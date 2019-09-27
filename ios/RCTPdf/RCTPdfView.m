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

const float MAX_SCALE = 3.0f;
const float MIN_SCALE = 1.0f;

@implementation RCTPdfView
{
    PDFDocument *_pdfDocument;
    PDFView *_pdfView;
    PDFOutline *root;
    float _fixScaleFactor;
    bool _initialed;
    NSArray<NSString *> *_changedProps;
	bool _initializing;
	NSTimer *_timerPosition;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        _page = 1;
        _scale = 1;
        _minScale = MIN_SCALE;
        _maxScale = MAX_SCALE;
        _horizontal = NO;
        _enablePaging = NO;
        _enableRTL = NO;
        _enableAnnotationRendering = YES;
        _fitPolicy = 2;
        _spacing = 10;
		
		_restoreViewState = @"";
		_annotations = nil;
		
		_timerPosition = nil;
		
        // init and config PDFView
        _pdfView = [[PDFView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
        _pdfView.displayMode = kPDFDisplaySinglePageContinuous;
        _pdfView.autoScales = YES;
        _pdfView.displaysPageBreaks = YES;
        _pdfView.displayBox = kPDFDisplayBoxCropBox;
        
        _fixScaleFactor = -1.0f;
        _initialed = NO;
        _changedProps = NULL;
		_initializing = NO;
		
        [self addSubview:_pdfView];
        
        
        // register notification
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(onDocumentChanged:) name:PDFViewDocumentChangedNotification object:_pdfView];
        [center addObserver:self selector:@selector(onPageChanged:) name:PDFViewPageChangedNotification object:_pdfView];
        [center addObserver:self selector:@selector(onScaleChanged:) name:PDFViewScaleChangedNotification object:_pdfView];
	
        
        [[_pdfView document] setDelegate: self];
        
        
        [self bindTap];
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
        
        if (_pdfDocument && ([changedProps containsObject:@"path"] || [changedProps containsObject:@"fitPolicy"] || [changedProps containsObject:@"minScale"] || [changedProps containsObject:@"maxScale"])) {
            
            PDFPage *pdfPage = [_pdfDocument pageAtIndex:_pdfDocument.pageCount-1];
            CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxCropBox];
            
            // some pdf with rotation, then adjust it
            if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
                pdfPageRect = CGRectMake(0, 0, pdfPageRect.size.height, pdfPageRect.size.width);
            }
			
			
			if ([_restoreViewState length] != 0) {
				NSArray *array = [_restoreViewState componentsSeparatedByString:@"/"];
				
				_scale = [array[5] floatValue];
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
        
        if (_pdfDocument && ([changedProps containsObject:@"path"] || [changedProps containsObject:@"enablePaging"] || [changedProps containsObject:@"horizontal"] || [changedProps containsObject:@"page"] || [changedProps containsObject:@"restoreViewState"]|| [changedProps containsObject:@"annotations"])) {
			
		
			
			
			
			
            PDFPage *pdfPage = [_pdfDocument pageAtIndex:_page-1];
            if (pdfPage) {
				
				
				
                CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxCropBox];
                
                // some pdf with rotation, then adjust it
                if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
                    pdfPageRect = CGRectMake(0, 0, pdfPageRect.size.height, pdfPageRect.size.width);
                }
				
				float left = 0;
				float top = pdfPageRect.size.height;
				
				
                CGPoint pointLeftTop = CGPointMake(0,  pdfPageRect.size.height);
                PDFDestination *pdfDest = [[PDFDestination alloc] initWithPage:pdfPage atPoint:pointLeftTop];
				
                [_pdfView goToDestination:pdfDest];
				
				if ([_restoreViewState length] != 0) {
					NSArray *array = [_restoreViewState componentsSeparatedByString:@"/"];
					
					CGRect targetRect = { {[array[1] floatValue], [array[2] floatValue]}, {[array[3] floatValue], [array[4] floatValue]} };
					
					[_pdfView goToRect:targetRect onPage:pdfPage];
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
						
						
						CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxCropBox];
						
						float x = pdfPageRect.size.width - (pdfPageRect.size.width * xPerc / 100);
						float y = pdfPageRect.size.height - (pdfPageRect.size.height * yPerc / 100);
						
						CGRect targetRect = { x - 10, y - 10, {20, 20} };
						
						PDFPage *annotationPage = [_pdfDocument pageAtIndex:pageNb];
						PDFAnnotation* annotation = [[PDFAnnotation alloc] initWithBounds:targetRect forType:PDFAnnotationSubtypeFreeText withProperties:nil];
						 annotation.color = [UIColor colorWithRed:213.0/255.0 green:41.0/255.0 blue:65.0/255.0 alpha:1];
						 annotation.contents = @" ";
						 annotation.iconType = kPDFTextAnnotationIconNote;
						 [annotationPage addAnnotation:annotation];
						
						/*if (@available(iOS 13, *)) {
							[annotation setAccessibilityRespondsToUserInteraction:NO];
						
							[annotation setAction:nil];}*/
						
					}
				}
				
            }
        }
        
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
    
    if (_initialed && _fixScaleFactor>0) {
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
    float min = _pdfView.minScaleFactor/_fixScaleFactor;
    float max = _pdfView.maxScaleFactor/_fixScaleFactor;
    float mid = (max - min) / 2 + min;
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


-(BOOL)annotationClicked:(CGPoint)point{
	
	PDFPage *pdfPage = [_pdfView pageForPoint:point nearest:NO];
	if (pdfPage) {
		unsigned long page = [_pdfDocument indexForPage:pdfPage];
		
		point = [_pdfView convertPoint:point toPage:pdfPage];
		
		
		CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxCropBox];
		
		
		
		
		if (_annotations != nil && [_annotations count] > 0) {
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
		
		
		CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxCropBox];
		
		
		float x = (pdfPageRect.size.width - point.x) / pdfPageRect.size.width * 100;
		float y = (pdfPageRect.size.height - point.y) / pdfPageRect.size.height * 100;
		if (canEdit) {
		_onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"longClick|%f|%f|%lu", x, y, page]]});
		}
	}
	[self didMove];
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
    
    [self addGestureRecognizer:doubleTapRecognizer];
    
    UITapGestureRecognizer *singleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                          action:@selector(handleSingleTap:)];
    //trigger by one finger and one touch
    singleTapRecognizer.numberOfTapsRequired = 1;
    singleTapRecognizer.numberOfTouchesRequired = 1;
    
    [self addGestureRecognizer:singleTapRecognizer];
    [singleTapRecognizer requireGestureRecognizerToFail:doubleTapRecognizer];
    
    UIPinchGestureRecognizer *pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                                                          action:@selector(handlePinch:)];
    [self addGestureRecognizer:pinchRecognizer];
    pinchRecognizer.delegate = self;
    
    UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                            action:@selector(handleLongPress:)];
    // Making sure the allowable movement isn not too narrow
    longPressRecognizer.allowableMovement=100;
    // Important: The duration must be long enough to allow taps but not longer than the period in which view opens the magnifying glass
    longPressRecognizer.minimumPressDuration=0.3;
    
    [self addGestureRecognizer:longPressRecognizer];
	
	
	
	
	UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipe:)];
	swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
	[self addGestureRecognizer:swipeLeft];
	swipeLeft.delegate = self;
	
	UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self  action:@selector(didSwipe:)];
	swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
	[self addGestureRecognizer:swipeRight];
	swipeRight.delegate = self;
	
	UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc]  initWithTarget:self action:@selector(didSwipe:)];
	swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
	[self addGestureRecognizer:swipeUp];
	swipeUp.delegate = self;
	
	UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipe:)];
	swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
	[self addGestureRecognizer:swipeDown];
    swipeDown.delegate = self;
}

- (void)sendNewPosition
{
	
	PDFPage *page = [_pdfView pageForPoint:CGPointZero nearest:YES];
	CGRect savedRect = [_pdfView convertRect:_pdfView.bounds toPage:page];
	
	
	//PDFDestination *pdfDestination = [_pdfView currentDestination];
	
	//				[_pdfView goToDestination:pdfDestination];
	
//	CGPoint newPoint = pdfDestination.point;
	
	
	//float x = newPoint.x;
	//float y = newPoint.y;
	
	unsigned long pageNb = [_pdfDocument indexForPage:page];
	
	float zoom = _pdfView.scaleFactor/_fixScaleFactor;
	//onPositionChanged={(currentPage, pageFocusX, pageFocusY, zoom, positionOffset)
	_onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"iosPositionChanged|%lu|%f|%f|%f|%f|%f", (pageNb + 1), savedRect.origin.x,  savedRect.origin.y, savedRect.size.width, savedRect.size.height, zoom]]});
	
	
	NSLog(@"sending new pos %f", savedRect.origin.y);
}


- (void)didMove
{
	if (_timerPosition) {
		[_timerPosition invalidate];
	}
	_timerPosition = [NSTimer scheduledTimerWithTimeInterval:3.0
									 target:self
								   selector:@selector(sendNewPosition)
								   userInfo:nil
									repeats:NO];
	
	
	
}


- (void)didSwipe:(UISwipeGestureRecognizer*)swipe{
	
	
	[self didMove];
	
	if (swipe.direction == UISwipeGestureRecognizerDirectionLeft) {
		NSLog(@"Swipe Left");
	} else if (swipe.direction == UISwipeGestureRecognizerDirectionRight) {
		NSLog(@"Swipe Right");
	} else if (swipe.direction == UISwipeGestureRecognizerDirectionUp) {
		NSLog(@"Swipe Up");
	} else if (swipe.direction == UISwipeGestureRecognizerDirectionDown) {
		NSLog(@"Swipe Down");
	}
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
