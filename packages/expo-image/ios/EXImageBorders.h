// Copyright 2020-present 650 Industries. All rights reserved.

#import <React/RCTBorderStyle.h>
#import <React/RCTBorderDrawing.h>

#define EXIMAGE_BORDERS \
EXIMAGE_BORDER(,all) \
EXIMAGE_BORDER(Top,top) \
EXIMAGE_BORDER(Right,right) \
EXIMAGE_BORDER(Bottom,bottom) \
EXIMAGE_BORDER(Left,left) \
EXIMAGE_BORDER(Start,start) \
EXIMAGE_BORDER(End,end)

typedef struct {
  CGFloat width;
  CGColorRef color;
  RCTBorderStyle style;
} EXImageBorder;

typedef struct {
  EXImageBorder all;
  EXImageBorder top;
  EXImageBorder right;
  EXImageBorder bottom;
  EXImageBorder left;
  EXImageBorder start;
  EXImageBorder end;
} EXImageBorders;

typedef NS_ENUM(NSInteger, EXImageBorderLocation) {
  EXImageBorderLocationTop,
  EXImageBorderLocationRight,
  EXImageBorderLocationBottom,
  EXImageBorderLocationLeft,
};

EXImageBorders EXImageBordersInit();
EXImageBorder EXImageBorderMake(CGFloat width, CGColorRef color, RCTBorderStyle style);
EXImageBorders EXImageBordersResolve(EXImageBorders borders, UIUserInterfaceLayoutDirection layoutDirection, BOOL swapLeftRightInRTL);
BOOL EXImageBorderEqualTo(EXImageBorder border, EXImageBorder equalTo);
BOOL EXImageBordersAllEqual(EXImageBorders borders);
BOOL EXImageBorderVisible(EXImageBorder border);
void EXImageBordersRelease(EXImageBorders borders);
CALayer *EXImageBorderMask(CGRect bounds, EXImageBorderLocation location, EXImageBorders borders);
CALayer *EXImageBorderSimpleLayer(CALayer *layer, EXImageBorder border, CGRect bounds, CGFloat cornerRadius);
CALayer *EXImageBorderShapeLayer(CALayer *layer, EXImageBorder border, CGRect bounds, CGPathRef path, CALayer *mask);

