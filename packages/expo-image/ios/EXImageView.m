// Copyright 2020-present 650 Industries. All rights reserved.

#import <expo-image/EXImageView.h>
#import <expo-image/EXImageBorders.h>
#import <expo-image/EXImageCornerRadii.h>
#import <React/RCTConvert.h>
#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <React/RCTI18nUtil.h>
#import <React/RCTBorderDrawing.h>

static NSString * const sourceUriKey = @"uri";
static NSString * const sourceScaleKey = @"scale";
static NSString * const sourceWidthKey = @"width";
static NSString * const sourceHeightKey = @"height";

@interface EXImageView ()

@property (nonatomic, weak) RCTBridge *bridge;
@property (nonatomic, strong) SDAnimatedImageView *imageView;
@property (nonatomic, strong) NSDictionary *source;
@property (nonatomic, assign) RCTResizeMode resizeMode;
@property (nonatomic, assign) BOOL needsReload;
@property (nonatomic, assign) CGSize intrinsicContentSize;
@property (nonatomic, assign) EXImageCornerRadii cornerRadii;
@property (nonatomic, assign) EXImageBorders borders;
@property (nonatomic, strong) NSDictionary<NSString *, CALayer *> *borderLayers;

@end

@implementation EXImageView

- (instancetype)initWithBridge:(RCTBridge *)bridge
{
  if (self = [super init]) {
    _bridge = bridge;
    _needsReload = NO;
    _resizeMode = RCTResizeModeCover;
    _intrinsicContentSize = CGSizeZero;
    _cornerRadii = EXImageCornerRadiiInit();
    _borders = EXImageBordersInit();
    _borderLayers = @{};

    _imageView = [SDAnimatedImageView new];
    _imageView.frame = self.bounds;
    _imageView.contentMode = [EXImageTypes resizeModeToContentMode:_resizeMode];
    _imageView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    _imageView.layer.masksToBounds = YES;
    
    [self addSubview:_imageView];
  }
  return self;
}

- (void)dealloc
{
  // Stop any active operations or downloads
  [_imageView sd_cancelCurrentImageLoad];  
  EXImageBordersRelease(_borders);
}

# pragma mark -  Custom prop setters

- (void)setSource:(NSDictionary *)source
{
  _source = source;
  // TODO: Implement equatable image source abstraction
  _needsReload = YES;
}

- (void)setResizeMode:(RCTResizeMode)resizeMode
{
  if (_resizeMode == resizeMode) {
    return;
  }
  
  // Update resize-mode. Image repeat is handled in the completion-block
  // and requires a reload of the image for the post-process function to run.
  _needsReload = _needsReload || (resizeMode == RCTResizeModeRepeat) || (_resizeMode == RCTResizeModeRepeat);
  _resizeMode = resizeMode;
  _imageView.contentMode = [EXImageTypes resizeModeToContentMode:resizeMode];
}

- (void)didSetProps:(NSArray<NSString *> *)changedProps
{
  if (_needsReload) {
    _needsReload = NO;
    [self updateImage];
  }
}

- (void)updateImage
{
  // We want to call onError, onLoadEnd for the previous image load
  // before calling onLoadStart for the next image load.
  [self sd_cancelCurrentImageLoad];

  if (self.onLoadStart) {
    self.onLoadStart(@{});
  }

  NSURL *imageURL = [RCTConvert NSURL:_source[sourceUriKey]];
  NSNumber *scale = _source[sourceScaleKey];
  NSNumber *width = _source[sourceWidthKey];
  NSNumber *height = _source[sourceHeightKey];
  RCTResizeMode resizeMode = _resizeMode;
  
  // For local assets, the intrinsic image size is passed down in the source.
  // This means we can set it immediately without having to wait for the
  // image content to load.
  if (width && height) {
    [self updateIntrinsicContentSize:CGSizeMake(width.doubleValue, height.doubleValue) internalAsset:YES];
  }
  
  NSMutableDictionary *context = [NSMutableDictionary new];

  // Only apply custom scale factors when neccessary. The scale factor
  // affects how the image is rendered when resizeMode `center` and `repeat`
  // are used. On animated images, applying a scale factor may cause
  // re-encoding of the data, which should be avoided when possible.
  if (scale && scale.doubleValue != 1.0) {
    [context setValue:scale forKey:SDWebImageContextImageScaleFactor];
  }

  [_imageView sd_setImageWithURL:imageURL
          placeholderImage:nil
                   options:SDWebImageAvoidAutoSetImage
                   context:context
                  progress:[self progressBlock]
                 completed:[self completionBlock]];
}

- (SDImageLoaderProgressBlock)progressBlock
{
  __weak EXImageView *weakSelf = self;
  return ^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
    __strong EXImageView *strongSelf = weakSelf;
    if (!strongSelf) {
      // Nothing to do
      return;
    }

    if (strongSelf.onProgress) {
      strongSelf.onProgress(@{
        @"loaded": @(receivedSize),
        @"total": @(expectedSize)
      });
    }
  };
}

- (SDExternalCompletionBlock)completionBlock
{
  RCTResizeMode resizeMode = _resizeMode;
  NSNumber *width = _source && _source[sourceWidthKey] ? _source[sourceWidthKey] : nil;
  NSNumber *height = _source && _source[sourceHeightKey] ? _source[sourceHeightKey] : nil;
  
  __weak EXImageView *weakSelf = self;
  return ^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
    __strong EXImageView *strongSelf = weakSelf;
    if (!strongSelf) {
      // Nothing to do
      return;
    }

    // Modifications to the image like changing the resizing-mode or cap-insets
    // cannot be handled using a SDWebImage transformer, because they don't change
    // the image-data and this causes this "meta" data to be lost in the SDWebImage caching process.
    if (image) {
      if (resizeMode == RCTResizeModeRepeat) {
        image = [image resizableImageWithCapInsets:UIEdgeInsetsZero resizingMode:UIImageResizingModeTile];
      }
    }
    
    // When no explicit source image size was specified, use the dimensions
    // of the loaded image as the intrinsic content size.
    if (!width && !height) {
      [strongSelf updateIntrinsicContentSize:image.size internalAsset:NO];
    }

    // Update image
    strongSelf.imageView.image = image;

    if (error && strongSelf.onError) {
      strongSelf.onError(@{
        @"error": error.localizedDescription,
        @"ios": @{
            @"code": @(error.code),
            @"domain": error.domain,
            @"description": error.localizedDescription,
            @"helpAnchor": error.helpAnchor ?: [NSNull null],
            @"failureReason": error.localizedFailureReason ?: [NSNull null],
            @"recoverySuggestion": error.localizedRecoverySuggestion ?: [NSNull null]
        }
      });
    } else if (image && strongSelf.onLoad) {
      strongSelf.onLoad(@{
        @"cacheType": @([EXImageTypes convertToCacheTypeEnum:cacheType]),
        @"source": @{
            @"url": imageURL.absoluteString,
            @"width": @(image.size.width),
            @"height": @(image.size.height),
            @"mediaType": [EXImageTypes sdImageFormatToMediaType:image.sd_imageFormat] ?: [NSNull null]
        }
      });
    }
  };
}


- (void)setBackgroundColor:(UIColor *)backgroundColor
{
  _imageView.backgroundColor = backgroundColor;
}

- (void)displayLayer:(CALayer *)layer
{
  if (CGSizeEqualToSize(layer.bounds.size, CGSizeZero)) {
    return;
  }
  
  CGRect bounds = self.bounds;
  BOOL swapLeftRightInRTL = [[RCTI18nUtil sharedInstance] doLeftAndRightSwapInRTL];
  EXImageCornerRadii cornerRadii = EXImageCornerRadiiResolve(_cornerRadii, _reactLayoutDirection, swapLeftRightInRTL, bounds.size);
  EXImageBorders borders = EXImageBordersResolve(_borders, _reactLayoutDirection, swapLeftRightInRTL);
  
  [self updateClipMaskForCornerRadii:cornerRadii bounds:bounds];
  [self updateBorderLayersForBorders:borders cornerRadii:cornerRadii bounds:bounds];
}

- (void)setReactLayoutDirection:(UIUserInterfaceLayoutDirection)layoutDirection
{
  if (_reactLayoutDirection != layoutDirection) {
    _reactLayoutDirection = layoutDirection;
    [self.layer setNeedsDisplay];
  }
  
  if ([self respondsToSelector:@selector(setSemanticContentAttribute:)]) {
    self.semanticContentAttribute = layoutDirection == UIUserInterfaceLayoutDirectionLeftToRight
    ? UISemanticContentAttributeForceLeftToRight
    : UISemanticContentAttributeForceRightToLeft;
  }
}

# pragma mark -  Intrinsic content size

- (CGSize)intrinsicContentSize
{
  return _intrinsicContentSize;
}

- (void)updateIntrinsicContentSize:(CGSize)intrinsicContentSize internalAsset:(BOOL)internalAsset
{
  if (!CGSizeEqualToSize(_intrinsicContentSize, intrinsicContentSize)) {
    _intrinsicContentSize = intrinsicContentSize;
    
    // Only inform Yoga of the intrinsic image size when needed.
    // Yoga already knows about the size of the internal assets, and
    // only needs to be informed about the intrinsic content size when
    // no size styles were provided to the component. Always updating
    // the intrinsicContentSize will cause unnecessary layout passes
    // which we want to avoid.
    if (!internalAsset && CGRectIsEmpty(self.bounds)) {
      [_bridge.uiManager setIntrinsicContentSize:intrinsicContentSize forView:self];
    }
  }
}

#pragma mark - Border Radius

#define setBorderRadius(side, var)                       \
-(void)setBorder##side##Radius : (NSNumber *)radius      \
{                                                        \
CGFloat val = (radius != nil) ? radius.doubleValue : -1; \
if (_cornerRadii.var == val) {                           \
return;                                                  \
}                                                        \
_cornerRadii.var = val;                                  \
[self.layer setNeedsDisplay];                            \
}

setBorderRadius(,all)
setBorderRadius(TopLeft, topLeft)
setBorderRadius(TopRight, topRight)
setBorderRadius(TopStart, topStart)
setBorderRadius(TopEnd, topEnd)
setBorderRadius(BottomLeft, bottomLeft)
setBorderRadius(BottomRight, bottomRight)
setBorderRadius(BottomStart, bottomStart)
setBorderRadius(BottomEnd, bottomEnd)

- (void)updateClipMaskForCornerRadii:(EXImageCornerRadii)cornerRadii bounds:(CGRect)bounds
{
  CALayer *mask = nil;
  CGFloat cornerRadius = 0;
  
  if (EXImageCornerRadiiAllEqual(cornerRadii)) {
    cornerRadius = cornerRadii.topLeft;
  } else {
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    RCTCornerInsets cornerInsets = EXImageGetCornerInsets(cornerRadii, UIEdgeInsetsZero);
    CGPathRef path = RCTPathCreateWithRoundedRect(bounds, cornerInsets, NULL);
    shapeLayer.path = path;
    CGPathRelease(path);
    mask = shapeLayer;
  }
  
  _imageView.layer.cornerRadius = cornerRadius;
  _imageView.layer.mask = mask;
  _imageView.layer.masksToBounds = YES;
}


#pragma mark Border Color / Width / Style

#define setBorder(side, var)                              \
-(void)setBorder##side##Color : (CGColorRef)color         \
{                                                         \
if (CGColorEqualToColor(_borders.var.color, color)) {     \
return;                                                   \
}                                                         \
CGColorRelease(_borders.var.color);                       \
_borders.var.color = CGColorRetain(color);                \
[self.layer setNeedsDisplay];                             \
}                                                         \
-(void)setBorder##side##Width : (NSNumber *)width         \
{                                                         \
CGFloat val = (width != nil) ? width.doubleValue : -1;    \
if (_borders.var.width == val) {                          \
return;                                                   \
}                                                         \
_borders.var.width = val;                                 \
[self.layer setNeedsDisplay];                             \
}                                                         \
-(void)setBorder##side##Style : (RCTBorderStyle)style     \
{                                                         \
if (_borders.var.style == style) {                        \
return;                                                   \
}                                                         \
_borders.var.style = style;                               \
[self.layer setNeedsDisplay];                             \
}

setBorder(,all)
setBorder(Top,top)
setBorder(Right,right)
setBorder(Bottom,bottom)
setBorder(Left,left)
setBorder(Start,start)
setBorder(End,end)

- (void)updateBorderLayersForBorders:(EXImageBorders)borders cornerRadii:(EXImageCornerRadii)cornerRadii bounds:(CGRect)bounds
{
  NSMutableDictionary<NSString *, CALayer *> *borderLayers = [NSMutableDictionary dictionary];
  
  // Shape-layers draw the stroke in the middle of the path. The border should
  // however be drawn on the inside of the outer path. Therefore calculate the path
  // for CAShapeLayer with an offset to the outside path, so that the stroke edges
  // line-up with the outside path.
  UIEdgeInsets edgeInsets = UIEdgeInsetsMake(borders.top.width * 0.5, borders.left.width * 0.5, borders.bottom.width * 0.5, borders.right.width * 0.5);
  RCTCornerInsets cornerInsets = EXImageGetCornerInsets(cornerRadii, edgeInsets);
  CGPathRef shapeLayerPath = RCTPathCreateWithRoundedRect(UIEdgeInsetsInsetRect(bounds, edgeInsets), cornerInsets, NULL);
  
  // Optimized code-path using a single layer when with no required masking
  // This code-path is preferred and yields the best possible performance.
  // When possible, a simple CALayer with optional corner-radius is used.
  // In case the corner-radii are different, a single CAShapeLayer will be used.
  if (EXImageBordersAllEqual(borders)) {
    EXImageBorder border = borders.top;
    if (EXImageBorderVisible(border)) {
      CALayer *borderLayer = _borderLayers[@"all"];
      if ((border.style == RCTBorderStyleSolid) &&
          EXImageCornerRadiiAllEqual(cornerRadii)) {
        borderLayer = EXImageBorderSimpleLayer(borderLayer, border, bounds, cornerRadii.topLeft);
      } else {
        borderLayer = EXImageBorderShapeLayer(borderLayer, border, bounds, shapeLayerPath, nil);
      }
      [borderLayers setValue:borderLayer forKey:@"all"];
    }
  } else {
    
    // Define a layer for each visible border. Each layer is masked so that it only
    // shows that edge.
    if (EXImageBorderVisible(borders.top)) {
      [borderLayers setValue:EXImageBorderShapeLayer(_borderLayers[@"top"], borders.top, bounds, shapeLayerPath, EXImageBorderMask(bounds, EXImageBorderLocationTop, borders)) forKey:@"top"];
    }
    if (EXImageBorderVisible(borders.right)) {
      [borderLayers setValue:EXImageBorderShapeLayer(_borderLayers[@"right"], borders.right, bounds, shapeLayerPath, EXImageBorderMask(bounds, EXImageBorderLocationRight, borders)) forKey:@"right"];
    }
    if (EXImageBorderVisible(borders.bottom)) {
      [borderLayers setValue:EXImageBorderShapeLayer(_borderLayers[@"bottom"], borders.bottom, bounds, shapeLayerPath, EXImageBorderMask(bounds, EXImageBorderLocationBottom, borders)) forKey:@"bottom"];
    }
    if (EXImageBorderVisible(borders.left)) {
      [borderLayers setValue:EXImageBorderShapeLayer(_borderLayers[@"left"], borders.left, bounds, shapeLayerPath, EXImageBorderMask(bounds, EXImageBorderLocationLeft, borders)) forKey:@"left"];
    }
  }
  CGPathRelease(shapeLayerPath);
  
  // Add new/updated layers
  for (NSString* key in borderLayers) {
    CALayer *layer = borderLayers[key];
    if (_borderLayers[key] != layer) {
      [_imageView.layer addSublayer:layer];
    }
  }
  
  // Remove old layers
  for (NSString* key in _borderLayers) {
    CALayer *layer = _borderLayers[key];
    if (borderLayers[key] != layer) {
      [layer removeFromSuperlayer];
    }
  }
  _borderLayers = borderLayers;
}

@end
