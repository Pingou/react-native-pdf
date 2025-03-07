/**
 * Copyright (c) 2017-present, Wonday (@wonday.org)
 * All rights reserved.
 *
 * This source code is licensed under the MIT-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import "RCTPdfViewManager.h"
#import "RCTPdfView.h"

RCTPdfView *RctpdfView;

@implementation RCTPdfViewManager

RCT_EXPORT_MODULE()

- (UIView *)view
{
    if([[[UIDevice currentDevice] systemVersion] compare:@"11.0" options:NSNumericSearch] == NSOrderedDescending
       || [[[UIDevice currentDevice] systemVersion] compare:@"11.0" options:NSNumericSearch] == NSOrderedSame) {
        RctpdfView = [[RCTPdfView alloc] init];
        
        return RctpdfView;
    } else {
        return NULL;
    }
  
}

RCT_EXPORT_VIEW_PROPERTY(path, NSString);
RCT_EXPORT_VIEW_PROPERTY(page, int);
RCT_EXPORT_VIEW_PROPERTY(scale, float);
RCT_EXPORT_VIEW_PROPERTY(minScale, float);
RCT_EXPORT_VIEW_PROPERTY(maxScale, float);
RCT_EXPORT_VIEW_PROPERTY(horizontal, BOOL);
RCT_EXPORT_VIEW_PROPERTY(enablePaging, BOOL);
RCT_EXPORT_VIEW_PROPERTY(enableRTL, BOOL);
RCT_EXPORT_VIEW_PROPERTY(enableAnnotationRendering, BOOL);
RCT_EXPORT_VIEW_PROPERTY(fitPolicy, int);
RCT_EXPORT_VIEW_PROPERTY(spacing, int);
RCT_EXPORT_VIEW_PROPERTY(password, NSString);
RCT_EXPORT_VIEW_PROPERTY(onChange, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(restoreViewState, NSString);
RCT_EXPORT_VIEW_PROPERTY(annotations, NSArray);
RCT_EXPORT_VIEW_PROPERTY(drawings, NSArray);
RCT_EXPORT_VIEW_PROPERTY(drawingsV2, NSArray);
RCT_EXPORT_VIEW_PROPERTY(highlightLines, NSArray);
RCT_EXPORT_VIEW_PROPERTY(enableDarkMode, BOOL);
RCT_EXPORT_VIEW_PROPERTY(showPagesNav, BOOL);
RCT_EXPORT_VIEW_PROPERTY(singlePage, BOOL);
RCT_EXPORT_VIEW_PROPERTY(chartStart, NSString);
RCT_EXPORT_VIEW_PROPERTY(chartEnd, NSString);
RCT_EXPORT_VIEW_PROPERTY(chartHighlights, NSArray);
RCT_EXPORT_METHOD(supportPDFKit:(RCTResponseSenderBlock)callback)
{
    if([[[UIDevice currentDevice] systemVersion] compare:@"11.0" options:NSNumericSearch] == NSOrderedDescending
       || [[[UIDevice currentDevice] systemVersion] compare:@"11.0" options:NSNumericSearch] == NSOrderedSame) {
        callback(@[@YES]);
    } else {
        callback(@[@NO]);
    }
    
}

RCT_EXPORT_METHOD(getConvertedPoints:(NSString *)input :(RCTResponseSenderBlock)callback)
{
    
   // NSString *output = [RctpdfView convertPoints:@"{\"points\":[{\"x\":0, \"y\":0}, {\"x\":12, \"y\":122}, {\"x\":31, \"y\":2}]}"];
    NSString *output = [RctpdfView convertPoints:input];
    callback(@[output]);
  /*
    if([[[UIDevice currentDevice] systemVersion] compare:@"11.0" options:NSNumericSearch] == NSOrderedDescending
       || [[[UIDevice currentDevice] systemVersion] compare:@"11.0" options:NSNumericSearch] == NSOrderedSame) {
        callback(@[@YES]);
    } else {
        callback(@[@NO]);
    }
    */
}

//can handle points on different pages
RCT_EXPORT_METHOD(getConvertedPointArray:(NSString *)input :(RCTResponseSenderBlock)callback)
{

    NSString *output = [RctpdfView convertPointArray:input];
    callback(@[output]);
  
}

//can handle points on different pages
RCT_EXPORT_METHOD(setDrawingsDynamically:(NSArray *)drawings)
{
    [RctpdfView setDrawingsDynamically:drawings];
}


RCT_EXPORT_METHOD(setHighlighterPos:(int)isVertical :(float)positionPercent :(int)pageNb)
{
    
   // NSString *output = [RctpdfView convertPoints:@"{\"points\":[{\"x\":0, \"y\":0}, {\"x\":12, \"y\":122}, {\"x\":31, \"y\":2}]}"];
    [RctpdfView setHighlighterPos:isVertical :positionPercent :pageNb];

  /*
    if([[[UIDevice currentDevice] systemVersion] compare:@"11.0" options:NSNumericSearch] == NSOrderedDescending
       || [[[UIDevice currentDevice] systemVersion] compare:@"11.0" options:NSNumericSearch] == NSOrderedSame) {
        callback(@[@YES]);
    } else {
        callback(@[@NO]);
    }
    */
}



+ (BOOL)requiresMainQueueSetup {
    return YES;
}


- (void)dealloc{
}

@end
