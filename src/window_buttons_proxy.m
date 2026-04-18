// Very roughly based on Electron, simplified, cleaned up and fixed up
// a fullscreen button glitch.

// Copyright (c) 2021 Microsoft, Inc.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

#include "window_buttons_proxy.h"

static bool IsRTL() {
  return [NSApp userInterfaceLayoutDirection] ==
         NSUserInterfaceLayoutDirectionRightToLeft;
}

@interface WindowButtonsProxy () {
  NSWindow *_window;
  NSPoint _margin;
  NSPoint _defaultMargin;
}

@end

@implementation WindowButtonsProxy

- (id)initWithWindow:(NSWindow *)window {
  _window = window;
  _margin = _defaultMargin = [self getCurrentMargin];
  return self;
}

- (void)setMargin:(const NSPoint *)margin {
  if (margin)
    _margin = *margin;
  else
    _margin = _defaultMargin;
  [self performLayout];
}

- (void)performLayout {
  NSView *titleBarContainer = [self titleBarContainer];
  if (!titleBarContainer) {
    return;
  }

  NSView *left = [self leftButton];
  NSView *middle = [self middleButton];
  NSView *right = [self rightButton];

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
}

// Return the bounds of all 3 buttons.
- (NSRect)getButtonsBounds {
  NSView *left = [self leftButton];
  NSView *right = [self rightButton];

  return NSMakeRect(NSMinX(left.frame), NSMinY(left.frame),
                    NSMaxX(right.frame) - NSMinX(left.frame),
                    NSHeight(left.frame));
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