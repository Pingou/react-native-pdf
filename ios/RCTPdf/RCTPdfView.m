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
#import "SVGKit.h"

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
#import <math.h>
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


- (void)setScrollsToTop:(BOOL)scrollsToTop {
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIScrollView class]]) {
            [(UIScrollView *)subview setScrollsToTop:NO];
        }
    }
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self setScrollsToTop:NO];
}

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

@interface ClickableZone : NSObject
    @property(strong) NSString *action;
    @property(strong) NSString *param;
    @property() long pageNb;
    @property (nonatomic, assign) CGRect bounds;
@end


@implementation ClickableZone {

};
@end


@implementation PDFImageAnnotation : PDFAnnotation {
    UIImage * _picture;
    CGRect _bounds;
    float _offsetY;
    float _offsetX;
};
CGContextRef _context;

-(instancetype)initWithPicture:(nonnull UIImage *)picture bounds:(CGRect) bounds offsetX:(float) offsetX offsetY:(float) offsetY {
    self = [super initWithBounds:bounds
                  forType:PDFAnnotationSubtypeWidget
                  withProperties:nil];

    if(self){
        _picture = picture;
        _bounds = bounds;
        _offsetX = offsetX;
        _offsetY = offsetY;
        _context = nil;
    }
    
    
    return  self;
}


- (void)redraw {
    
    [_picture drawInRect:_bounds];

    CGContextRestoreGState(_context);
    UIGraphicsPopContext();
}

- (void)drawWithBox:(PDFDisplayBox) box
          inContext:(CGContextRef)context {
    [super drawWithBox:box inContext:context];
    
    
    
   /*
    
     UIGraphicsPushContext(context);
     CGContextSaveGState(context);
     
     [_picture drawInRect:_bounds];

     CGContextRestoreGState(context);
     UIGraphicsPopContext();
     */
     
     
    
    UIGraphicsPushContext(context);
        CGContextSaveGState(context);

        CGContextTranslateCTM(context, _bounds.origin.x - _offsetX, _bounds.origin.y + _bounds.size.height - _offsetY);
        CGContextScaleCTM(context, 1.0, -1.0);
        [_picture drawInRect:CGRectMake(0,0, _bounds.size.width - _offsetX, _bounds.size.height - _offsetY)];

        //[_picture drawAtPoint:CGPointMake(0, 0)];
        CGContextRestoreGState(context);
        UIGraphicsPopContext();
    
    _context = context;
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
    NSTimer *_timerPosition2;
    int _highlighter_page;
    int _isLandscape;
    NSMutableArray<PDFAnnotation *> *_annotationsAdded;
    NSMutableArray<PDFImageAnnotation *> *_drawingsAdded;
    NSMutableArray<PDFImageAnnotation *> *_drawingsV2Added;
    NSMutableArray<PDFAnnotation *> *_chartHighlightsAdded;
    NSMutableArray<PDFAnnotation *> *_editChartHighlightsAdded;
    NSMutableArray<ClickableZone *> *_clickableZonesAdded;
    int _lastDrawingDrawnWhenPageWasAt;
    float _horizontalHighlightPosPercent;
    int _horizontalHighlightPosPageNb;
    float _verticalHighlightPosPercent;
    int _verticalHighlightPosPageNb;
    bool _hasSentPosInit;
    float _lastZoomLevel;
    bool _hasRestoredViewState;
    bool _showPagesNav;
    bool _hasAddedPreviousAndNext;
    NSString *_chartStart;
    NSString *_chartEnd;
    PDFAnnotation* _annotationChartStart;
    PDFAnnotation* _annotationChartEnd;
    int _totalPageNb;
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
        _spacing = 0;
		
		_restoreViewState = @"";
		_annotations = nil;
        _drawings = nil;
        _drawingsV2 = nil;
        _highlightLines = nil;
        _highlighter_page = 0;
        _lastDrawingDrawnWhenPageWasAt = -42;
        
		_timerPosition = nil;
        _timerPosition2 = nil;
        
        _hasRestoredViewState = NO;
        _showPagesNav = NO;
        _singlePage = NO;
        _chartStart = nil;
        _chartEnd = nil;
        
        // init and config PDFView
        _pdfView = [[MyPDFView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
        if (_singlePage == YES)
            _pdfView.displayMode = kPDFDisplaySinglePage;
        else
            _pdfView.displayMode = kPDFDisplaySinglePageContinuous;
        //_pdfView.displayMode = kPDFDisplaySinglePage;//kPDFDisplaySinglePageContinuous;
        _pdfView.autoScales = YES;
        _pdfView.displaysPageBreaks = NO;
        _pdfView.displayBox = kPDFDisplayBoxMediaBox;
        
        _fixScaleFactor = -1.0f;
        _initialed = NO;
        _changedProps = NULL;
		_initializing = NO;
        _isLandscape = 0;
        _totalPageNb = 0;
        
        _horizontalHighlightPosPercent = -42.0f;
        _verticalHighlightPosPercent = -42.0f;
        _hasSentPosInit = false;
        _lastZoomLevel = -1;
        
        _annotationsAdded = [[NSMutableArray alloc] init];
        _drawingsAdded = [[NSMutableArray alloc] init];
        _drawingsV2Added = [[NSMutableArray alloc] init];
        _chartHighlightsAdded = [[NSMutableArray alloc] init];
        _clickableZonesAdded = [[NSMutableArray alloc] init];
        _editChartHighlightsAdded = [[NSMutableArray alloc] init];
        _annotationChartStart = nil;
        _annotationChartEnd = nil;
        
        _hasAddedPreviousAndNext = NO;
        [self addSubview:_pdfView];
        
        
        // register notification
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(onDocumentChanged:) name:PDFViewDocumentChangedNotification object:_pdfView];
        [center addObserver:self selector:@selector(onPageChanged:) name:PDFViewPageChangedNotification object:_pdfView];
        [center addObserver:self selector:@selector(onScaleChanged:) name:PDFViewScaleChangedNotification object:_pdfView];
        [center addObserver:self selector:@selector(onDisplayChanged:) name:PDFViewDisplayBoxChangedNotification object:_pdfView];
	
        
        [[_pdfView document] setDelegate: self];
        [_pdfView setDelegate: self];
        
		
        double delayInSeconds = 0.5;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
          [self bindTap];
        });
        
    }
    
    return self;
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    //UIGraphicsBeginImageContext(newSize);
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (void)didSetProps:(NSArray<NSString *> *)changedProps
{
    if (!_initialed) {
        
        _changedProps = changedProps;
        
    } else {
        if (_initializing == YES)
			return;
		_initializing = YES;
        
        if ([changedProps containsObject:@"singlePage"]) {
            if (_singlePage == YES)
                _pdfView.displayMode = kPDFDisplaySinglePage;
            else
                _pdfView.displayMode = kPDFDisplaySinglePageContinuous;
        }
       
        float zoomFromRestoreViewState = 0;
        
        if ([changedProps containsObject:@"restoreViewState"]) {
            NSArray *array = [_restoreViewState componentsSeparatedByString:@"/"];
            
            if (array.count > 12) {
            _verticalHighlightPosPercent = [array[9] floatValue];
            _horizontalHighlightPosPercent = [array[10] floatValue];
            _verticalHighlightPosPageNb = [array[11] intValue];
            _horizontalHighlightPosPageNb = [array[12] intValue];
            zoomFromRestoreViewState = [array[5] floatValue];
            }
            
            
            
           
        }
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
            CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
            
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
        PDFPage *pdfPage = nil;
        if (_page == -1)
            pdfPage = [_pdfDocument pageAtIndex:0];
        else
            pdfPage = [_pdfDocument pageAtIndex:_page - 1];
        

        if (_pdfDocument && ([changedProps containsObject:@"showPagesNav"])) {
            if (_showPagesNav == YES) {
                [_pdfView setDisplaysPageBreaks:YES];
                //if (pdfPage.rotation == 90 || pdfPage.rotation == 270)
                  //  [_pdfView setPageBreakMargins:UIEdgeInsetsMake(100, 0, 0, 0)];
                //else
                [_pdfView setPageBreakMargins:UIEdgeInsetsMake(50, 0, 0, 0)];
            }
        }
        
        if (_pdfDocument && ([changedProps containsObject:@"chartStart"] || [changedProps containsObject:@"chartEnd"]) && _chartStart && _chartStart.length > 0) {
            
            NSArray *array = [_chartStart componentsSeparatedByString:@"|"];
            
            //UIImage *appIcon = [UIImage imageWithContentsOfFile:array[2]];
            UIImage *icon = [UIImage imageNamed:@"crosshairTop"];
            
            if (_annotationChartStart) {
                PDFPage *annotationPage = [_pdfDocument pageAtIndex:_page -1];
              
                [annotationPage removeAnnotation:_annotationChartStart];
                _annotationChartStart = nil;
            }
            _annotationChartStart = [self addImgAnnotationAtSpot:(_page -1) xPerc:[array[0] floatValue] yPerc:[array[1] floatValue] image:icon imgSizeMultiplier:1.5 action:nil actionParam:nil alpha:1.0];
            
            if (_chartEnd && _chartEnd.length > 0) {
                
                if (_annotationChartEnd) {
                    PDFPage *annotationPage = [_pdfDocument pageAtIndex:_page -1];
                  
                    [annotationPage removeAnnotation:_annotationChartEnd];
                    _annotationChartEnd = nil;
                }
                
                NSArray *arrayEnd = [_chartEnd componentsSeparatedByString:@"|"];
                _annotationChartEnd = [self addHighlightAnnotationAtSpot:(_page -1) startXPerc:[array[0] floatValue] startYPerc:[array[1] floatValue] endXPerc:[arrayEnd[0] floatValue] endYPerc:[arrayEnd[1] floatValue] color:@"22ff22"];
                
            }
            
        }
        
       
       // [_pdfView setLayoutMargins:UIEdgeInsetsMake(0, 0, 100, 0)];
                             
        if (_pdfDocument && ([changedProps containsObject:@"path"] || [changedProps containsObject:@"enablePaging"] || [changedProps containsObject:@"horizontal"] || [changedProps containsObject:@"page"] || [changedProps containsObject:@"restoreViewState"] || [changedProps containsObject:@"annotations"] || [changedProps containsObject:@"highlightLines"] || [changedProps containsObject:@"drawings"] || [changedProps containsObject:@"drawingsV2"])) {
			
            
            PDFPage *pdfPage = nil;
           if (_page == -1)
               pdfPage = [_pdfDocument pageAtIndex:0];
           else
               pdfPage = [_pdfDocument pageAtIndex:_page - 1];
            
            if (pdfPage) {
				
        
                CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
                
                // some pdf with rotation, then adjust it
                if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
                    pdfPageRect = CGRectMake(0, 0, pdfPageRect.size.height, pdfPageRect.size.width);
                    _isLandscape = 1;
                }
				 
               
                if (_hasRestoredViewState == NO || _pdfView.currentPage != pdfPage) {
                    if ([_restoreViewState length] != 0) {
                        NSArray *array = [_restoreViewState componentsSeparatedByString:@"/"];
                        NSLog(@"restoringviewstate: %i %f %f", _page, [array[2] floatValue], [array[4] floatValue]);
                        CGRect targetRect = { {[array[1] floatValue], [array[2] floatValue]}, {[array[3] floatValue], [array[4] floatValue]} };
                        
                        pdfPage = [_pdfDocument pageAtIndex:_page - 1];
                        [_pdfView goToRect:targetRect onPage:pdfPage];
                        
                        _highlighter_page = [array[7] intValue];
                        
                        
                        _hasRestoredViewState = YES;
                    }
                    else {
                        CGPoint pointLeftTop = CGPointMake(0,  pdfPageRect.size.height);
                        PDFDestination *pdfDest = [[PDFDestination alloc] initWithPage:pdfPage atPoint:pointLeftTop];
                        [_pdfView goToDestination:pdfDest];
                    }
                }
				
				
				//savedRect	CGRect	(origin = (x = 156.29249129685482, y = 318.01580670334749), size = (width = 111.27272811160432, height = 178.46640450750056))
				
				
	
				
				
				_pdfView.scaleFactor = _fixScaleFactor*_scale;
				
				
            }
        }
        
        
        if (_pdfDocument && ([changedProps containsObject:@"annotations"] || [changedProps containsObject:@"highlightLines"] || [changedProps containsObject:@"drawings"] || [changedProps containsObject:@"drawingsV2"] || [changedProps containsObject:@"chartHighlights"]  || _lastDrawingDrawnWhenPageWasAt != _page)) {
            
            
            _lastDrawingDrawnWhenPageWasAt = _page;
            PDFPage *pdfPage = nil;
            if (_page == -1)
                pdfPage = [_pdfDocument pageAtIndex:0];
            else
                pdfPage = [_pdfDocument pageAtIndex:_page - 1];
            if (pdfPage) {
                
                
                
             
                
                
                _pdfView.scaleFactor = _fixScaleFactor*_scale;
                
                _totalPageNb = [_pdfDocument pageCount];
                
                int iter = 0;
                while (iter < _totalPageNb) {
                    
                    PDFPage *annotationPage = [_pdfDocument pageAtIndex:iter];
                    
                    //NSArray *annotationstmp = [annotationPage annotations];
                    
//NSMutableArray *annotations = [NSMutableArray arrayWithArray:annotationstmp];
                    for (id object in _annotationsAdded) {
                        [annotationPage removeAnnotation:object];
                    }
                    
                    for (id object in _drawingsAdded) {
                        [annotationPage removeAnnotation:object];
                    }
                    
                    for (id object in _drawingsV2Added) {
                        [annotationPage removeAnnotation:object];
                    }
                    
                    for (id object in _chartHighlightsAdded) {
                        [annotationPage removeAnnotation:object];
                    }
                    for (id object in _editChartHighlightsAdded) {
                        [annotationPage removeAnnotation:object];
                    }
                    
                    iter++;
                    
                    
                }
                [_annotationsAdded removeAllObjects];
                [_drawingsAdded removeAllObjects];
                [_drawingsV2Added removeAllObjects];
                [_chartHighlightsAdded removeAllObjects];
                [_editChartHighlightsAdded removeAllObjects];
                
                if (_annotations != nil && [_annotations count] > 0) {
                    for (id object in _annotations) {
                        // do something with object
                        
                        
                        float xPerc = [[object objectForKey:@"x"] floatValue];
                        float yPerc = [[object objectForKey:@"y"] floatValue];
                        
                        long pageNb = [[object objectForKey:@"pageNb"] integerValue];
                        
                        NSString *title = (NSString *)[object objectForKey:@"title"];
                        
                        NSString *color = (NSString *)[object objectForKey:@"color"];
                        NSString *icon = (NSString *)[object objectForKey:@"icon"];
                        
                        long fontSize = [[object objectForKey:@"size"] integerValue];
                        
                        pdfPage = [_pdfDocument pageAtIndex:pageNb];
                        CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
                        
                        
                        float x = 0;
                        float y = 0;
                        
                        if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
                          // x = (pdfPageRect.size.width * (100 - yPerc) / 100) - (pdfPageRect.size.height - pdfPageRect.size.width);
                         //  y = (pdfPageRect.size.height * xPerc / 100);
                            x = (pdfPageRect.size.width * (100 - yPerc) / 100);
                            y = (pdfPageRect.size.height * xPerc / 100);
                        }
                        /*else if (pdfPage.rotation == 270) {
                            x = (pdfPageRect.size.width * (100 - yPerc) / 100);
                            y = (pdfPageRect.size.height * xPerc / 100);
                        }*/
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
                        if (pdfPage.rotation == 90) {
                            targetRect = CGRectMake(x, y - 5, width, height);
                        }
                        else if (pdfPage.rotation == 270) {
                            width = 150;
                            height = 40;
                            targetRect = CGRectMake(x - height, y - width, height, width);
                        }
                        else {
                            targetRect = CGRectMake( x - 5, y - (height - 10), width, height);
                       }
                        
                        float baseWidth = 1000;
                        float currentWidth = fmin(pdfPageRect.size.width,pdfPageRect.size.height);
                        if (currentWidth > baseWidth) {
                            fontSize = fontSize * ((currentWidth / baseWidth));
                        }
                        
                        PDFPage *annotationPage = [_pdfDocument pageAtIndex:pageNb];
                        PDFAnnotation* annotation = [[PDFAnnotation alloc] initWithBounds:targetRect forType:PDFAnnotationSubtypeFreeText withProperties:nil];
                         annotation.color = [UIColor colorWithRed:213.0/255.0 green:41.0/255.0 blue:65.0/255.0 alpha:0];
                        annotation.font = [UIFont fontWithName:@"ArialMT" size:fontSize];
                        annotation.multiline = true;
                        annotation.fontColor = [self getUIColorObjectFromHexString:color alpha:1];
                        annotation.contents = [NSString stringWithFormat:@"%@%@", icon, title];
                        // annotation.iconType = kPDFTextAnnotationIconNote;
                        [annotationPage addAnnotation:annotation];
                        
                        [_annotationsAdded addObject:annotation];
                        
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
                
                
                if (_drawings != nil && [_drawings count] > 0) {
                    for (id object in _drawings) {
                        // do something with object
                        
                        
                        float xPercStart = [[object objectForKey:@"startX"] floatValue];
                        float yPercStart = [[object objectForKey:@"startY"] floatValue];
                        
                        float xPercEnd = [[object objectForKey:@"endX"] floatValue];
                        float yPercEnd = [[object objectForKey:@"endY"] floatValue];
                        
                        long pageNb = [[object objectForKey:@"pageNb"] integerValue];
                        
                        NSString *path = [object objectForKey:@"imgPath"];
                        
                      
                        pdfPage = [_pdfDocument pageAtIndex:pageNb];
                        CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
                        
                        
                        float startX = 0;
                        float startY = 0;
                        
                        float endX = 0;
                        float endY = 0;
                        
                        /*
                         
                         if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
                            x = (pdfPageRect.size.width * (100 - yPerc) / 100) - (pdfPageRect.size.height - pdfPageRect.size.width);
                            y = (pdfPageRect.size.height * xPerc / 100);
                         }
                         else {
                             x = pdfPageRect.size.width - (pdfPageRect.size.width * xPerc / 100);
                             y = pdfPageRect.size.height - (pdfPageRect.size.height * yPerc / 100);
                         }
                         
                         */
                        float width;
                        float height;
                        float offsetX;
                        float offsetY;
                        
                        
                        if (pdfPage.rotation == 90) {
                            float tmp = xPercStart;
                            xPercStart = yPercStart;
                            yPercStart = 100 - tmp;
                            tmp = xPercEnd;
                            xPercEnd = yPercEnd;
                            yPercEnd = 100 - tmp;
                            
                            tmp = yPercStart;
                            yPercStart = yPercEnd;
                            yPercEnd = tmp;
                        }
                        else if (pdfPage.rotation == 270) {
                            float tmp = xPercStart;
                            xPercStart = 100 - yPercStart;
                            yPercStart = tmp;
                            tmp = xPercEnd;
                            xPercEnd = 100 - yPercEnd;
                            yPercEnd = tmp;
                            
                            tmp = xPercStart;
                            xPercStart = xPercEnd;
                            xPercEnd = tmp;
                            
                        }
                 /*       if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
                            startX = (pdfPageRect.size.width * (yPercStart) / 100);
                            startY = (pdfPageRect.size.height * (xPercEnd) / 100);
                            
                           // endX = (pdfPageRect.size.width * (yPercEnd) / 100) - (pdfPageRect.size.height - pdfPageRect.size.width);
                            endX = (pdfPageRect.size.width * (yPercEnd) / 100);
                            endY = (pdfPageRect.size.height * (xPercStart) / 100);
                            
                            
                            if (pdfPage.rotation == 90) {
                                width = endX - startX;
                                height = startY - endY;
                            }
                            else {
                                width = startX - endX;
                                height = endY - startY;
                                startX = startX - width;
                                endX = endX - width;
                                startY = startY - height;
                                endY = endY - height;
                            }
                            offsetX = pdfPageRect.origin.y;
                            offsetY = pdfPageRect.origin.x;
                        }
                        else {*/
                            startX = (pdfPageRect.size.width * xPercStart / 100);
                            startY = (pdfPageRect.size.height) - (pdfPageRect.size.height * (yPercStart/ 100));
                                                        
                            endX = pdfPageRect.size.width * xPercEnd / 100;
                            endY = (pdfPageRect.size.height) - ((pdfPageRect.size.height) * (yPercEnd / 100));
                            
                            width = endX - startX;
                            height = startY - endY;
                            offsetX = pdfPageRect.origin.x;
                            offsetY = pdfPageRect.origin.y;
                       // }
                       
                       
                        
                        CGRect targetRect;
                      /*  if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
                            targetRect = CGRectMake(y - (height - 10), x - 5, width, height);
                        }
                        else {*/
                            targetRect = CGRectMake( startX, endY, width + offsetX, height + offsetY);
                       // }
                        
                     

                        
                        UIImage *image = [UIImage imageWithContentsOfFile:path];
                        
                        if (pdfPage.rotation == 90) {
                            image = [UIImage imageWithCGImage:image.CGImage
                                                                    scale:image.scale
                                                              orientation:UIImageOrientationLeft];
                        }
                        else if (pdfPage.rotation == 270) {
                            image = [UIImage imageWithCGImage:image.CGImage
                                                                    scale:image.scale
                                                              orientation:UIImageOrientationRight];
                        }
                        else {
                            //image = [UIImage imageWithCGImage:image.CGImage
                            //                                        scale:image.scale
                              //                                orientation:UIImageOrientationDownMirrored];
                        }
                       // float ratio = width / image.size.width;
                       // float newHeight = image.size.height * ratio;
                        
                        //image = [self imageWithImage:image scaledToSize:CGSizeMake(round(width), round(height))];
                        //targetRect = CGRectMake( startX, endY, round(width), round(height + 8));
                       
                        PDFPage *annotationPage = [_pdfDocument pageAtIndex:pageNb];
                        PDFImageAnnotation* annotation = [[PDFImageAnnotation alloc] initWithPicture:image bounds:targetRect offsetX:offsetX offsetY:offsetY];
                        annotation.backgroundColor = UIColor.redColor;
                         annotation.color = [UIColor colorWithRed:213.0/255.0 green:41.0/255.0 blue:65.0/255.0 alpha:0];
                                                // annotation.iconType = kPDFTextAnnotationIconNote;
                        
                        if (pageNb > _page + 2 || pageNb < _page - 2)
                            annotation.shouldDisplay = NO;
                        
                        [annotationPage addAnnotation:annotation];
                        
                        [_drawingsAdded addObject:annotation];
                        
                      
                        
                    }
                    
                
                }
                
                
                if (_drawingsV2 != nil && [_drawingsV2 count] > 0) {
                    
                    [self addDrawingsV2ToView];
                
                }
                if (_chartHighlights != nil && [_chartHighlights count] > 0) {
                    for (id object in _chartHighlights) {
                        float startXPerc = [[object objectForKey:@"startX"] floatValue];
                        float startYPerc = [[object objectForKey:@"startY"] floatValue];
                        float endXPerc = [[object objectForKey:@"endX"] floatValue];
                        float endYPerc = [[object objectForKey:@"endY"] floatValue];
                        
                        long pageNb = [[object objectForKey:@"pageNb"] integerValue];
                       
                        int chartId = [[object objectForKey:@"id"] integerValue];
                        NSString* chartIdStr = [NSString stringWithFormat:@"%i", chartId];
                        NSString *color = (NSString *)[object objectForKey:@"color"];
                    
                        PDFAnnotation *annotation = [self addHighlightAnnotationAtSpot:(pageNb -1) startXPerc:startXPerc startYPerc:startYPerc endXPerc:endXPerc endYPerc:endYPerc color:color];
                        
                        [_chartHighlightsAdded addObject:annotation];
                        
                        UIImage *pencilIcon = [UIImage imageNamed:@"pencil"];
                        PDFAnnotation *editHightlight = [self addImgAnnotationAtSpot:(pageNb - 1) xPerc:startXPerc yPerc:startYPerc image:pencilIcon imgSizeMultiplier:0.5 action:@"edit_chart" actionParam:chartIdStr alpha:0.7];
                        
                        [_editChartHighlightsAdded addObject:editHightlight];
                        
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
                        CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
                        
                        //sur android c'est plus petit que sur ios, on ajuste
                        //size = size * 0.8;
                        
                        float startX = 0;
                        float startY = 0;
                        if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
                           // startX = (pdfPageRect.size.width * (100 - startYPerc) / 100) - (pdfPageRect.size.height - pdfPageRect.size.width);
                           // startY = (pdfPageRect.size.height * startXPerc / 100);
                            
                            startX = (pdfPageRect.size.width * (100 - startYPerc) / 100);
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
                          //  endX = (pdfPageRect.size.width * (100 - endYPerc) / 100) - (pdfPageRect.size.height - pdfPageRect.size.width);
                           // endY = (pdfPageRect.size.height * endXPerc / 100);
                            
                            
                            endX = (pdfPageRect.size.width * (100 - endYPerc) / 100);
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
                            startX = startX - (size / 2);
                            width = size;
                            height = endY - startY;
                        }
                        else
                            startY = startY - (size / 2);
                        
                        
                        CGRect targetRect;
                        if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
                            if (isVertical == 1)
                                targetRect = CGRectMake(startX, startY - (size / 2), endX - startX, width);
                            else
                                targetRect = CGRectMake(startX - (size / 2), startY, size, endY - startY);
                        }
                        else {
                            targetRect = CGRectMake( startX, startY, width, height);
                       }
                        
                        
                        PDFAnnotation* annotation = [[PDFAnnotation alloc] initWithBounds:targetRect forType:PDFAnnotationSubtypeHighlight withProperties:nil];
                        annotation.color = [self getUIColorObjectFromHexString:color alpha:0.5];
                        [annotationPage addAnnotation:annotation];
                        
                   
                    }
                }
                
            }
        }
        long totalPageNb = [_pdfDocument pageCount];
        if (_showPagesNav == YES && _hasAddedPreviousAndNext == NO && totalPageNb > 1)
            [self showPreviousAndNextPages:_page - 1];
        
        
        if (_enableDarkMode)
            _pdfView.backgroundColor = [UIColor blackColor];
        else
            _pdfView.backgroundColor = [UIColor whiteColor];
        
        if (@available(iOS 12, *)) {
            if (_spacing == 0) {
                [_pdfView enablePageShadows:NO];
            }
        }
		/*if (@available(iOS 12, *)) {
			[_pdfView enablePageShadows:NO];
		}
		[_pdfView setEnableDataDetectors:NO];
        [_pdfView setGestureRecognizers:nil];*/
		_initializing = NO;
		
        [_pdfView layoutDocumentView];
        [self setNeedsDisplay];
        
        
        if (!_hasSentPosInit || zoomFromRestoreViewState != _lastZoomLevel) {
            _hasSentPosInit = true;
            _lastZoomLevel = zoomFromRestoreViewState;
            [self didMove];
        }
    }
}


- (void)showPreviousAndNextPages:(long)pageNb
{
    
    UIImage *previous_icon = [UIImage imageNamed:@"back_blue"];
    UIImage *next_icon = [UIImage imageNamed:@"forward_blue"];
    [self addImgAnnotationAtSpot:pageNb xPerc:60.0 yPerc:105.0 image:previous_icon imgSizeMultiplier:1.0 action:@"previous" actionParam:nil alpha:1.0];
    [self addImgAnnotationAtSpot:pageNb xPerc:40.0 yPerc:105.0 image:next_icon imgSizeMultiplier:1.0 action:@"next" actionParam:nil alpha:1.0];
    [self addImgAnnotationAtSpot:pageNb xPerc:60.0 yPerc:-4.0 image:previous_icon imgSizeMultiplier:1.0 action:@"previous" actionParam:nil alpha:1.0];
    [self addImgAnnotationAtSpot:pageNb xPerc:40.0 yPerc:-4.0 image:next_icon imgSizeMultiplier:1.0 action:@"next" actionParam:nil alpha:1.0];
    _hasAddedPreviousAndNext = YES;
}

- (void)addDrawingsV2ToView
{
    PDFPage *pdfPage = nil;
    if (_page == -1)
        pdfPage = [_pdfDocument pageAtIndex:0];
    else
        pdfPage = [_pdfDocument pageAtIndex:_page - 1];
    
    for (id object in _drawingsV2) {
        // do something with object
        
        
        float xPercStart = 0.0f;
        float yPercStart = 0.0f;
        
        float xPercEnd = 100.0f;
        float yPercEnd = 100.0f;
        
        long pageNb = [[object objectForKey:@"pageNb"] integerValue];
        
        NSString *path = [object objectForKey:@"imgPath"];
        
      
        pdfPage = [_pdfDocument pageAtIndex:pageNb];
        CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
        
        
        float startX = 0;
        float startY = 0;
        
        float endX = 0;
        float endY = 0;
        
        
        float width;
        float height;
        float offsetX;
        float offsetY;
        
        
        if (pdfPage.rotation == 90) {
            float tmp = xPercStart;
            xPercStart = yPercStart;
            yPercStart = 100 - tmp;
            tmp = xPercEnd;
            xPercEnd = yPercEnd;
            yPercEnd = 100 - tmp;
            
            tmp = yPercStart;
            yPercStart = yPercEnd;
            yPercEnd = tmp;
        }
        else if (pdfPage.rotation == 270) {
            float tmp = xPercStart;
            xPercStart = 100 - yPercStart;
            yPercStart = tmp;
            tmp = xPercEnd;
            xPercEnd = 100 - yPercEnd;
            yPercEnd = tmp;
            
            tmp = xPercStart;
            xPercStart = xPercEnd;
            xPercEnd = tmp;
            
        }
 
            startX = (pdfPageRect.size.width * xPercStart / 100);
            startY = (pdfPageRect.size.height) - (pdfPageRect.size.height * (yPercStart/ 100));
                                        
            endX = pdfPageRect.size.width * xPercEnd / 100;
            endY = (pdfPageRect.size.height) - ((pdfPageRect.size.height) * (yPercEnd / 100));
            
            width = endX - startX;
            height = startY - endY;
            offsetX = pdfPageRect.origin.x;
            offsetY = pdfPageRect.origin.y;
       // }
       
       
        
        CGRect targetRect;
      /*  if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
            targetRect = CGRectMake(y - (height - 10), x - 5, width, height);
        }
        else {*/
            targetRect = CGRectMake( startX, endY, width + offsetX, height + offsetY);
  

        SVGKImage *svgImage = [[SVGKImage alloc] initWithContentsOfFile:path];
        UIImage *image = svgImage.UIImage;//[UIImage imageWithContentsOfFile:newPath];
        
        if (pdfPage.rotation == 90) {
            image = [UIImage imageWithCGImage:image.CGImage
                                                    scale:image.scale
                                              orientation:UIImageOrientationLeft];
        }
        else if (pdfPage.rotation == 270) {
            image = [UIImage imageWithCGImage:image.CGImage
                                                    scale:image.scale
                                              orientation:UIImageOrientationRight];
        }
        else {
            //image = [UIImage imageWithCGImage:image.CGImage
            //                                        scale:image.scale
              //                                orientation:UIImageOrientationDownMirrored];
        }
       
        PDFPage *annotationPage = [_pdfDocument pageAtIndex:pageNb];
        PDFImageAnnotation* annotation = [[PDFImageAnnotation alloc] initWithPicture:image bounds:targetRect offsetX:offsetX offsetY:offsetY];
      //  annotation.backgroundColor = UIColor.redColor;
      //   annotation.color = [UIColor colorWithRed:213.0/255.0 green:41.0/255.0 blue:65.0/255.0 alpha:0];
                                // annotation.iconType = kPDFTextAnnotationIconNote;
        
       // if (pageNb > _page + 2 || pageNb < _page - 2)
         //   annotation.shouldDisplay = NO;
        annotation.shouldDisplay = YES;
        [annotationPage addAnnotation:annotation];
        
        [_drawingsV2Added addObject:annotation];
        
      
        
    }

}

- (void)setDrawingsDynamically:(NSArray *)drawings
{
    if (_pdfDocument) {
        PDFPage *currentPage = _pdfView.currentPage;
         unsigned long page = [_pdfDocument indexForPage:currentPage];
         unsigned long numberOfPages = _pdfDocument.pageCount;
         for (PDFAnnotation *object in _drawingsV2Added) {
  
         
                    // object.shouldDisplay = NO;
             PDFPage *annotationPage = object.page;
             [annotationPage removeAnnotation:object];
           
             
             
         }
        dispatch_async(dispatch_get_main_queue(), ^{
            [_drawingsV2Added removeAllObjects];
            
            _drawingsV2 = drawings;
            [self addDrawingsV2ToView];
            [_pdfView setNeedsDisplay];
            [_pdfView layoutDocumentView];
        });
       
       
        
       
    }

}

- (void)addLineAtSpot:(long)pageNb startXPerc:(float)startXPerc startYPerc:(float)startYPerc endXPerc:(float)endXPerc endYPerc:(float)endYPerc color:(NSString *)color
{
    /*
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, startX, startY);
    CGContextAddLineToPoint(context, endX, endY);
    CGContextStrokePath(context);*/
}

- (PDFAnnotation *)addHighlightAnnotationAtSpot:(long)pageNb startXPerc:(float)startXPerc startYPerc:(float)startYPerc endXPerc:(float)endXPerc endYPerc:(float)endYPerc color:(NSString *)color
{
    PDFPage *pdfPage = [_pdfDocument pageAtIndex:pageNb];
    CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];

    //sur android c'est plus petit que sur ios, on ajuste
    //size = size * 0.8;

    float startX = 0;
    float startY = 0;
    if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
        startX = (pdfPageRect.size.width * (100 - startYPerc) / 100);
        startY = (pdfPageRect.size.height * startXPerc / 100);
    }
    else {
        startX = pdfPageRect.size.width - (pdfPageRect.size.width * startXPerc / 100);
        startY = pdfPageRect.size.height - (pdfPageRect.size.height * startYPerc / 100);
    }

    float endX = 0;
    float endY = 0;
    if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
          
        endX = (pdfPageRect.size.width * (100 - endYPerc) / 100);
        endY = (pdfPageRect.size.height * endXPerc / 100);
    }
    else {
        endX = pdfPageRect.size.width - (pdfPageRect.size.width * endXPerc / 100);
        endY = pdfPageRect.size.height - (pdfPageRect.size.height * endYPerc / 100);
    }

    PDFPage *annotationPage = [_pdfDocument pageAtIndex:pageNb];

    CGRect targetRect;
   // if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
        targetRect = CGRectMake( startX, startY, endX - startX, endY - startY);
        //targetRect = CGRectMake(startX, startY, endX - startY, endY - startY);
   // }
    //else {
      //  targetRect = CGRectMake( startX, startY, endX - startX, endY - startY);
    //}
    
    PDFAnnotation* annotation = [[PDFAnnotation alloc] initWithBounds:targetRect forType:PDFAnnotationSubtypeHighlight withProperties:nil];
    annotation.color = [self getUIColorObjectFromHexString:color alpha:0.8];
    [annotationPage addAnnotation:annotation];

    
    
    
    return annotation;
}

- (PDFAnnotation *)addImgAnnotationAtSpot:(long)pageNb xPerc:(float)xPercStart yPerc:(float)yPercStart image:(UIImage *)image imgSizeMultiplier:(float)imgSizeMultiplier action:(NSString *)action actionParam:(NSString *)actionParam alpha:(float)alpha
{
    PDFPage *pdfPage = [_pdfDocument pageAtIndex:pageNb];
    CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
    
    //float xPercEnd = xPercStart + 5;
    //float yPercEnd = yPercStart + 5;
    float startX = 0;
    float startY = 0;
    
    float endX = 0;
    float endY = 0;
    
   
    float width;
    float height;
    float offsetX;
    float offsetY;
    
    float imgSize = pdfPageRect.size.height / 10 / (_scale + 1) * imgSizeMultiplier;
    if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
        startX = (pdfPageRect.size.width * (100 - yPercStart) / 100);
        startY = (pdfPageRect.size.height * xPercStart / 100);
    }
    else {
        startX = pdfPageRect.size.width - (pdfPageRect.size.width * xPercStart / 100);
        startY = (pdfPageRect.size.height) - (pdfPageRect.size.height * (yPercStart/ 100));
    }

    offsetX = pdfPageRect.origin.x;
    offsetY = pdfPageRect.origin.y;

    CGRect targetRect;

       // targetRect = CGRectMake( startX - (imgSize / 2), startY - (imgSize / 2), imgSize, imgSize);

    if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
        targetRect = CGRectMake(startX - (imgSize / 2), startY - (imgSize / 2), imgSize, imgSize);
    }
    else {
        targetRect = CGRectMake( startX - (imgSize / 2), startY - (imgSize / 2), imgSize, imgSize);
   }
   
    //UIImage *image = [UIImage imageWithContentsOfFile:imgUri];
    
    if (pdfPage.rotation == 90) {
        image = [UIImage imageWithCGImage:image.CGImage
                                                scale:image.scale
                                          orientation:UIImageOrientationLeft];
    }
    else if (pdfPage.rotation == 270) {
        image = [UIImage imageWithCGImage:image.CGImage
                                                scale:image.scale
                                          orientation:UIImageOrientationRight];
    }
    else {
        //image = [UIImage imageWithCGImage:image.CGImage
        //                                        scale:image.scale
          //                                orientation:UIImageOrientationDownMirrored];
    }
   
    PDFPage *annotationPage = [_pdfDocument pageAtIndex:pageNb];
    PDFImageAnnotation* annotation = [[PDFImageAnnotation alloc] initWithPicture:image bounds:targetRect offsetX:offsetX offsetY:offsetY];
    annotation.backgroundColor = UIColor.redColor;
     annotation.color = [UIColor colorWithRed:213.0/255.0 green:41.0/255.0 blue:65.0/255.0 alpha:alpha];
                            // annotation.iconType = kPDFTextAnnotationIconNote;
    [annotationPage addAnnotation:annotation];
    
    if (action) {
        ClickableZone *clickableZone = [[ClickableZone alloc] init];
        clickableZone.action = action;
        clickableZone.param = actionParam;
        clickableZone.bounds = targetRect;
        clickableZone.pageNb = pageNb;
        [_clickableZonesAdded addObject:clickableZone];
        
    }
    
    return annotation;
}

- (void)addTextAnnotationAtSpot:(long)pageNb xPerc:(float)xPerc yPerc:(float)yPerc title:(NSString *)title
{
    
    NSString *color = @"#5f433d";
    
    long fontSize = 16;
    
    PDFPage *pdfPage = [_pdfDocument pageAtIndex:pageNb];
    CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
    
    
    float x = 0;
    float y = 0;
    
    if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
      // x = (pdfPageRect.size.width * (100 - yPerc) / 100) - (pdfPageRect.size.height - pdfPageRect.size.width);
     //  y = (pdfPageRect.size.height * xPerc / 100);
        x = (pdfPageRect.size.width * (100 - yPerc) / 100);
        y = (pdfPageRect.size.height * xPerc / 100);
    }
    /*else if (pdfPage.rotation == 270) {
        x = (pdfPageRect.size.width * (100 - yPerc) / 100);
        y = (pdfPageRect.size.height * xPerc / 100);
    }*/
    else {
        x = pdfPageRect.size.width - (pdfPageRect.size.width * xPerc / 100);
        y = pdfPageRect.size.height - (pdfPageRect.size.height * yPerc / 100);
    }
   // x = pdfPageRect.size.width - (pdfPageRect.size.width * xPerc / 100);
   // y = pdfPageRect.size.height - (pdfPageRect.size.height * yPerc / 100);
    
    //float x = pdfPageRect.size.width - (pdfPageRect.size.width * xPerc / 100);
    //float y = pdfPageRect.size.height - (pdfPageRect.size.height * yPerc / 100);
    
    float width = 25;
    float height = 25;
    
    
    
    CGRect targetRect;
    if (pdfPage.rotation == 90) {
        targetRect = CGRectMake(x, y - 5, width, height);
    }
    else if (pdfPage.rotation == 270) {
        width = 150;
        height = 40;
        targetRect = CGRectMake(x - height, y - width, height, width);
    }
    else {
        targetRect = CGRectMake( x - 5, y - (height - 10), width, height);
   }
    
    
    PDFPage *annotationPage = [_pdfDocument pageAtIndex:pageNb];
    PDFAnnotation* annotation = [[PDFAnnotation alloc] initWithBounds:targetRect forType:PDFAnnotationSubtypeFreeText withProperties:nil];
    // annotation.color = [UIColor colorWithRed:213.0/255.0 green:41.0/255.0 blue:65.0/255.0 alpha:0];
    annotation.font = [UIFont fontWithName:@"ArialMT" size:fontSize];
    annotation.fontColor = [self getUIColorObjectFromHexString:color alpha:1];
    annotation.contents = title;
    //annotation.iconType = kPDFTextAnnotationIconNote;
    [annotationPage addAnnotation:annotation];
}


- (void)PDFViewWillClickOnLink:(PDFView *)sender withURL:(NSURL *)url
{
    NSString *_url = url.absoluteString;
    
    NSLog(@"url %s", _url.UTF8String);
    _onChange(@{ @"message":
                     [[NSString alloc] initWithString:
                      [NSString stringWithFormat:
                       @"linkPressed|%s", _url.UTF8String]] });
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
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"PDFViewDisplayBoxChangedNotification" object:nil];
	
	
	if (_timerPosition) {
		[_timerPosition invalidate];
		_timerPosition = nil;
	}
    if (_timerPosition2) {
        [_timerPosition2 invalidate];
        _timerPosition2 = nil;
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
        
        int disableAnnotations = 0;
        if (![_pdfDocument allowsCommenting])
            disableAnnotations = 1;

        _onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"loadComplete|%lu|%f|%f|%lu|%@", numberOfPages, pageSize.width, pageSize.height,disableAnnotations,jsonString]]});
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
/*
- (void)pdfViewWillLayoutSubviews:(PDFView *)pdfView {
    for (PDFAnnotation *annotation in _drawingsAdded) {
        [annotation.page removeAnnotation:annotation];
        [annotation.page addAnnotation:annotation];
    }
}*/

- (void)onPageChanged:(NSNotification *)noti
{
    
    if (_pdfDocument) {
        PDFPage *currentPage = _pdfView.currentPage;
        unsigned long page = [_pdfDocument indexForPage:currentPage];
        unsigned long numberOfPages = _pdfDocument.pageCount;

        _onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"pageChanged|%lu|%lu", page+1, numberOfPages]]});
        //iterate drawings added, hide the ones 1 pages off and show the ones on the current page, previous page and next page
        for (PDFAnnotation *object in _drawingsAdded) {
            if (page - 1 == [_pdfDocument indexForPage:object.page] || page == [_pdfDocument indexForPage:object.page] || page + 1 == [_pdfDocument indexForPage:object.page]) {
                
                //add annotation
                //PDFPage *page = [_pdfDocument pageAtIndex:object.page];
                //[page addAnnotation:object];

                object.shouldDisplay = YES;
                //object.
            }
            else {
                //PDFPage *page = [_pdfDocument pageAtIndex:object.page];
                //[page removeAnnotation:object];
                object.shouldDisplay = NO;
            }
        }
        
        for (PDFAnnotation *object in _drawingsV2Added) {
            if (page - 1 == [_pdfDocument indexForPage:object.page] || page == [_pdfDocument indexForPage:object.page] || page + 1 == [_pdfDocument indexForPage:object.page]) {
                
                //add annotation
                //PDFPage *page = [_pdfDocument pageAtIndex:object.page];
                //[page addAnnotation:object];

                object.shouldDisplay = YES;
                //object.
            }
            else {
                //PDFPage *page = [_pdfDocument pageAtIndex:object.page];
                //[page removeAnnotation:object];
                object.shouldDisplay = NO;
            }
        }
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


- (void)onDisplayChanged:(NSNotification *)noti
{
    [self didMove];
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


- (void)checkIfClickableTouched:(UITapGestureRecognizer *)sender
{
    
    unsigned long pageNb = [_pdfDocument indexForPage:_pdfView.currentPage];
    CGPoint point = [sender locationInView:self];
    CGPoint pointPageBefore = [sender locationInView:self];
    CGPoint pointPageAfter = [sender locationInView:self];
    PDFPage *pdfPageBefore = nil;
    if (pageNb > 1) {
        pdfPageBefore = [_pdfDocument pageAtIndex:pageNb - 1];
        pointPageBefore = [_pdfView convertPoint:point toPage:pdfPageBefore];
    }
    PDFPage *pdfPageAfter = nil;
    if (pageNb < _totalPageNb + 1) {
        pdfPageAfter = [_pdfDocument pageAtIndex:pageNb + 1];
        pointPageAfter = [_pdfView convertPoint:point toPage:pdfPageAfter];
    }
    
    PDFPage *pdfPage = _pdfView.currentPage;
    
   
    point = [_pdfView convertPoint:point toPage:pdfPage];
    
    
    for (ClickableZone *object in _clickableZonesAdded) {
        
 
        if ((pageNb == object.pageNb && point.x > object.bounds.origin.x && point.x < object.bounds.origin.x + object.bounds.size.width
            && point.y > object.bounds.origin.y && point.y < object.bounds.origin.y + object.bounds.size.height) ||
            (pdfPageBefore && pageNb - 1 == object.pageNb && pointPageBefore.x > object.bounds.origin.x && pointPageBefore.x < object.bounds.origin.x + object.bounds.size.width
                && pointPageBefore.y > object.bounds.origin.y && pointPageBefore.y < object.bounds.origin.y + object.bounds.size.height) ||
            (pdfPageAfter && pageNb + 1 == object.pageNb && pointPageAfter.x > object.bounds.origin.x && pointPageAfter.x < object.bounds.origin.x + object.bounds.size.width
                && pointPageAfter.y > object.bounds.origin.y && pointPageAfter.y < object.bounds.origin.y + object.bounds.size.height)
            ) {
            NSLog(@"Annotation hit");
            if ([object.action isEqualToString:@"next"]) {
                _onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"onSwitchPage|%d", _page + 1]]});
            }
            if ([object.action isEqualToString:@"previous"]) {
                _onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"onSwitchPage|%d", _page - 1]]});
            }
            if ([object.action isEqualToString:@"edit_chart"]) {
                _onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"onEditChart|%@", object.param]]});
            }
        }
        
    }
}
/**
 *  Single Tap
 *  stop zoom
 *
 *  @param recognizer
 */
- (void)handleSingleTap:(UITapGestureRecognizer *)sender
{
    [self checkIfClickableTouched:sender];
    //_pdfView.scaleFactor = _pdfView.minScaleFactor;
    
    CGPoint point = [sender locationInView:self];
    PDFPage *pdfPage = [_pdfView pageForPoint:point nearest:NO];
    if (pdfPage) {
        
        if ([self annotationClicked:point] == YES)
            return;
        
        unsigned long page = [_pdfDocument indexForPage:pdfPage];
        
        point = [_pdfView convertPoint:point toPage:pdfPage];
        
        //BOOL canEdit = [_pdfDocument allowsCommenting];
      
        CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
        
        
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
            _onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"simpleClick|%f|%f|%lu|%d", x, y, page, pdfPage.rotation]]});
    //    }
    }
    
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
    ///[self onScaleChanged:Nil];
    
    /*
        CGPoint velocity = [sender velocityInView:_pdfView];
        CGFloat speed = sqrt(pow(velocity.x, 2) + pow(velocity.y, 2));
        CGFloat angle = atan2(velocity.y, velocity.x);
        angle = angle * (180.0 / M_PI);

        if (speed > 100) {
            CGPoint touchPoint = [sender locationInView:_pdfView];
            CGFloat pageHeight = _pdfView.bounds.size.height / _pdfView.scaleFactor;
            if (touchPoint.y < pageHeight * 0.1) {
                // User swiped near the top of the page
                NSLog(@"top");
            } else if (touchPoint.y > pageHeight * 0.9) {
                // User swiped near the bottom of the page
                NSLog(@"bottom");
            }
        }
    */
    
    [self didMove];
}


-(BOOL)imgAnnotationClicked:(CGPoint)point{
    
    PDFPage *pdfPage = [_pdfView pageForPoint:point nearest:NO];
    if (pdfPage) {
        unsigned long page = [_pdfDocument indexForPage:pdfPage];
        
        //point = [_pdfView convertPoint:point toPage:pdfPage];
        
        
        CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
        
        
        
        CGPoint pointOnPage = [_pdfView convertPoint:point toPage:pdfPage];

            for (PDFAnnotation *annotation in pdfPage.annotations) {
               
                if (pointOnPage.x >= annotation.bounds.origin.x && pointOnPage.x <= annotation.bounds.origin.x + annotation.bounds.size.width
                    && pointOnPage.y >= annotation.bounds.origin.y && pointOnPage.y <= annotation.bounds.origin.y + annotation.bounds.size.height)
                {
                    NSLog(@"Annotation hit: %@", annotation);
                }
            }
        
        
    }
    
    return NO;
}

-(BOOL)annotationClicked:(CGPoint)point{
	
	PDFPage *pdfPage = [_pdfView pageForPoint:point nearest:NO];
	if (pdfPage) {
		unsigned long page = [_pdfDocument indexForPage:pdfPage];
		
		//point = [_pdfView convertPoint:point toPage:pdfPage];
		
		
		CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
		
        
        /*
        CGPoint pointOnPage = [_pdfView convertPoint:point toPage:pdfPage];

            for (PDFAnnotation *annotation in pdfPage.annotations) {
               
                if (pointOnPage.x >= annotation.bounds.origin.x && pointOnPage.x <= annotation.bounds.origin.x + annotation.bounds.size.width
                    && pointOnPage.y >= annotation.bounds.origin.y && pointOnPage.y <= annotation.bounds.origin.y + annotation.bounds.size.height)
                {
                    NSLog(@"Annotation hit: %@", annotation);
                }
            }*/
        
        CGPoint convertedPoint = [self convertPointToPercent:point pdfPage:pdfPage];
       
        float annotationWidthMargin = 0.0;
        float annotationHeightMargin = 0.0;
        if (pdfPage.rotation == 90) {
            convertedPoint.y = 100 - convertedPoint.y;
            annotationWidthMargin = (10 / (_lastZoomLevel + 2));
        }
        else if (pdfPage.rotation == 270) {
            convertedPoint.x = 100 - convertedPoint.x;
            annotationWidthMargin = (10 / (_lastZoomLevel + 2));
        }
        else {
            convertedPoint.x = 100 - convertedPoint.x;
            annotationHeightMargin = (10 / (_lastZoomLevel + 2));
            annotationWidthMargin = (7 / (_lastZoomLevel + 2));
        }
        /*{
            float tmp = convertedPoint.x;
            convertedPoint.x = convertedPoint.y;
            convertedPoint.y = tmp;
        }*/
        NSLog(@"convertedPoint: %f %f",convertedPoint.x, convertedPoint.y);
		if (_annotations && [_annotations count] > 0) {
            
            
            /*if (pdfPage.rotation == 90)//  || pdfPage.rotation == 270)
            {
                point.x = pdfPageRect.size.height - point.x;
                point.y = pdfPageRect.size.width - point.y;
            }*/
            
			for (id object in _annotations) {
		
				long pageNb = [[object objectForKey:@"pageNb"] integerValue];
				
				if (pageNb != page)
					continue;
				
				float xPerc = [[object objectForKey:@"x"] floatValue];
				float yPerc = [[object objectForKey:@"y"] floatValue];
				
				//float x = pdfPageRect.size.width - (pdfPageRect.size.width * xPerc / 100);
				//float y = pdfPageRect.size.height - (pdfPageRect.size.height * yPerc / 100);
				
				
				
				//if (pageNb == page && x > point.x - 20 && x < point.x + 20
				//	&& y > point.y - 20 && y < point.y + 20)
                
                
                float allowedMargin = (3 / _lastZoomLevel);
                //float annotationWidthMargin = (5 / _lastZoomLevel);
                if (pageNb == page && xPerc > convertedPoint.x - allowedMargin && xPerc < convertedPoint.x + allowedMargin + annotationWidthMargin
                    && yPerc > convertedPoint.y - allowedMargin - (annotationHeightMargin / 2) && yPerc < convertedPoint.y + allowedMargin + (annotationHeightMargin / 2))
				{
                    NSString *uniqueIdOnClient = [object objectForKey:@"uniqueIdOnClient"];
					_onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"annotationClicked|%@|12", uniqueIdOnClient]]});
					return YES;
					
				}
			}
		}
	}
	
	return NO;
}

- (void) showAlert:(NSString *)Message {
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

- (void) setHighlighterPos:(int )isVertical :(float)positionPercent :(int)pageNb
{
    if (isVertical == 0) {
        _horizontalHighlightPosPercent = positionPercent;
        _horizontalHighlightPosPageNb = pageNb;
    }
    else {
        _verticalHighlightPosPercent = positionPercent;
        _verticalHighlightPosPageNb = pageNb;
    }
    
}



- (float) getHighlighterHorizontalPos :(unsigned long) currentPageNb
{
    if (_horizontalHighlightPosPercent == -42.0f)
        return 0;
    
    PDFPage *pdfPage = [_pdfDocument pageAtIndex:_horizontalHighlightPosPageNb];
    
    CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
    
    
    float x = 0;
    float y = 0;
    
    if (pdfPage.rotation == 90) {
       y = 10;
        x = ((pdfPageRect.size.width * _horizontalHighlightPosPercent / 100) - pdfPageRect.origin.x);
        
        //CGRect targetRect = CGRectMake( x, y, 100, 100);
        //CGPoint tmpP = CGPointMake(y,  x);
        //CGPoint newPoint = [_pdfView convertPoint:tmpP fromPage:pdfPage];
        
       // NSLog(@"newPoint: %f, currentPage %i, highlightPage %i", newPoint.y, currentPageNb, _horizontalHighlightPosPageNb);
        
        
        //return newPoint.y;
    }
    else if (pdfPage.rotation == 270) {
        y = 10;
        x = pdfPageRect.size.width - ((pdfPageRect.size.width * _horizontalHighlightPosPercent / 100) - pdfPageRect.origin.x);
    }
    else {
        x = 100;
        y = pdfPageRect.size.height - ((pdfPageRect.size.height * _horizontalHighlightPosPercent / 100) - pdfPageRect.origin.y);
    }
    
    
   // CGRect targetRect = CGRectMake( x - 5, y, 100, 100);

    
    CGPoint tmpP = CGPointMake(x,  y);
    CGPoint newPoint = [_pdfView convertPoint:tmpP fromPage:pdfPage];
    
   // NSLog(@"newPoint: %f, currentPage %i, highlightPage %i", newPoint.y, currentPageNb, _horizontalHighlightPosPageNb);
    
    
    return newPoint.y;
}


- (float) getHighlighterVerticalPos :(unsigned long) currentPageNb
{
    if (_verticalHighlightPosPercent == -42.0f)
        return 0;
    
    PDFPage *pdfPage = [_pdfDocument pageAtIndex:_verticalHighlightPosPageNb];
    
    CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
    
    
    float x = 0;
    float y = 0;

    if (pdfPage.rotation == 90) {
       y = (pdfPageRect.size.height * (_verticalHighlightPosPercent) / 100);
       x = (pdfPageRect.size.height * 50 / 100);
    }
    else if (pdfPage.rotation == 270) {
        y = pdfPageRect.size.height - (pdfPageRect.size.height * (_verticalHighlightPosPercent) / 100);
        x = (pdfPageRect.size.height * 50 / 100);
    }
    else {
        x = pdfPageRect.size.width * _verticalHighlightPosPercent / 100;
        y = pdfPageRect.size.height - (pdfPageRect.size.height * 50 / 100);
    }
    
    //CGRect targetRect = CGRectMake(x, y, 10, 10);

    
    CGPoint tmpP = CGPointMake(x,  y);
    CGPoint newPoint = [_pdfView convertPoint:tmpP fromPage:pdfPage];
    
    NSLog(@"newPoint: %f, currentPage %i, highlightPageNb %i _verticalHighlightPosPageNb %f", newPoint.x, currentPageNb, _verticalHighlightPosPageNb, _verticalHighlightPosPercent);
    
    
    return newPoint.x;
}



/**
 *  Do nothing on long Press
 *
 *
 */
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender{
    
	CGPoint point = [sender locationInView:self];
	
   // PDFImageAnnotation *annotation = [_drawingsAdded objectAtIndex:0];
   // [annotation redraw];
    
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
		CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
		
		
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

//can only handle one page
- (NSString *) convertPoints:(NSString *)input
{
    NSError *e = nil;
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData: data options: NSJSONReadingMutableContainers error: &e];

    NSArray* pointsArray = [jsonData objectForKey:@"points"];
    
    NSMutableArray *outputArray = [@[] mutableCopy];
    
    NSLog(@"xcode input: %@", input);
    unsigned long page = 0;
    
    //find most southern point
    float maxY = 0;
    for (id object in pointsArray) {
        float y = [[object objectForKey:@"y"] floatValue];
        
        if (y > maxY)
            maxY = y;
    }
    
    PDFPage *pdfPageStart = [_pdfView pageForPoint:CGPointMake(0, maxY) nearest:YES];
    page = [_pdfDocument indexForPage:pdfPageStart];
    
    for (id object in pointsArray) {
        float x = [[object objectForKey:@"x"] floatValue];
        float y = [[object objectForKey:@"y"] floatValue];

        
        CGPoint point = CGPointMake(x, y);
        
    
        CGPoint convertedPoint = [self convertPointToPercent:point pdfPage:pdfPageStart];
  
        
        NSDictionary *obj = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithFloat:convertedPoint.x], @"x",
                             [NSNumber numberWithFloat:convertedPoint.y], @"y",
        nil];

        

        [outputArray addObject:obj]; // Works with NSMutableArray
        
    }
    

    NSDictionary *dict = @{ @"pageNb" : [NSNumber numberWithInt:page], @"points" : outputArray};
    NSData *jsonDataOut = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&e];
    NSString *jsonStringOut = [[NSString alloc] initWithData:jsonDataOut encoding:NSUTF8StringEncoding];

    NSLog(@"xcode output: %@", jsonStringOut);
    return jsonStringOut;
}

/*
//can handle points on different pages
- (NSString *) convertPointArray:(NSString *)input
{
    NSError *e = nil;
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData: data options: NSJSONReadingMutableContainers error: &e];

    NSArray* pointsArray = [jsonData objectForKey:@"points"];
    
    NSMutableArray *outputArray = [@[] mutableCopy];
    
    NSLog(@"xcode input: %@", input);
    unsigned long page = 0;
    

    
    
    
    for (id object in pointsArray) {
        float x = [[object objectForKey:@"x"] floatValue];
        float y = [[object objectForKey:@"y"] floatValue];

        PDFPage *pdfPage = [_pdfView pageForPoint:CGPointMake(x, y) nearest:YES];
        page = [_pdfDocument indexForPage:pdfPage];
        
        CGPoint point = CGPointMake(x, y);
        
    
        CGPoint convertedPoint = [self convertPointToPercent:point pdfPage:pdfPage];
        CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
        
        int pageWidth = pdfPageRect.size.width;
        int pageHeight = pdfPageRect.size.height;
        if (pdfPage.rotation == 90 || pdfPage.rotation == 270)
        {
            pageWidth = pdfPageRect.size.height;
            pageHeight =pdfPageRect.size.width;
        }
        
        NSDictionary *obj = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithFloat:convertedPoint.x], @"x",
                             [NSNumber numberWithFloat:convertedPoint.y], @"y",
                             [NSNumber numberWithInt:page], @"pageNb",
                             [NSNumber numberWithInt:pageWidth], @"pageWidth",
                             [NSNumber numberWithInt:pageHeight], @"pageHeight",
        nil];

        

        [outputArray addObject:obj]; // Works with NSMutableArray
        
    }
    

    NSDictionary *dict = @{ @"pageNb" : [NSNumber numberWithInt:page], @"points" : outputArray};
    NSData *jsonDataOut = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&e];
    NSString *jsonStringOut = [[NSString alloc] initWithData:jsonDataOut encoding:NSUTF8StringEncoding];

    NSLog(@"xcode output: %@", jsonStringOut);
    return jsonStringOut;
}
 */

- (NSDictionary *)processPoint:(float)x y:(float)y {
    PDFPage *pdfPage = [_pdfView pageForPoint:CGPointMake(x, y) nearest:YES];
    unsigned long page = [_pdfDocument indexForPage:pdfPage];
    
    CGPoint point = CGPointMake(x, y);
    CGPoint convertedPoint = [self convertPointToPercent:point pdfPage:pdfPage];
    CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
    
    int pageWidth = pdfPageRect.size.width;
    int pageHeight = pdfPageRect.size.height;
    if (pdfPage.rotation == 90 || pdfPage.rotation == 270) {
        pageWidth = pdfPageRect.size.height;
        pageHeight = pdfPageRect.size.width;
    }
    
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithFloat:convertedPoint.x], @"x",
            [NSNumber numberWithFloat:convertedPoint.y], @"y",
            [NSNumber numberWithUnsignedLong:page], @"pageNb",
            [NSNumber numberWithInt:pageWidth], @"pageWidth",
            [NSNumber numberWithInt:pageHeight], @"pageHeight",
            nil];
}

- (NSString *)convertPointArray:(NSString *)input {
    NSError *e = nil;
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data
                                                           options:NSJSONReadingMutableContainers
                                                             error:&e];
    
    NSArray *pointsArray = [jsonData objectForKey:@"points"];
    NSMutableArray *outputArray = [@[] mutableCopy];
    
//NSLog(@"xcode input: %@", input);
    
    for (id object in pointsArray) {
        float x = [[object objectForKey:@"x"] floatValue];
        float y = [[object objectForKey:@"y"] floatValue];
        
        NSDictionary *obj = [self processPoint:x y:y];
        [outputArray addObject:obj];
    }
    
    NSDictionary *dict = @{@"points": outputArray};
    
    NSData *jsonDataOut = [NSJSONSerialization dataWithJSONObject:dict
                                                         options:0
                                                           error:&e];
    NSString *jsonStringOut = [[NSString alloc] initWithData:jsonDataOut
                                                   encoding:NSUTF8StringEncoding];
    
//  NSLog(@"xcode output: %@", jsonStringOut);
    return jsonStringOut;
}




- (CGPoint) convertPointToPercent:(CGPoint)point pdfPage:(PDFPage *)pdfPage
{
   // PDFPage *pdfPage = [_pdfView pageForPoint:point nearest:NO];
    if (pdfPage) {
    
        point = [_pdfView convertPoint:point toPage:pdfPage];
        
        
        NSLog(@"xcode converted point: %f %f", point.x, point.y);
        //CGRect cgrect = [_pdfView convertRect:point toPage:pdfPage];
        
        CGRect pdfPageRect = [pdfPage boundsForBox:kPDFDisplayBoxMediaBox];
        
        
        float x;
        float y;
        
        x = (pdfPageRect.size.width - point.x) / pdfPageRect.size.width * 100;
                   y = (pdfPageRect.size.height + pdfPageRect.origin.y - point.y) / (pdfPageRect.size.height)  * 100;
        x = 100 - x;
        if (pdfPage.rotation == 90)
        {
            float tmp = x;
            x = 100 - y;
            y = tmp;
            
        }
        else if (pdfPage.rotation == 270) {
            float tmp = 100 - x;
            x = y;
            y = tmp;
        }
        
        
        return CGPointMake(x, y);

    }
    return CGPointMake(0, 0);
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
    
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [_pdfView addGestureRecognizer2:panRecognizer];
    panRecognizer.delegate = self;

    

    [self disableLongPressSubviews:_pdfView];
    
    UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                            action:@selector(handleLongPress:)];
    // Making sure the allowable movement isn not too narrow
    longPressRecognizer.allowableMovement=300;
    // Important: The duration must be long enough to allow taps but not longer than the period in which view opens the magnifying glass
    longPressRecognizer.minimumPressDuration=0.3;
    
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
    

    CGFloat windowWidth = _pdfView.bounds.size.width;
    CGFloat windowHeight = _pdfView.bounds.size.height;

    
    NSDictionary *topLeft = [self processPoint:0 y:0];
    NSDictionary *topRight = [self processPoint:windowWidth y:0];
    NSDictionary *middleLeft = [self processPoint:0 y:windowHeight / 2];
    NSDictionary *middleRight = [self processPoint:windowWidth y:windowHeight / 2];
    NSDictionary *bottomLeft = [self processPoint:0 y:windowHeight];
    NSDictionary *bottomRight = [self processPoint:windowWidth y:windowHeight];

    // Create the pagesVisibility dictionary
    NSDictionary *pagesVisibility = @{
        @"topLeft": topLeft,
        @"topRight": topRight,
        @"middleLeft": middleLeft,
        @"middleRight": middleRight,
        @"bottomLeft": bottomLeft,
        @"bottomRight": bottomRight
    };
/*
    // Add it to your main JSON dictionary
    NSDictionary *jsonDict = @{
        @"currentPage": @(pageNb + 1),
        @"pageFocusX": @(savedRect.origin.x),
        @"pageFocusY": @(savedRect.origin.y),
        @"width": @(savedRect.size.width),
        @"height": @(savedRect.size.height),
        @"zoom": @(zoom),
        @"positionOffset": @(posYFromSelectedPage),
        @"isLandscape": @(_isLandscape),
        @"highlighterHorizontalPos": @([self getHighlighterHorizontalPos:pageNb]),
        @"highlighterVerticalPos": @([self getHighlighterVerticalPos:pageNb]),
        @"pagesVisibility": pagesVisibility
    };*/

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:pagesVisibility
                                                      options:0
                                                        error:&error];
        
   
    NSString *jsonString = [[NSString alloc] initWithData:jsonData
                                                    encoding:NSUTF8StringEncoding];
     
    
    _onChange(@{ @"message": [[NSString alloc] initWithString:[NSString stringWithFormat:@"iosPositionChanged|%lu|%f|%f|%f|%f|%f|%f|%d|%f|%f|%@", (pageNb + 1), savedRect.origin.x,  savedRect.origin.y, savedRect.size.width, savedRect.size.height, zoom, posYFromSelectedPage, _isLandscape,  [self getHighlighterHorizontalPos :pageNb], [self getHighlighterVerticalPos :pageNb], jsonString ]]});
    
	//NSLog(@"has moved sending new pos %f", savedRect.origin.y);
}


- (void)didMove
{
    
   // NSLog(@"has moved");
	if (_timerPosition) {
		[_timerPosition invalidate];
	}
	_timerPosition = [NSTimer scheduledTimerWithTimeInterval:0.25
									 target:self
								   selector:@selector(sendNewPosition)
								   userInfo:nil
									repeats:NO];
    
    if (_timerPosition2) {
        [_timerPosition2 invalidate];
    }
    _timerPosition2 = [NSTimer scheduledTimerWithTimeInterval:0.7
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
