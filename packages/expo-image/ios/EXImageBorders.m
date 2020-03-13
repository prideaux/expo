// Copyright 2020-present 650 Industries. All rights reserved.

#import <expo-image/EXImageBorders.h>
#import <React/RCTUtils.h>

static const CGFloat EXImageViewBorderThreshold = 0.001;

EXImageBorder EXImageBorderMake(CGFloat width, CGColorRef color, RCTBorderStyle style)
{
  EXImageBorder border;
  border.width = width;
  border.color = color;
  border.style = style;
  return border;
}

EXImageBorders EXImageBordersInit()
{
  EXImageBorders borders;
  EXImageBorder border = EXImageBorderMake(-1, nil, RCTBorderStyleUnset);
  borders.all = EXImageBorderMake(-1, nil, RCTBorderStyleSolid);
  borders.top = border;
  borders.right = border;
  borders.bottom = border;
  borders.left = border;
  borders.start = border;
  borders.end = border;
  return borders;
}

void EXImageBordersRelease(EXImageBorders borders)
{
  CGColorRelease(borders.all.color);
  CGColorRelease(borders.top.color);
  CGColorRelease(borders.right.color);
  CGColorRelease(borders.bottom.color);
  CGColorRelease(borders.left.color);
  CGColorRelease(borders.start.color);
  CGColorRelease(borders.end.color);
}

EXImageBorder EXImageBorderResolve(EXImageBorder border, EXImageBorder defaultBorder)
{
  return EXImageBorderMake(
                           (border.width > -1) ?border.width : defaultBorder.width,
                           border.color ? border.color : defaultBorder.color,
                           (border.style != RCTBorderStyleUnset) ? border.style : defaultBorder.style
                           );
}

EXImageBorders EXImageBordersResolve(EXImageBorders borders, UIUserInterfaceLayoutDirection layoutDirection, BOOL swapLeftRightInRTL)
{
  EXImageBorder identityBorder = EXImageBorderMake(-1, nil, RCTBorderStyleSolid);
  EXImageBorder defaultBorder = EXImageBorderResolve(borders.all, identityBorder);
  
  EXImageBorders result;
  result.all = identityBorder;
  result.start = identityBorder;
  result.end = identityBorder;
  result.top = EXImageBorderResolve(borders.top, defaultBorder);
  result.bottom = EXImageBorderResolve(borders.bottom, defaultBorder);
  
  const BOOL isRTL = layoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
  if (swapLeftRightInRTL) {
    EXImageBorder startEdge = EXImageBorderResolve(borders.left, borders.start);
    EXImageBorder endEdge = EXImageBorderResolve(borders.right, borders.end);
    EXImageBorder leftEdge = isRTL ? endEdge : startEdge;
    EXImageBorder rightEdge = isRTL ? startEdge : endEdge;
    result.left = EXImageBorderResolve(leftEdge, defaultBorder);
    result.right = EXImageBorderResolve(rightEdge, defaultBorder);
  } else {
    EXImageBorder leftEdge = isRTL ? borders.end : borders.start;
    EXImageBorder rightEdge = isRTL ? borders.start : borders.end;
    result.left = EXImageBorderResolve(EXImageBorderResolve(leftEdge, borders.left), defaultBorder);
    result.right = EXImageBorderResolve(EXImageBorderResolve(rightEdge, borders.right), defaultBorder);
  }
  return result;
}

BOOL EXImageBorderEqualTo(EXImageBorder border, EXImageBorder equalToBorder)
{
  return (ABS(border.width - equalToBorder.width) < EXImageViewBorderThreshold)
  && (border.style == equalToBorder.style)
  && CGColorEqualToColor(border.color, equalToBorder.color);
}

BOOL EXImageBordersAllEqual(EXImageBorders borders)
{
  return EXImageBorderEqualTo(borders.top, borders.right)
  && EXImageBorderEqualTo(borders.top, borders.bottom)
  && EXImageBorderEqualTo(borders.top, borders.left);
}

BOOL EXImageBorderVisible(EXImageBorder border)
{
  return border.color
  && (border.width >= EXImageViewBorderThreshold)
  && (border.style != RCTBorderStyleUnset);
}

CALayer *EXImageBorderMask(CGRect bounds, EXImageBorderLocation location, EXImageBorders borders)
{
  UIBezierPath *path = [UIBezierPath bezierPath];
  switch (location) {
    case EXImageBorderLocationLeft:
      [path moveToPoint:bounds.origin];
      if (!EXImageBorderVisible(borders.top)) {
        [path addLineToPoint:CGPointMake(bounds.origin.x + borders.left.width, bounds.origin.y)];
        [path addLineToPoint:CGPointMake(bounds.origin.x + borders.left.width, bounds.origin.y + bounds.size.height * 0.5)];
      }
      [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.height * 0.5, bounds.origin.y + bounds.size.height * 0.5)];
      if (!EXImageBorderVisible(borders.bottom)) {
        [path addLineToPoint:CGPointMake(bounds.origin.x + borders.left.width, bounds.origin.y + bounds.size.height * 0.5)];
        [path addLineToPoint:CGPointMake(bounds.origin.x + borders.left.width, bounds.origin.y + bounds.size.height)];
      }
      [path addLineToPoint:CGPointMake(bounds.origin.x, bounds.origin.y + bounds.size.height)];
      break;
    case EXImageBorderLocationTop:
      [path moveToPoint:bounds.origin];
      if (!EXImageBorderVisible(borders.left)) {
        [path addLineToPoint:CGPointMake(bounds.origin.x, bounds.origin.y + borders.top.width)];
        [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width * 0.5, bounds.origin.y + borders.top.width)];
      }
      [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width * 0.5, bounds.origin.y + bounds.size.width * 0.5)];
      if (!EXImageBorderVisible(borders.right)) {
        [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width * 0.5, bounds.origin.y + borders.top.width)];
        [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width, bounds.origin.y + borders.top.width)];
      }
      [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width, bounds.origin.y)];
      break;
    case EXImageBorderLocationRight:
      [path moveToPoint:CGPointMake(bounds.origin.x + bounds.size.width, bounds.origin.y)];
      if (!EXImageBorderVisible(borders.top)) {
        [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width - borders.right.width, bounds.origin.y)];
        [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width - borders.right.width, bounds.size.height * 0.5)];
      }
      [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width - bounds.size.height * 0.5, bounds.origin.y + bounds.size.height * 0.5)];
      if (!EXImageBorderVisible(borders.bottom)) {
        [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width - borders.right.width, bounds.size.height * 0.5)];
        [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width - borders.right.width, bounds.origin.y + bounds.size.height)];
      }
      [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height)];
      break;
    case EXImageBorderLocationBottom:
      [path moveToPoint:CGPointMake(bounds.origin.x, bounds.origin.y + bounds.size.height)];
      if (!EXImageBorderVisible(borders.left)) {
        [path addLineToPoint:CGPointMake(bounds.origin.x, bounds.origin.y + bounds.size.height - borders.bottom.width)];
        [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width * 0.5, bounds.origin.y + bounds.size.height - borders.bottom.width)];
      }
      [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width * 0.5, bounds.origin.y + bounds.size.height - bounds.size.width * 0.5)];
      if (!EXImageBorderVisible(borders.right)) {
        [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width * 0.5, bounds.origin.y + bounds.size.height - borders.bottom.width)];
        [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height - borders.bottom.width)];
      }
      [path addLineToPoint:CGPointMake(bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height)];
      break;
  }
  
  [path closePath];
  CAShapeLayer *layer = [CAShapeLayer layer];
  layer.path = path.CGPath;
  return layer;
}

CALayer *EXImageBorderSimpleLayer(CALayer *layer, EXImageBorder border, CGRect bounds, CGFloat cornerRadius)
{
  // Re-use original layer when possible
  cornerRadius = MAX(cornerRadius, 0);
  if (layer
      && ![layer isKindOfClass:[CAShapeLayer class]]
      && CGRectEqualToRect(layer.frame, bounds)
      && (layer.borderWidth == border.width)
      && CGColorEqualToColor(layer.borderColor, border.color)
      && (layer.cornerRadius == cornerRadius)) {
    return layer;
  }
  
  layer = [CALayer layer];
  layer.frame = bounds;
  layer.borderColor = border.color;
  layer.borderWidth = border.width;
  layer.cornerRadius = cornerRadius;
  
  return layer;
}

CALayer *EXImageBorderShapeLayer(CALayer *layer, EXImageBorder border, CGRect bounds, CGPathRef path, CALayer *mask)
{
  // TODO: re-use cached layer if possible?
  
  CAShapeLayer *shapeLayer = [CAShapeLayer layer];
  shapeLayer.frame = bounds;
  shapeLayer.fillColor = UIColor.clearColor.CGColor;
  shapeLayer.strokeColor = border.color;
  shapeLayer.lineWidth = border.width;
  shapeLayer.path = path;
  shapeLayer.mask = mask;
  
  switch (border.style) {
    case RCTBorderStyleDashed:
      shapeLayer.lineCap = kCALineCapSquare;
      shapeLayer.lineDashPattern = @[@(shapeLayer.lineWidth * 2), @(shapeLayer.lineWidth * 4)];
      break;
    case RCTBorderStyleDotted:
      shapeLayer.lineCap = kCALineCapSquare;
      shapeLayer.lineDashPattern = @[@0, @(shapeLayer.lineWidth * 2)];
      break;
    default:
      shapeLayer.lineCap = kCALineCapSquare;
      shapeLayer.lineDashPattern = nil;
      break;
  }
  
  return shapeLayer;
}
