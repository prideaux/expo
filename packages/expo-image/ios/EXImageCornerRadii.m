// Copyright 2020-present 650 Industries. All rights reserved.

#import <expo-image/EXImageCornerRadii.h>
#import <React/RCTUtils.h>

static CGFloat EXImageDefaultIfNegativeTo(CGFloat defaultValue, CGFloat x)
{
  return x >= 0 ? x : defaultValue;
};

static const CGFloat EXImageCornerRadiiThreshold = 0.001;

EXImageCornerRadii EXImageCornerRadiiInit()
{
  EXImageCornerRadii cornerRadii;
  cornerRadii.all = -1;
  cornerRadii.topLeft = -1;
  cornerRadii.topRight = -1;
  cornerRadii.topStart = -1;
  cornerRadii.topEnd = -1;
  cornerRadii.bottomLeft = -1;
  cornerRadii.bottomRight = -1;
  cornerRadii.bottomStart = -1;
  cornerRadii.bottomEnd = -1;
  return cornerRadii;
}

BOOL EXImageCornerRadiiAllEqual(EXImageCornerRadii cornerRadii)
{
  return ABS(cornerRadii.topLeft - cornerRadii.topRight) < EXImageCornerRadiiThreshold &&
  ABS(cornerRadii.topLeft - cornerRadii.bottomLeft) < EXImageCornerRadiiThreshold &&
  ABS(cornerRadii.topLeft - cornerRadii.bottomRight) < EXImageCornerRadiiThreshold;
}

RCTCornerInsets EXImageGetCornerInsets(EXImageCornerRadii cornerRadii, UIEdgeInsets edgeInsets)
{
  return (RCTCornerInsets){{
    MAX(0, cornerRadii.topLeft - edgeInsets.left),
    MAX(0, cornerRadii.topLeft - edgeInsets.top),
  },
    {
      MAX(0, cornerRadii.topRight - edgeInsets.right),
      MAX(0, cornerRadii.topRight - edgeInsets.top),
    },
    {
      MAX(0, cornerRadii.bottomLeft - edgeInsets.left),
      MAX(0, cornerRadii.bottomLeft - edgeInsets.bottom),
    },
    {
      MAX(0, cornerRadii.bottomRight - edgeInsets.right),
      MAX(0, cornerRadii.bottomRight - edgeInsets.bottom),
    }};
}

EXImageCornerRadii EXImageCornerRadiiResolve(EXImageCornerRadii cornerRadii, UIUserInterfaceLayoutDirection layoutDirection, BOOL swapLeftRightInRTL, CGSize size)
{
  const BOOL isRTL = layoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
  const CGFloat radius = MAX(0, cornerRadii.all);
  
  EXImageCornerRadii result = EXImageCornerRadiiInit();
  
  if (swapLeftRightInRTL) {
    const CGFloat topStartRadius = EXImageDefaultIfNegativeTo(cornerRadii.topLeft, cornerRadii.topStart);
    const CGFloat topEndRadius = EXImageDefaultIfNegativeTo(cornerRadii.topRight, cornerRadii.topEnd);
    const CGFloat bottomStartRadius = EXImageDefaultIfNegativeTo(cornerRadii.bottomLeft, cornerRadii.bottomStart);
    const CGFloat bottomEndRadius = EXImageDefaultIfNegativeTo(cornerRadii.bottomRight, cornerRadii.bottomEnd);
    
    const CGFloat directionAwareTopLeftRadius = isRTL ? topEndRadius : topStartRadius;
    const CGFloat directionAwareTopRightRadius = isRTL ? topStartRadius : topEndRadius;
    const CGFloat directionAwareBottomLeftRadius = isRTL ? bottomEndRadius : bottomStartRadius;
    const CGFloat directionAwareBottomRightRadius = isRTL ? bottomStartRadius : bottomEndRadius;
    
    result.topLeft = EXImageDefaultIfNegativeTo(radius, directionAwareTopLeftRadius);
    result.topRight = EXImageDefaultIfNegativeTo(radius, directionAwareTopRightRadius);
    result.bottomLeft = EXImageDefaultIfNegativeTo(radius, directionAwareBottomLeftRadius);
    result.bottomRight = EXImageDefaultIfNegativeTo(radius, directionAwareBottomRightRadius);
  } else {
    const CGFloat directionAwareTopLeftRadius = isRTL ? cornerRadii.topEnd : cornerRadii.topStart;
    const CGFloat directionAwareTopRightRadius = isRTL ? cornerRadii.topStart : cornerRadii.topEnd;
    const CGFloat directionAwareBottomLeftRadius = isRTL ? cornerRadii.bottomEnd : cornerRadii.bottomStart;
    const CGFloat directionAwareBottomRightRadius = isRTL ? cornerRadii.bottomStart : cornerRadii.bottomEnd;
    
    result.topLeft =
    EXImageDefaultIfNegativeTo(radius, EXImageDefaultIfNegativeTo(cornerRadii.topLeft, directionAwareTopLeftRadius));
    result.topRight =
    EXImageDefaultIfNegativeTo(radius, EXImageDefaultIfNegativeTo(cornerRadii.topRight, directionAwareTopRightRadius));
    result.bottomLeft =
    EXImageDefaultIfNegativeTo(radius, EXImageDefaultIfNegativeTo(cornerRadii.bottomLeft, directionAwareBottomLeftRadius));
    result.bottomRight = EXImageDefaultIfNegativeTo(
                                                    radius, EXImageDefaultIfNegativeTo(cornerRadii.bottomRight, directionAwareBottomRightRadius));
  }
  
  // Get scale factors required to prevent radii from overlapping
  const CGFloat topScaleFactor = RCTZeroIfNaN(MIN(1, size.width / (result.topLeft + result.topRight)));
  const CGFloat bottomScaleFactor = RCTZeroIfNaN(MIN(1, size.width / (result.bottomLeft + result.bottomRight)));
  const CGFloat rightScaleFactor = RCTZeroIfNaN(MIN(1, size.height / (result.topRight + result.bottomRight)));
  const CGFloat leftScaleFactor = RCTZeroIfNaN(MIN(1, size.height / (result.topLeft + result.bottomLeft)));
  
  result.topLeft *= MIN(topScaleFactor, leftScaleFactor);
  result.topRight *= MIN(topScaleFactor, rightScaleFactor);
  result.bottomLeft *= MIN(bottomScaleFactor, leftScaleFactor);
  result.bottomRight *= MIN(bottomScaleFactor, rightScaleFactor);
  
  return result;
}

