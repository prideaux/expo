// Copyright 2020-present 650 Industries. All rights reserved.

#import <SDWebImage/SDWebImage.h>
#import <expo-image/EXImageView.h>
#import <expo-image/EXImageTypes.h>
#import <React/RCTComponent.h>
#import <React/UIView+React.h>
#import <React/RCTResizeMode.h>
#import <React/RCTBorderStyle.h>

@class RCTBridge;

@interface EXImageView : UIView

@property (nonatomic, copy) RCTDirectEventBlock onLoadStart;
@property (nonatomic, copy) RCTDirectEventBlock onProgress;
@property (nonatomic, copy) RCTDirectEventBlock onError;
@property (nonatomic, copy) RCTDirectEventBlock onLoad;

- (instancetype)initWithBridge:(RCTBridge *)bridge NS_DESIGNATED_INITIALIZER;

- (void)setSource:(NSDictionary *)sourceMap;
- (void)setResizeMode:(RCTResizeMode)resizeMode;

- (void)didSetProps:(NSArray<NSString *> *)changedProps;

@property (nonatomic, assign) UIUserInterfaceLayoutDirection reactLayoutDirection;

/**
 * Border radii.
 */
@property (nonatomic, copy) NSNumber *borderRadius;
@property (nonatomic, copy) NSNumber *borderTopLeftRadius;
@property (nonatomic, copy) NSNumber *borderTopRightRadius;
@property (nonatomic, copy) NSNumber *borderTopStartRadius;
@property (nonatomic, copy) NSNumber *borderTopEndRadius;
@property (nonatomic, copy) NSNumber *borderBottomLeftRadius;
@property (nonatomic, copy) NSNumber *borderBottomRightRadius;
@property (nonatomic, copy) NSNumber *borderBottomStartRadius;
@property (nonatomic, copy) NSNumber *borderBottomEndRadius;

/**
 * Border colors (actually retained).
 */
@property (nonatomic, assign) CGColorRef borderTopColor;
@property (nonatomic, assign) CGColorRef borderRightColor;
@property (nonatomic, assign) CGColorRef borderBottomColor;
@property (nonatomic, assign) CGColorRef borderLeftColor;
@property (nonatomic, assign) CGColorRef borderStartColor;
@property (nonatomic, assign) CGColorRef borderEndColor;
@property (nonatomic, assign) CGColorRef borderColor;

/**
 * Border widths.
 */
@property (nonatomic, copy) NSNumber *borderTopWidth;
@property (nonatomic, copy) NSNumber *borderRightWidth;
@property (nonatomic, copy) NSNumber *borderBottomWidth;
@property (nonatomic, copy) NSNumber *borderLeftWidth;
@property (nonatomic, copy) NSNumber *borderStartWidth;
@property (nonatomic, copy) NSNumber *borderEndWidth;
@property (nonatomic, copy) NSNumber *borderWidth;

/**
 * Border styles.
 */
@property (nonatomic, assign) RCTBorderStyle borderTopStyle;
@property (nonatomic, assign) RCTBorderStyle borderRightStyle;
@property (nonatomic, assign) RCTBorderStyle borderBottomStyle;
@property (nonatomic, assign) RCTBorderStyle borderLeftStyle;
@property (nonatomic, assign) RCTBorderStyle borderStartStyle;
@property (nonatomic, assign) RCTBorderStyle borderEndStyle;
@property (nonatomic, assign) RCTBorderStyle borderStyle;

@end
