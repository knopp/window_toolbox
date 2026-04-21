// Very roughly based on Electron, simplified, cleaned up and fixed up
// a fullscreen button glitch.

// Copyright (c) 2021 Microsoft, Inc.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

#include "window_buttons_proxy.h"

#include <QuartzCore/QuartzCore.h>

static bool IsRTL() {
  return [NSApp userInterfaceLayoutDirection] ==
         NSUserInterfaceLayoutDirectionRightToLeft;
}

@interface CWWindowButtonsProxy ()

- (CGFloat)buttonOffset;

@end

@interface CWWindowButtonsInactiveView : NSView {
  NSTrackingArea *_trackingArea;
  BOOL _mouseIn;
  __weak CWWindowButtonsProxy *_proxy;
}

@property(readonly, nonatomic) CALayer *left;
@property(readonly, nonatomic) CALayer *middle;
@property(readonly, nonatomic) CALayer *right;

@end

@implementation CWWindowButtonsInactiveView

- (BOOL)mouseIn {
  return _mouseIn;
}

- (instancetype)initWithFrame:(NSRect)frameRect
                        proxy:(CWWindowButtonsProxy *)proxy {
  if (self = [super initWithFrame:frameRect]) {
    _proxy = proxy;
    _trackingArea = [[NSTrackingArea alloc]
        initWithRect:frameRect
             options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways |
                     NSTrackingInVisibleRect
               owner:self
            userInfo:nil];
    [self addTrackingArea:_trackingArea];
    self.layer = [CALayer layer];
    // self.layer.backgroundColor = [NSColor yellowColor].CGColor;
    _left = [CALayer layer];
    [self.layer addSublayer:_left];
    _left.backgroundColor = [NSColor grayColor].CGColor;

    _middle = [CALayer layer];
    [self.layer addSublayer:_middle];
    _middle.backgroundColor = [NSColor grayColor].CGColor;

    _right = [CALayer layer];
    [self.layer addSublayer:_right];
  }
  return self;
}

- (void)layout {
  [super layout];
  NSRect bounds = self.bounds;

  CGFloat effectiveButtonSize = NSHeight(bounds) - 4;
  CGFloat horizontalPadding = 1;
  CGFloat verticalPadding = 2;
  CGFloat borderWidth = 0.5;
  CGColorRef borderColor = [NSColor blackColor].CGColor;
  CGColorRef backgroundColor = [NSColor grayColor].CGColor;
  CGFloat cornerRadius = effectiveButtonSize / 2;

  CGRect frame = NSMakeRect(horizontalPadding, verticalPadding,
                            effectiveButtonSize, effectiveButtonSize);

  _left.frame = frame;
  _left.cornerRadius = cornerRadius;

  frame.origin.x += _proxy.buttonOffset;
  _middle.frame = frame;
  _middle.cornerRadius = cornerRadius;

  frame.origin.x += _proxy.buttonOffset;
  _right.frame = frame;
  _right.cornerRadius = cornerRadius;
}

- (void)setBackgroundColor:(NSColor *)color {
  _left.backgroundColor = color.CGColor;
  _middle.backgroundColor = color.CGColor;
  _right.backgroundColor = color.CGColor;
}

- (void)setBorderColor:(NSColor *)color {
  _left.borderColor = color.CGColor;
  _middle.borderColor = color.CGColor;
  _right.borderColor = color.CGColor;
}

- (void)setBorderWidth:(CGFloat)width {
  _left.borderWidth = width;
  _middle.borderWidth = width;
  _right.borderWidth = width;
}

- (void)mouseEntered:(NSEvent *)event {
  _mouseIn = YES;
  [_proxy performLayout];
}

- (void)mouseExited:(NSEvent *)event {
  _mouseIn = NO;
  [_proxy performLayout];
}

@end

@interface CWWindowButtonsProxy () {
  NSWindow *_window;
  NSView *_container;
  NSPoint _margin;
  NSPoint _defaultMargin;
  CWWindowButtonsInactiveView *_inactiveView;
  BOOL _didChangeMargin;
  CWWindowButtonsProxyInactiveConfiguration *_inactiveConfiguration;
}

@end

@interface NSView (NSThemeFrame)

- (void)_updateMouseTracking;

@end

void _updateArea(NSView *view) {
  [view updateTrackingAreas];
  for (NSView *v in view.subviews) {
    _updateArea(v);
  }
}

@implementation CWWindowButtonsProxyInactiveConfiguration

@end

@implementation CWWindowButtonsProxy

- (id)initWithContainer:(NSView *)container {
  if (self = [super init]) {
    _window = container.window;
    _container = container;
    _margin = _defaultMargin = [self getCurrentMargin];
    _inactiveView =
        [[CWWindowButtonsInactiveView alloc] initWithFrame:NSZeroRect
                                                     proxy:self];
    [_container addSubview:_inactiveView];
  }
  return self;
}

- (void)setMargin:(const NSPoint *)margin {
  if (margin)
    _margin = *margin;
  else
    _margin = _defaultMargin;
  _didChangeMargin = YES;
  [self performLayout];
}

- (NSView *)getThemeFrame {
  NSView *titleBarContainer = [self titleBarContainer];
  NSView *frame = titleBarContainer.superview;
  Class themeFrameClass = NSClassFromString(@"NSThemeFrame");
  while (frame && ![frame isKindOfClass:themeFrameClass]) {
    frame = frame.superview;
  }
  return frame;
}

- (void)setInactiveConfiguration:
    (CWWindowButtonsProxyInactiveConfiguration *)configuration {
  _inactiveConfiguration = configuration;
  [_inactiveView setBackgroundColor:configuration.backgroundColor];
  [_inactiveView setBorderColor:configuration.borderColor];
  [_inactiveView setBorderWidth:configuration.borderWidth];
  [self performLayout];
}

- (void)setButttonAppearance:(NSAppearance *)appearance {
  [self leftButton].superview.appearance = appearance;
}

- (void)performLayout {
  NSView *titleBarContainer = [self titleBarContainer];
  if (!titleBarContainer) {
    return;
  }

  NSButton *left = [self leftButton];
  NSButton *middle = [self middleButton];
  NSButton *right = [self rightButton];

  float button_width = NSWidth(left.frame);
  float button_height = NSHeight(left.frame);
  float padding = NSMinX(middle.frame) - NSMaxX(left.frame);
  float start;
  if (IsRTL())
    start = NSWidth(_window.frame) - 3 * button_width - 2 * padding - _margin.x;
  else
    start = _margin.x;

  NSRect cbounds = titleBarContainer.frame;
  cbounds.size.height = button_height + 2 * _margin.y;

  cbounds.origin.y = NSHeight(_window.frame) - NSHeight(cbounds);
  NSRect oldFrame = titleBarContainer.frame;

  if ((_window.styleMask & NSWindowStyleMaskFullScreen) == 0) {
    [titleBarContainer setFrame:cbounds];
    NSPoint currentMargin = [self getCurrentMargin];
    [left setFrameOrigin:NSMakePoint(start, currentMargin.y)];
    start += button_width + padding;
    [middle setFrameOrigin:NSMakePoint(start, currentMargin.y)];
    start += button_width + padding;
    [right setFrameOrigin:NSMakePoint(start, currentMargin.y)];
  }

  if (_didChangeMargin) {
    NSView *themeFrame = [self getThemeFrame];
    if ([themeFrame respondsToSelector:@selector(_updateMouseTracking)]) {
      [themeFrame _updateMouseTracking];
    }
    _didChangeMargin = NO;
  }

  _inactiveView.frame = [self getButtonsBounds];

  [CATransaction begin];
  [CATransaction setDisableActions:YES];

  if (_inactiveConfiguration == nil) {
    left.superview.alphaValue = 1;
    _inactiveView.left.opacity = 0;
    _inactiveView.middle.opacity = 0;
    _inactiveView.right.opacity = 0;
  } else {
    bool showsActive = _inactiveView.mouseIn;
    if (!_inactiveConfiguration.showAsInactiveInKeyWindow) {
      showsActive |= _window.keyWindow;
    }

    if (showsActive) {
      left.superview.alphaValue = 1;
      _inactiveView.left.opacity = 0;
      _inactiveView.middle.opacity = 0;
      _inactiveView.right.opacity = 0;
    } else {
      left.superview.alphaValue = 0;
      _inactiveView.left.opacity = 1;
      _inactiveView.middle.opacity = 1;
      _inactiveView.right.opacity = 1;
    }

    if (!left.enabled) {
      left.alphaValue = 0;
      _inactiveView.left.opacity = 1;
    }
    if (!middle.enabled) {
      middle.alphaValue = 0;
      _inactiveView.middle.opacity = 1;
    }
    if (!right.enabled) {
      right.alphaValue = 0;
      _inactiveView.right.opacity = 1;
    }
  }

  [CATransaction commit];
}

// Return the bounds of all 3 buttons.
- (NSRect)getButtonsBounds {
  NSView *left = [self leftButton];
  NSView *right = [self rightButton];

  return NSMakeRect(NSMinX(left.frame), NSMinY(left.frame),
                    NSMaxX(right.frame) - NSMinX(left.frame),
                    NSHeight(left.frame));
}

- (CGFloat)buttonOffset {
  return NSMinX([self middleButton].frame) - NSMinX([self leftButton].frame);
}

// Compute margin from position of current buttons.
- (NSPoint)getCurrentMargin {
  NSPoint result;
  NSView *titleBarContainer = [self titleBarContainer];
  if (!titleBarContainer)
    return result;

  NSView *left = [self leftButton];
  NSView *right = [self rightButton];

  result.y = (NSHeight(titleBarContainer.frame) - NSHeight(left.frame)) / 2;

  if (IsRTL())
    result.x = NSWidth(_window.frame) - NSMaxX(right.frame);
  else
    result.x = NSMinX(left.frame);
  return result;
}

// Receive the titlebar container, which might be nil if the window does not
// have the NSWindowStyleMaskTitled style.
- (NSView *)titleBarContainer {
  return self.leftButton.superview.superview;
}

// Receive the window buttons, note that the buttons might be removed and
// re-added on the fly so we should not cache them.
- (NSButton *)leftButton {
  if (IsRTL())
    return [_window standardWindowButton:NSWindowZoomButton];
  else
    return [_window standardWindowButton:NSWindowCloseButton];
}

- (NSButton *)middleButton {
  return [_window standardWindowButton:NSWindowMiniaturizeButton];
}

- (NSButton *)rightButton {
  if (IsRTL())
    return [_window standardWindowButton:NSWindowCloseButton];
  else
    return [_window standardWindowButton:NSWindowZoomButton];
}

@end
