/**
 * Copyright (c) 2017-present, Wonday (@wonday.org)
 * All rights reserved.
 *
 * This source code is licensed under the MIT-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTPdfView.h"

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <PDFKit/PDFKit.h>

#if __has_include(<React/RCTAssert.h>)
#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>
#import <React/UIView+React.h>
#import <React/RCTLog.h>
#else
#import "RCTBridgeModule.h"
#import "RCTEventDispatcher.h"
#import "UIView+React.h"
#import "RCTLog.h"
#endif

#ifndef __OPTIMIZE__
// only output log when debug
#define DLog( s, ... ) NSLog( @"<%p %@:(%d)> %@", self, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
#define DLog( s, ... )
#endif

// output log both debug and release
#define RLog( s, ... ) NSLog( @"<%p %@:(%d)> %@", self, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )

const float MAX_SCALE = 30.0f;
const float MIN_SCALE = 1.0f;


NS_CLASS_AVAILABLE_IOS(11_0) @interface MyPDFView: PDFView {
   
}
@end

@implementation MyPDFView

- (void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]])
    {
        UITapGestureRecognizer *tapGest = (UITapGestureRecognizer*)gestureRecognizer;
        if (tapGest.numberOfTapsRequired == 2)
        {
            return;
        }
        
    }

    [super addGestureRecognizer:gestureRecognizer];
}


- (void)addGestureRecognizer2:(UIGestureRecognizer *)gestureRecognizer
{
    
 
    [super addGestureRecognizer:gestureRecognizer];
}


- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer

{
    if (@available(iOS 13, *)) {
        return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

@end

@implementation RCTPdfView
{
    PDFDocument *_pdfDocument;
    MyPDFView *_pdfView;
    PDFOutline *root;
    float _fixScaleFactor;
    bool _initialed;
    NSArray<NSString *> *_changedProps;
	bool _initializing;
	NSTimer *_timerPosition;
    int _highlighter_page;
    int _isLandscape;
}

- (instancetype)init
{
    self = [super init];
    
    NSLog(@"HELLO THERE");
    if (self) {
        
        _page = 1;
        _scale = 1;
        _minScale = MIN_SCALE;
        _maxScale = MAX_SCALE;
        _horizontal = NO;
        _enablePaging = NO;
        _enableRTL = NO;
        _enableDarkMode = NO;
        _enableAnnotationRendering = YES;
        _fitPolicy = 2;
        _spacing = 10;
		
		_restoreViewState = @"";
		_annotations = nil;
        _highlightLines = nil;
        _highlighter_page = 0;
        
		_timerPosition = nil;
		
        // init and config PDFView
        _pdfView = [[MyPDFView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
        _pdfView.displayMode = kPDFDisplaySinglePageContinuous;
        _pdfView.autoScales = YES;
        _pdfView.displaysPageBreaks = YES;
        _pdfView.displayBox = kPDFDisplayBoxCropBox;
        
        _fixScaleFactor = -1.0f;
        _initialed = NO;
        _changedProps = NULL;
		_initializing = NO;
        _isLandscape = 0;
        
        [self addSubview:_pdfView];
        
        
        // register notification
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(onDocumentChanged:) name:PDFViewDocumentChangedNotification object:_pdfView];
        [center addObserver:self selector:@selector(onPageChanged:) name:PDFViewPageChangedNotification object:_pdfView];
        [center addObserver:self selector:@selector(onScaleChanged:) name:PDFViewScaleChangedNotification object:_pdfView];
	
        
        [[_pdfView document] setDelegate: self];
        
        
		
        double delayInSeconds = 0.5;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
          [self bindTap];
        });
        
    }
    
    return self;
}

- (void)didSetProps:(NSArray<NSString *> *)changedProps
{
    if (!_initialed) {
        
        _changedProps = changedProps;
        
    } else {
        if (_initializing == YES)
			return;
		_initializing = YES;
        if ([changedProps containsObject:@"path"]) {
            
            NSURL *fileURL = [NSURL fileURLWithPath:_path];
            
            if (_pdfDocument != Nil) {
                //Release old doc
                _pdfDocument = Nil;
            }
            
            _pdfDocument = [[PDFDocument alloc] initWithURL:fileURL];
            
            if (_pdfDocument) {
                
                //check need password or not
                if (_pdfDocument.isLocked && ![_pdfDocument unlockWithPassword:_password]) {
                    
                    _onChange(@{ @"message": @"error|Password required or incorrect password."});
                    
                    _pdfDocument = Nil;
                    return;
                }
                
                _pdfView.document = _pdfDocument;
            } else {
                
                _onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"error|Load pdf failed. path=%s",_path.UTF8String]]});
                
                _pdfDocument = Nil;
                return;
            }
        }
        
        if (_pdfDocument && ([changedProps containsObject:@"path"] || [changedProps containsObject:@"spacing"])) {
            if (_horizontal) {
                _pdfView.pageBreakMargins = UIEdgeInsetsMake(0,_spacing,0,0);
            } else {
                _pdfView.pageBreakMargins = UIEdgeInsetsMake(0,0,_spacing,0);
            }
        }
        
        if (_pdfDocument && ([changedProps containsObject:@"path"] || [changedProps containsObject:@"enableRTL"])) {
            _pdfView.displaysRTL = _enableRTL;
        }
        
        if (_pdfDocument && ([changedProps containsObject:@"path"] || [changedProps containsObject:@"enableAnnotationRendering"])) {
            if (!_enableAnnotationRendering) {
                for (unsigned long i=0; i<_pdfView.document.pageCount; i++) {
                    PDFPage *pdfPage = [_pdfView.document pageAtIndex:i];
                    for (unsigned long j=0; j<pdfPage.annotations.count; j++) {
                        pdfPage.annotations[j].shouldDisplay = _enableAnnotationRendering;
                    }
                }
            }
        }
        
        if (_pdfDocument && ([changedProps containsObject:@"path"] || [changedProps containsObject:@"fitPolicy"] || [changedProps containsObject:@"minScale"] || [changedProps containsObject:@"maxScale"] || [changedProps containsObject:@"restoreViewState"])) {
            
            PDFPage *pdfPage = [_pdfDocument pageAtIndex:_pdfDocument.pageCount-1];
            CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxCropBox];
            
            // some pdf with rotation, then adjust it
            if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
                pdfPageRect = CGRectMake(0, 0, pdfPageRect.size.height, pdfPageRect.size.width);
            }
			
			
			if ([_restoreViewState length] != 0) {
				NSArray *array = [_restoreViewState componentsSeparatedByString:@"/"];
				
                _page = [array[0] intValue];
				_scale = [array[5] floatValue];
                _fixScaleFactor = -1.0f;
                _minScale = MIN_SCALE;
                _maxScale = MAX_SCALE;
			}
			
            if (_fitPolicy == 0) {
                _fixScaleFactor = self.frame.size.width/pdfPageRect.size.width;
                _pdfView.scaleFactor = _scale * _fixScaleFactor;
                _pdfView.minScaleFactor = _fixScaleFactor*_minScale;
                _pdfView.maxScaleFactor = _fixScaleFactor*_maxScale;
            } else if (_fitPolicy == 1) {
                _fixScaleFactor = self.frame.size.height/pdfPageRect.size.height;
                _pdfView.scaleFactor = _scale * _fixScaleFactor;
                _pdfView.minScaleFactor = _fixScaleFactor*_minScale;
                _pdfView.maxScaleFactor = _fixScaleFactor*_maxScale;
            } else {
                float pageAspect = pdfPageRect.size.width/pdfPageRect.size.height;
                float reactViewAspect = self.frame.size.width/self.frame.size.height;
                if (reactViewAspect>pageAspect) {
                    _fixScaleFactor = self.frame.size.height/pdfPageRect.size.height;
                    _pdfView.scaleFactor = _scale * _fixScaleFactor;
                    _pdfView.minScaleFactor = _fixScaleFactor*_minScale;
                    _pdfView.maxScaleFactor = _fixScaleFactor*_maxScale;
                } else {
                    _fixScaleFactor = self.frame.size.width/pdfPageRect.size.width;
                    _pdfView.scaleFactor = _scale * _fixScaleFactor;
                    _pdfView.minScaleFactor = _fixScaleFactor*_minScale;
                    _pdfView.maxScaleFactor = _fixScaleFactor*_maxScale;
                }
            }
            
        }
        
        if (_pdfDocument && ([changedProps containsObject:@"path"] || [changedProps containsObject:@"scale"])) {
            _pdfView.scaleFactor = _scale * _fixScaleFactor;
            if (_pdfView.scaleFactor>_pdfView.maxScaleFactor) _pdfView.scaleFactor = _pdfView.maxScaleFactor;
            if (_pdfView.scaleFactor<_pdfView.minScaleFactor) _pdfView.scaleFactor = _pdfView.minScaleFactor;
        }
        
        if (_pdfDocument && ([changedProps containsObject:@"path"] || [changedProps containsObject:@"horizontal"])) {
            if (_horizontal) {
                _pdfView.displayDirection = kPDFDisplayDirectionHorizontal;
                _pdfView.pageBreakMargins = UIEdgeInsetsMake(0,_spacing,0,0);
            } else {
                _pdfView.displayDirection = kPDFDisplayDirectionVertical;
                _pdfView.pageBreakMargins = UIEdgeInsetsMake(0,0,_spacing,0);
            }
        }
        
        if (_pdfDocument && ([changedProps containsObject:@"path"] || [changedProps containsObject:@"enablePaging"])) {
            if (_enablePaging) {
                [_pdfView usePageViewController:YES withViewOptions:@{UIPageViewControllerOptionSpineLocationKey:@(UIPageViewControllerSpineLocationMin),UIPageViewControllerOptionInterPageSpacingKey:@(_spacing)}];
            } else {
                [_pdfView usePageViewController:NO withViewOptions:Nil];
            }
        }
       
        if (_pdfDocument && ([changedProps containsObject:@"path"] || [changedProps containsObject:@"enablePaging"] || [changedProps containsObject:@"horizontal"] || [changedProps containsObject:@"page"] || [changedProps containsObject:@"restoreViewState"] || [changedProps containsObject:@"annotations"] || [changedProps containsObject:@"highlightLines"])) {
			
            
            PDFPage *pdfPage = nil;
            if (_page == -1)
                pdfPage = [_pdfDocument pageAtIndex:0];
            else
                pdfPage = [_pdfDocument pageAtIndex:_page - 1];
            if (pdfPage) {
				
				
				
                CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxCropBox];
                
                // some pdf with rotation, then adjust it
                if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
                    pdfPageRect = CGRectMake(0, 0, pdfPageRect.size.height, pdfPageRect.size.width);
                    _isLandscape = 1;
                }
				 
				
				if ([_restoreViewState length] != 0) {
					NSArray *array = [_restoreViewState componentsSeparatedByString:@"/"];
					
					CGRect targetRect = { {[array[1] floatValue], [array[2] floatValue]}, {[array[3] floatValue], [array[4] floatValue]} };
					
					[_pdfView goToRect:targetRect onPage:pdfPage];
                    
                    _highlighter_page = [array[7] intValue];
				}
				else {
					CGPoint pointLeftTop = CGPointMake(0,  pdfPageRect.size.height);
					PDFDestination *pdfDest = [[PDFDestination alloc] initWithPage:pdfPage atPoint:pointLeftTop];
					[_pdfView goToDestination:pdfDest];
				}
				
				//savedRect	CGRect	(origin = (x = 156.29249129685482, y = 318.01580670334749), size = (width = 111.27272811160432, height = 178.46640450750056))
				
				
	
				
				
				_pdfView.scaleFactor = _fixScaleFactor*_scale;
				
				int totalPageNb = [_pdfDocument pageCount];
				
				int iter = 0;
				while (iter < totalPageNb) {
					
					PDFPage *annotationPage = [_pdfDocument pageAtIndex:iter];
					
					NSArray *annotationstmp = [annotationPage annotations];
					
					NSMutableArray *annotations = [NSMutableArray arrayWithArray:annotationstmp];
					for (id object in annotations) {
						[annotationPage removeAnnotation:object];
					}
					iter++;
					
					
				}
				
				if (_annotations != nil && [_annotations count] > 0) {
					for (id object in _annotations) {
						// do something with object
						
						
						float xPerc = [[object objectForKey:@"x"] floatValue];
						float yPerc = [[object objectForKey:@"y"] floatValue];
						
						long pageNb = [[object objectForKey:@"pageNb"] integerValue];
                        
                        NSString *title = (NSString *)[object objectForKey:@"title"];
                        
						NSString *color = (NSString *)[object objectForKey:@"color"];
                        NSString *icon = (NSString *)[object objectForKey:@"icon"];
                        
                        pdfPage = [_pdfDocument pageAtIndex:pageNb];
						CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxCropBox];
						
                        
                        float x = 0;
                        float y = 0;
                        if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
                           x = (pdfPageRect.size.width * (100 - yPerc) / 100) - (pdfPageRect.size.height - pdfPageRect.size.width);
                           y = (pdfPageRect.size.height * xPerc / 100);
                        }
                        else {
                            x = pdfPageRect.size.width - (pdfPageRect.size.width * xPerc / 100);
                            y = pdfPageRect.size.height - (pdfPageRect.size.height * yPerc / 100);
                        }
                       // x = pdfPageRect.size.width - (pdfPageRect.size.width * xPerc / 100);
                       // y = pdfPageRect.size.height - (pdfPageRect.size.height * yPerc / 100);
                        
						//float x = pdfPageRect.size.width - (pdfPageRect.size.width * xPerc / 100);
						//float y = pdfPageRect.size.height - (pdfPageRect.size.height * yPerc / 100);
						
                        float width = pdfPageRect.size.width - x + 10;
                        if (width > 200) {
                           width = 200;
                        }
                        float height = 200;
                        
                        CGRect targetRect;
                      /*  if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
                            targetRect = CGRectMake(y - (height - 10), x - 5, width, height);
                        }
                        else {*/
                            targetRect = CGRectMake( x - 5, y - (height - 10), width, height);
                       // }
						
						PDFPage *annotationPage = [_pdfDocument pageAtIndex:pageNb];
						PDFAnnotation* annotation = [[PDFAnnotation alloc] initWithBounds:targetRect forType:PDFAnnotationSubtypeFreeText withProperties:nil];
						 annotation.color = [UIColor colorWithRed:213.0/255.0 green:41.0/255.0 blue:65.0/255.0 alpha:0];
                        annotation.font = [UIFont fontWithName:@"ArialMT" size:13.0];
                        annotation.multiline = true;
                        annotation.fontColor = [self getUIColorObjectFromHexString:color alpha:1];
                        annotation.contents = [NSString stringWithFormat:@"%@%@", icon, title];
						// annotation.iconType = kPDFTextAnnotationIconNote;
                        [annotationPage addAnnotation:annotation];
						
						
                        /*
                        PDFAnnotation* annotation = [[PDFAnnotation alloc] initWithBounds:CGRectMake(206, 600, 60, 59) forType:PDFAnnotationSubtypeHighlight withProperties:nil];
                        annotation.color = UIColor.blueColor;
                        [annotationPage addAnnotation:annotation];
                        */
                        
						
						/*if (@available(iOS 13, *)) {
							[annotation setAccessibilityRespondsToUserInteraction:NO];
						
							[annotation setAction:nil];}*/
						
					}
				}
                
                
                if (_highlightLines != nil && [_highlightLines count] > 0) {
                    for (id object in _highlightLines) {
                        // do something with object
                        
                        
                        float startXPerc = [[object objectForKey:@"startX"] floatValue];
                        float startYPerc = [[object objectForKey:@"startY"] floatValue];
                        
                        long pageNb = [[object objectForKey:@"pageNb"] integerValue];
                        long size = [[object objectForKey:@"size"] integerValue];
                        long isVertical = [[object objectForKey:@"isVertical"] integerValue];
                        NSString *color = (NSString *)[object objectForKey:@"color"];
                    
                        pdfPage = [_pdfDocument pageAtIndex:pageNb];
                        CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxCropBox];
                        
                        
                        float startX = 0;
                        float startY = 0;
                        if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
                            startX = (pdfPageRect.size.width * (100 - startYPerc) / 100) - (pdfPageRect.size.height - pdfPageRect.size.width);
                            startY = (pdfPageRect.size.height * startXPerc / 100);
                        }
                        else {
                            startX = pdfPageRect.size.width - (pdfPageRect.size.width * startXPerc / 100);
                            startY = pdfPageRect.size.height - (pdfPageRect.size.height * startYPerc / 100);
                        }
                        
                        
                       // startY = startY - (size / 2);
                        float endXPerc = [[object objectForKey:@"endX"] floatValue];
                        float endYPerc = [[object objectForKey:@"endY"] floatValue];
                        
                        
                        float endX = 0;
                        float endY = 0;
                        if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
                            endX = (pdfPageRect.size.width * (100 - endYPerc) / 100) - (pdfPageRect.size.height - pdfPageRect.size.width);
                            endY = (pdfPageRect.size.height * endXPerc / 100);
                        }
                        else {
                            endX = pdfPageRect.size.width - (pdfPageRect.size.width * endXPerc / 100);
                            endY = pdfPageRect.size.height - (pdfPageRect.size.height * endYPerc / 100);
                        }
                        
                        
                        PDFPage *annotationPage = [_pdfDocument pageAtIndex:pageNb];
                        
                        float width = endX - startX;
                        float height = size;
                        if (isVertical == 1) {
                            width = size;
                            height = endY - startY;
                        }
                        PDFAnnotation* annotation = [[PDFAnnotation alloc] initWithBounds:CGRectMake(startX, startY, width, height) forType:PDFAnnotationSubtypeHighlight withProperties:nil];
                        annotation.color = [self getUIColorObjectFromHexString:color alpha:0.5];
                        [annotationPage addAnnotation:annotation];
                        
                   
                    }
                }
				
            }
        }
        if (_enableDarkMode)
            _pdfView.backgroundColor = [UIColor blackColor];
        else
            _pdfView.backgroundColor = [UIColor whiteColor];
		/*if (@available(iOS 12, *)) {
			[_pdfView enablePageShadows:NO];
		}
		[_pdfView setEnableDataDetectors:NO];
        [_pdfView setGestureRecognizers:nil];*/
		_initializing = NO;
		
        [_pdfView layoutDocumentView];
        [self setNeedsDisplay];
    }
}


- (void)reactSetFrame:(CGRect)frame
{
    [super reactSetFrame:frame];
    _pdfView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
    
    _initialed = YES;
    
    [self didSetProps:_changedProps];
}

- (void)dealloc{
    
    _pdfDocument = Nil;
    _pdfView = Nil;
    
    //Remove notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"PDFViewDocumentChangedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"PDFViewPageChangedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"PDFViewScaleChangedNotification" object:nil];
	
	
	if (_timerPosition) {
		[_timerPosition invalidate];
		_timerPosition = nil;
	}
    
}

#pragma mark notification process
- (void)onDocumentChanged:(NSNotification *)noti
{
    
    if (_pdfDocument) {
        
        unsigned long numberOfPages = _pdfDocument.pageCount;
        PDFPage *page = [_pdfDocument pageAtIndex:_pdfDocument.pageCount-1];
        CGSize pageSize = [_pdfView rowSizeForPage:page];
        NSString *jsonString = [self getTableContents];
        
        _onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"loadComplete|%lu|%f|%f|%@", numberOfPages, pageSize.width, pageSize.height,jsonString]]});
    }
    
}

- (unsigned int)intFromHexString:(NSString *)hexStr
{
  unsigned int hexInt = 0;

  // Create scanner
  NSScanner *scanner = [NSScanner scannerWithString:hexStr];

  // Tell scanner to skip the # character
  [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"#"]];

  // Scan hex value
  [scanner scanHexInt:&hexInt];

  return hexInt;
}

- (UIColor *)getUIColorObjectFromHexString:(NSString *)hexStr alpha:(CGFloat)alpha
{
  // Convert hex string to an integer
  unsigned int hexint = [self intFromHexString:hexStr];

  // Create a color object, specifying alpha as well
  UIColor *color =
    [UIColor colorWithRed:((CGFloat) ((hexint & 0xFF0000) >> 16))/255
    green:((CGFloat) ((hexint & 0xFF00) >> 8))/255
    blue:((CGFloat) (hexint & 0xFF))/255
    alpha:alpha];

  return color;
}




-(NSString *) getTableContents
{
    
    NSMutableArray<PDFOutline *> *arrTableOfContents = [[NSMutableArray alloc] init];
    
    if (_pdfDocument.outlineRoot) {
        
        PDFOutline *currentRoot = _pdfDocument.outlineRoot;
        NSMutableArray<PDFOutline *> *stack = [[NSMutableArray alloc] init];
        
        [stack addObject:currentRoot];
        
        while (stack.count > 0) {
            
            PDFOutline *currentOutline = stack.lastObject;
            [stack removeLastObject];
            
            if (currentOutline.label.length > 0){
                [arrTableOfContents addObject:currentOutline];
            }
            
            for ( NSInteger i= currentOutline.numberOfChildren; i > 0; i-- )
            {
                [stack addObject:[currentOutline childAtIndex:i-1]];
            }
        }
    }
    
    NSMutableArray *arrParentsContents = [[NSMutableArray alloc] init];
    
    for ( NSInteger i= 0; i < arrTableOfContents.count; i++ )
    {
        PDFOutline *currentOutline = [arrTableOfContents objectAtIndex:i];
        
        NSInteger indentationLevel = -1;
        
        PDFOutline *parentOutline = currentOutline.parent;
        
        while (parentOutline != nil) {
            indentationLevel += 1;
            parentOutline = parentOutline.parent;
        }
        
        if (indentationLevel == 0) {
            
            NSMutableDictionary *DXParentsContent = [[NSMutableDictionary alloc] init];
            
            [DXParentsContent setObject:[[NSMutableArray alloc] init] forKey:@"children"];
            [DXParentsContent setObject:@"" forKey:@"mNativePtr"];
            [DXParentsContent setObject:[NSString stringWithFormat:@"%lu", [_pdfDocument indexForPage:currentOutline.destination.page]] forKey:@"pageIdx"];
            [DXParentsContent setObject:currentOutline.label forKey:@"title"];
            
            //currentOutlin
            //mNativePtr
            [arrParentsContents addObject:DXParentsContent];
        }
        else {
            NSMutableDictionary *DXParentsContent = [arrParentsContents lastObject];
            
            NSMutableArray *arrChildren = [DXParentsContent valueForKey:@"children"];
            
            while (indentationLevel > 1) {
                NSMutableDictionary *DXchild = [arrChildren lastObject];
                arrChildren = [DXchild valueForKey:@"children"];
                indentationLevel--;
            }
            
            NSMutableDictionary *DXChildContent = [[NSMutableDictionary alloc] init];
            [DXChildContent setObject:[[NSMutableArray alloc] init] forKey:@"children"];
            [DXChildContent setObject:@"" forKey:@"mNativePtr"];
            [DXChildContent setObject:[NSString stringWithFormat:@"%lu", [_pdfDocument indexForPage:currentOutline.destination.page]] forKey:@"pageIdx"];
            [DXChildContent setObject:currentOutline.label forKey:@"title"];
            [arrChildren addObject:DXChildContent];
            
        }
    }
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:arrParentsContents options:NSJSONWritingPrettyPrinted error:&error];
    
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    return jsonString;
    
}

- (void)onPageChanged:(NSNotification *)noti
{
    
    if (_pdfDocument) {
        PDFPage *currentPage = _pdfView.currentPage;
        unsigned long page = [_pdfDocument indexForPage:currentPage];
        unsigned long numberOfPages = _pdfDocument.pageCount;

        _onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"pageChanged|%lu|%lu", page+1, numberOfPages]]});
    }
    
}

- (void)onScaleChanged:(NSNotification *)noti
{
    
    if (_initialed && _fixScaleFactor>0 && _initializing == NO) {
        if (_scale != _pdfView.scaleFactor/_fixScaleFactor) {
            _scale = _pdfView.scaleFactor/_fixScaleFactor;
            _onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"scaleChanged|%f", _scale]]});
        }
    }
}



#pragma mark gesture process

/**
 *  Tap
 *  zoom reset or zoom in
 *
 *  @param recognizer
 */
- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer
{
    // Cycle through min/mid/max scale factors to be consistent with Android
    float min = 1.0f;
    float max = 4.0f;
    float mid = 2.0f;
    float scale = _scale;
    if (_scale < mid) {
        scale = mid;
    } else if (_scale < max) {
        scale = max;
    } else {
        scale = min;
    }
    
    _pdfView.scaleFactor = scale*_fixScaleFactor;
    
    [self setNeedsDisplay];
    [self onScaleChanged:Nil];
	
	[self didMove];
}

/**
 *  Single Tap
 *  stop zoom
 *
 *  @param recognizer
 */
- (void)handleSingleTap:(UITapGestureRecognizer *)sender
{
	
    //_pdfView.scaleFactor = _pdfView.minScaleFactor;
    
    CGPoint point = [sender locationInView:self];
	
	
	[self annotationClicked:point];
    //[self setNeedsDisplay];
    //[self onScaleChanged:Nil];
    
	[self didMove];
}

/**
 *  Pinch
 *
 *
 *  @param recognizer
 */
-(void)handlePinch:(UIPinchGestureRecognizer *)sender{
    [self onScaleChanged:Nil];
	
	[self didMove];
}

/**
 *  Pinch
 *
 *
 *  @param recognizer
 */
-(void)handlePan:(UIPanGestureRecognizer *)sender{
    [self onScaleChanged:Nil];
    
    [self didMove];
}

-(BOOL)annotationClicked:(CGPoint)point{
	
	PDFPage *pdfPage = [_pdfView pageForPoint:point nearest:NO];
	if (pdfPage) {
		unsigned long page = [_pdfDocument indexForPage:pdfPage];
		
		point = [_pdfView convertPoint:point toPage:pdfPage];
		
		
		CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxCropBox];
		
		
		if (_annotations && [_annotations count] > 0) {
			for (id object in _annotations) {
		
				long pageNb = [[object objectForKey:@"pageNb"] integerValue];
				
				if (pageNb != page)
					continue;
				
				float xPerc = [[object objectForKey:@"x"] floatValue];
				float yPerc = [[object objectForKey:@"y"] floatValue];
				
				float x = pdfPageRect.size.width - (pdfPageRect.size.width * xPerc / 100);
				float y = pdfPageRect.size.height - (pdfPageRect.size.height * yPerc / 100);
				
				NSString *uniqueIdOnClient = [object objectForKey:@"uniqueIdOnClient"];
				
				if (pageNb == page && x > point.x - 20 && x < point.x + 20
					&& y > point.y - 20 && y < point.y + 20)
				{
					_onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"annotationClicked|%@|12", uniqueIdOnClient]]});
					return YES;
					
				}
			}
		}
	}
	
	return NO;
}

- (void) ShowAlert:(NSString *)Message {
    UIAlertController * alert=[UIAlertController alertControllerWithTitle:nil
                                                                  message:@""
                                                           preferredStyle:UIAlertControllerStyleAlert];
    UIView *firstSubview = alert.view.subviews.firstObject;
    UIView *alertContentView = firstSubview.subviews.firstObject;
    for (UIView *subSubView in alertContentView.subviews) {
        subSubView.backgroundColor = [UIColor colorWithRed:141/255.0f green:0/255.0f blue:254/255.0f alpha:1.0f];
    }
    NSMutableAttributedString *AS = [[NSMutableAttributedString alloc] initWithString:Message];
    [AS addAttribute: NSForegroundColorAttributeName value: [UIColor whiteColor] range: NSMakeRange(0,AS.length)];
    [alert setValue:AS forKey:@"attributedTitle"];
    UIViewController *viewController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    if ( viewController.presentedViewController && !viewController.presentedViewController.isBeingDismissed ) {
        viewController = viewController.presentedViewController;
    }

    NSLayoutConstraint *constraint = [NSLayoutConstraint
        constraintWithItem:alert.view
        attribute:NSLayoutAttributeHeight
        relatedBy:NSLayoutRelationLessThanOrEqual
        toItem:nil
        attribute:NSLayoutAttributeNotAnAttribute
        multiplier:1
        constant:viewController.view.frame.size.height*2.0f];

    [alert.view addConstraint:constraint];
    [viewController presentViewController:alert animated:YES completion:^{}];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [viewController dismissViewControllerAnimated:YES completion:^{
        }];
    });
}

/**
 *  Do nothing on long Press
 *
 *
 */
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender{
	CGPoint point = [sender locationInView:self];
	
	PDFPage *pdfPage = [_pdfView pageForPoint:point nearest:NO];
	if (pdfPage) {
		
		if ([self annotationClicked:point] == YES)
			return;
		
		unsigned long page = [_pdfDocument indexForPage:pdfPage];
		
		point = [_pdfView convertPoint:point toPage:pdfPage];
		
		BOOL canEdit = [_pdfDocument allowsCommenting];
		
//        if (!canEdit) {
//
//            NSString * language = [[NSLocale preferredLanguages] firstObject];
//
//            NSString *str = @"This document does not support annotations.";
//            if ([language containsString:@"fr"]) {
//
//              str = @"Ce document n'accepte pas les annotations.";
//            }
//            else if ([language containsString:@"de"]) {
//
//              str = @"Dieses Dokument ist geschützt und akzeptiert keine Anmerkungen";
//            }
//
//
//
//            [self ShowAlert:str];
//        }
//
		CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxCropBox];
		
		
		float x;
		float y;
        
        x = (pdfPageRect.size.width - point.x) / pdfPageRect.size.width * 100;
                   y = (pdfPageRect.size.height - point.y) / pdfPageRect.size.height * 100;
        if (pdfPage.rotation == 90 || pdfPage.rotation == 270)
        {
            float tmp = x;
            x = 100 - y;
            y = tmp;
           // x = 100 - ((pdfPageRect.size.height - point.y) / pdfPageRect.size.height * 100);
           // y = 100 - ((pdfPageRect.size.width - point.x) / pdfPageRect.size.width * 100);
            
        }
        
		//if (canEdit) {
            _onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"longClick|%f|%f|%lu|%d", x, y, page, canEdit ? 1 : 0]]});
	//	}
	}
	[self didMove];
}



- (void)disableLongPressSubviews:(UIView *)view
{
    
    for (UIView *subview in view.subviews)
    {
       for (UIGestureRecognizer * g in subview.gestureRecognizers) {
           
           if ([g isKindOfClass:[UILongPressGestureRecognizer class]]) {
               g.enabled = NO;
            }
       }
        [self disableLongPressSubviews:subview];
    }
}
/**
 *  Bind tap
 *
 *
 */
- (void)bindTap
{
    UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                          action:@selector(handleDoubleTap:)];
    //trigger by one finger and double touch
    doubleTapRecognizer.numberOfTapsRequired = 2;
    doubleTapRecognizer.numberOfTouchesRequired = 1;

    [_pdfView addGestureRecognizer2:doubleTapRecognizer];
    doubleTapRecognizer.delegate = self;
    UITapGestureRecognizer *singleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                          action:@selector(handleSingleTap:)];
    //trigger by one finger and one touch
    singleTapRecognizer.numberOfTapsRequired = 1;
    singleTapRecognizer.numberOfTouchesRequired = 1;
    
    [_pdfView addGestureRecognizer2:singleTapRecognizer];
   // [singleTapRecognizer requireGestureRecognizerToFail:doubleTapRecognizer];
    singleTapRecognizer.delegate = self;
    
    UIPinchGestureRecognizer *pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                                                          action:@selector(handlePinch:)];
    [self addGestureRecognizer:pinchRecognizer];
    pinchRecognizer.delegate = self;
    
//    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
//    [_pdfView addGestureRecognizer2:panRecognizer];
//    panRecognizer.delegate = self;
//
    

    [self disableLongPressSubviews:_pdfView];
    
    UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                            action:@selector(handleLongPress:)];
    // Making sure the allowable movement isn not too narrow
    longPressRecognizer.allowableMovement=300;
    // Important: The duration must be long enough to allow taps but not longer than the period in which view opens the magnifying glass
    longPressRecognizer.minimumPressDuration=1.0;
    
    [_pdfView addGestureRecognizer2:longPressRecognizer];
	
	
	
	
	UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipe:)];
	swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
	[_pdfView addGestureRecognizer2:swipeLeft];
	swipeLeft.delegate = self;
	
	UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self  action:@selector(didSwipe:)];
	swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
	[_pdfView addGestureRecognizer2:swipeRight];
	swipeRight.delegate = self;
	
	UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc]  initWithTarget:self action:@selector(didSwipe:)];
	swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
	[_pdfView addGestureRecognizer2:swipeUp];
	swipeUp.delegate = self;
	
	UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipe:)];
	swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
	[_pdfView addGestureRecognizer2:swipeDown];
    swipeDown.delegate = self;
}

- (void)sendNewPosition
{
	
    PDFPage *pdfPage = [_pdfDocument pageAtIndex:0];
    CGRect savedRect2 = [_pdfView convertRect:_pdfView.bounds toPage:pdfPage];
    
    //NSLog(@"savedRect2 %f", savedRect2.origin.y);
    
    
	PDFPage *page = [_pdfView pageForPoint:CGPointZero nearest:YES];
	
	if (!page)
		return;
	
	CGRect savedRect = [_pdfView convertRect:_pdfView.bounds toPage:page];
	
	unsigned long pageNb = [_pdfDocument indexForPage:page];
	
    float posYFromSelectedPage;
    if (_isLandscape == 1) {
        posYFromSelectedPage = savedRect2.origin.x;
    }
    else {
        posYFromSelectedPage = savedRect2.origin.y;
    }
	float zoom = _pdfView.scaleFactor/_fixScaleFactor;
	//onPositionChanged={(currentPage, pageFocusX, pageFocusY, zoom, positionOffset)
	_onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"iosPositionChanged|%lu|%f|%f|%f|%f|%f|%f|%d", (pageNb + 1), savedRect.origin.x,  savedRect.origin.y, savedRect.size.width, savedRect.size.height, zoom, posYFromSelectedPage, _isLandscape]]});
	
	
//	NSLog(@"sending new pos %f", savedRect.origin.y);
}


- (void)didMove
{
	if (_timerPosition) {
		[_timerPosition invalidate];
	}
	_timerPosition = [NSTimer scheduledTimerWithTimeInterval:0.5
									 target:self
								   selector:@selector(sendNewPosition)
								   userInfo:nil
									repeats:NO];
	
	
	
}


- (void)didSwipe:(UISwipeGestureRecognizer*)swipe{
	
	
	[self didMove];
}


- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer

{
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}



@end
