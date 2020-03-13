// Copyright 2020-present 650 Industries. All rights reserved.

#import <expo-image/EXImageViewManager.h>
#import <expo-image/EXImageView.h>

#import <React/RCTImageShadowView.h>

@implementation EXImageViewManager

RCT_EXPORT_MODULE(ExpoImage)

- (RCTShadowView *)shadowView
{
  return [RCTImageShadowView new];
}


RCT_EXPORT_VIEW_PROPERTY(source, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(resizeMode, RCTResizeMode)

RCT_EXPORT_VIEW_PROPERTY(onLoadStart, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onProgress, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onError, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLoad, RCTDirectEventBlock)

// borderRadius setter are overriden using NSNumber *
// in order to support resetting the property when the
// prop is no longer passed to the component
RCT_EXPORT_VIEW_PROPERTY(borderRadius, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(borderTopLeftRadius, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(borderTopRightRadius, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(borderTopStartRadius, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(borderTopEndRadius, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(borderBottomLeftRadius, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(borderBottomRightRadius, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(borderBottomStartRadius, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(borderBottomEndRadius, NSNumber)

// borderWidth setters are overriden using NSNumber *
// in order to support resetting the property when the
// prop is no longer passed to the component
RCT_EXPORT_VIEW_PROPERTY(borderWidth, NSNumber*)
RCT_EXPORT_VIEW_PROPERTY(borderTopWidth, NSNumber*)
RCT_EXPORT_VIEW_PROPERTY(borderRightWidth, NSNumber*)
RCT_EXPORT_VIEW_PROPERTY(borderBottomWidth, NSNumber*)
RCT_EXPORT_VIEW_PROPERTY(borderLeftWidth, NSNumber*)
RCT_EXPORT_VIEW_PROPERTY(borderStartWidth, NSNumber*)
RCT_EXPORT_VIEW_PROPERTY(borderEndWidth, NSNumber*)

- (UIView *)view
{
  return [[EXImageView alloc] initWithBridge:self.bridge];
}

@end
