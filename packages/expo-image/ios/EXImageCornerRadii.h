// Copyright 2020-present 650 Industries. All rights reserved.

#import <React/RCTBorderDrawing.h>

#define EXIMAGE_CORNERRADII \
EXIMAGE_CORNERRADIUS(,all) \
EXIMAGE_CORNERRADIUS(TopLeft,topLeft) \
EXIMAGE_CORNERRADIUS(TopRight,topRight) \
EXIMAGE_CORNERRADIUS(TopStart,topStart) \
EXIMAGE_CORNERRADIUS(TopEnd,topEnd) \
EXIMAGE_CORNERRADIUS(BottomLeft,bottomLeft) \
EXIMAGE_CORNERRADIUS(BottomRight,bottomRight) \
EXIMAGE_CORNERRADIUS(BottomStart,bottomStart) \
EXIMAGE_CORNERRADIUS(BottomEnd,bottomEnd)

typedef struct {
  CGFloat all;
  CGFloat topLeft;
  CGFloat topRight;
  CGFloat topStart;
  CGFloat topEnd;
  CGFloat bottomLeft;
  CGFloat bottomRight;
  CGFloat bottomStart;
  CGFloat bottomEnd;
} EXImageCornerRadii;

EXImageCornerRadii EXImageCornerRadiiInit();
EXImageCornerRadii EXImageCornerRadiiResolve(EXImageCornerRadii cornerRadii, UIUserInterfaceLayoutDirection layoutDirection, BOOL swapLeftRightInRTL, CGSize size);
RCTCornerInsets EXImageGetCornerInsets(EXImageCornerRadii cornerRadii, UIEdgeInsets edgeInsets);
BOOL EXImageCornerRadiiAllEqual(EXImageCornerRadii cornerRadii);
