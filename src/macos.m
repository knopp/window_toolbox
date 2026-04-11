#include "macos.h"

#import <AppKit/AppKit.h>
#import <objc/runtime.h>

static BOOL cw_mouseDownCanMoveWindow(id self, SEL _cmd) { return YES; }

static void initSwizzleIfNeeded() {
  static bool initialized = false;
  if (!initialized) {
    NSString *typeEncoding = [NSString stringWithFormat:@"%s@:", @encode(BOOL)];
    Class flutterViewClass = NSClassFromString(@"FlutterView");
    class_addMethod(flutterViewClass, @selector(mouseDownCanMoveWindow),
                    (IMP)cw_mouseDownCanMoveWindow, [typeEncoding UTF8String]);
    Class flutterViewWrapperClass = NSClassFromString(@"FlutterViewWrapper");
    class_addMethod(flutterViewWrapperClass, @selector(mouseDownCanMoveWindow),
                    (IMP)cw_mouseDownCanMoveWindow, [typeEncoding UTF8String]);

    initialized = true;
  }
}

@interface CWTrafficLight : NSView

- (void)setEnabled:(BOOL)enabled;
- (void)setOrigin:(NSPoint)origin;

@end

@interface CWWindowDragPreventer : NSView

@end

@implementation CWWindowDragPreventer

- (NSRect)_opaqueRectForWindowMoveWhenInTitlebar {
  return self.bounds;
}

- (BOOL)mouseDownCanMoveWindow {
  return NO;
}

- (NSView *)hitTest:(NSPoint)point {
  return nil;
}

@end

@interface CWWindowDraggingView : NSView {
  NSMutableArray<CWWindowDragPreventer *> *_dragExclusion;
  CWTrafficLight *trafficLight;
}

@end

@implementation CWWindowDraggingView

- (instancetype)initWithFrame:(NSRect)frameRect {
  if (self = [super initWithFrame:frameRect]) {
    _dragExclusion = [NSMutableArray new];
  }
  return self;
}

+ (CWWindowDraggingView *)forWindow:(NSWindow *)window {
  if (![window.contentView isKindOfClass:[CWWindowDraggingView class]]) {
    CWWindowDraggingView *view =
        [[CWWindowDraggingView alloc] initWithFrame:window.contentView.bounds];
    NSView *oldContentView = window.contentView;
    [view addSubview:window.contentView];
    window.contentView = view;
    oldContentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  }
  return window.contentView;
}

- (CWTrafficLight *)trafficLight {
  if (trafficLight == nil) {
    trafficLight = [CWTrafficLight new];
    [self addSubview:trafficLight];
  }
  return trafficLight;
}

- (BOOL)isFlipped {
  return YES;
}

- (BOOL)mouseDownCanMoveWindow {
  return YES;
}

- (void)updateExclusions:(cw_rect_t *)exclude withCount:(size_t)excludeCount {
  if (_dragExclusion.count > excludeCount) {
    [_dragExclusion
        removeObjectsInRange:NSMakeRange(excludeCount,
                                         _dragExclusion.count - excludeCount)];
  }
  while (_dragExclusion.count < excludeCount) {
    CWWindowDragPreventer *preventer = [CWWindowDragPreventer new];
    [self addSubview:preventer];
    [_dragExclusion addObject:preventer];
  }
  for (size_t i = 0; i < excludeCount; i++) {
    CWWindowDragPreventer *preventer = _dragExclusion[i];
    cw_rect_t rect = exclude[i];
    preventer.frame = NSMakeRect(rect.x, rect.y, rect.w, rect.h);
  }
}

@end

void cw_nswindow_remove_titlebar(void *ns_window) {
  initSwizzleIfNeeded();
  NSWindow *window = (__bridge NSWindow *)ns_window;
  window.titlebarAppearsTransparent = YES;
  window.titleVisibility = NSWindowTitleHidden;
  window.styleMask |= NSWindowStyleMaskFullSizeContentView;
}

EXPORT void cw_nswindow_update_draggable_areas(void *ns_window,
                                               cw_rect_t *exclude,
                                               size_t exclude_count) {
  initSwizzleIfNeeded();
  NSWindow *window = (__bridge NSWindow *)ns_window;
  [window setMovableByWindowBackground:YES];

  CWWindowDraggingView *draggingView = [CWWindowDraggingView forWindow:window];
  [draggingView updateExclusions:exclude withCount:exclude_count];
}

void cw_nswindow_disable_draggable_areas(void *ns_window) {
  NSWindow *window = (__bridge NSWindow *)ns_window;
  [window setMovableByWindowBackground:NO];
}

void cw_nswindow_request_close(void *ns_window) {
  NSWindow *window = (__bridge NSWindow *)ns_window;
  [window performClose:nil];
}

void cw_nswindow_update_traffic_light(void *ns_window, bool enabled, double x,
                                      double y) {
  NSWindow *window = (__bridge NSWindow *)ns_window;
  CWWindowDraggingView *draggingView = [CWWindowDraggingView forWindow:window];
  CWTrafficLight *trafficLight = draggingView.trafficLight;
  [trafficLight setEnabled:enabled];
  [trafficLight setOrigin:NSMakePoint(x, y)];
}

@interface CWTrafficLight () {
  NSButton *closeButton;
  NSButton *minimizeButton;
  NSButton *zoomButton;
  NSTrackingArea *trackingArea;

  NSView *originalParent;
  NSWindow *originalWindow;
  NSPoint origin;

  BOOL mouseInside;
  BOOL enabled;
}
@end

@implementation CWTrafficLight

- (instancetype)initWithCoder:(NSCoder *)coder {
  if (self = [super initWithCoder:coder]) {
    [self initialize];
  }
  return self;
}

- (instancetype)init {
  if (self = [super init]) {
    [self initialize];
  }
  return self;
}

- (void)initialize {
  closeButton = [NSWindow standardWindowButton:NSWindowCloseButton
                                  forStyleMask:NSWindowStyleMaskTitled];
  [self addSubview:closeButton];

  minimizeButton = [NSWindow standardWindowButton:NSWindowMiniaturizeButton
                                     forStyleMask:NSWindowStyleMaskTitled];
  [self addSubview:minimizeButton];
  NSRect frame = minimizeButton.frame;
  frame.origin.x += 20;
  minimizeButton.frame = frame;

  zoomButton = [NSWindow standardWindowButton:NSWindowZoomButton
                                 forStyleMask:NSWindowStyleMaskTitled];
  [self addSubview:zoomButton];
  frame = zoomButton.frame;
  frame.origin.x += 40;
  zoomButton.frame = frame;

  trackingArea = [[NSTrackingArea alloc]
      initWithRect:NSZeroRect
           options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways |
                   NSTrackingInVisibleRect
             owner:self
          userInfo:nil];
  [self addTrackingArea:trackingArea];

  origin = NSMakePoint(6, 6);

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(update:)
             name:NSWindowDidBecomeKeyNotification
           object:nil];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(update:)
             name:NSWindowDidResignKeyNotification
           object:nil];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(willEnterFullScreen:)
             name:NSWindowWillEnterFullScreenNotification
           object:nil];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(willExitFullScreen:)
             name:NSWindowWillExitFullScreenNotification
           object:nil];
}

- (BOOL)isFlipped {
  return YES;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)update:(id)notification {
  [self updateButtons];
}

- (BOOL)_mouseInGroup:(NSButton *)button {
  return mouseInside;
}

- (void)updateFrame {
  NSRect frame = self.frame;
  frame.origin = origin;
  frame.size = NSMakeSize(54, 16);
  self.frame = frame;
}

- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];
  [self updateFrame];

  if (self.superview != nil) {
    originalParent = self.superview;
    originalWindow = self.window;
    if (!self->enabled) {
      [self doDisableButtons];
    }
  }
}

- (void)setEnabled:(BOOL)_enabled {
  if (self->enabled != _enabled) {
    self->enabled = _enabled;
    if (_enabled) {
      [self doEnableButtons];
    } else {
      [self doDisableButtons];
    }
  }
}

- (void)setOrigin:(NSPoint)_origin {
  origin = _origin;
  [self updateFrame];
  [self updateButtons];
}

- (void)doEnableButtons {
  [originalWindow standardWindowButton:NSWindowCloseButton].hidden = YES;
  [originalWindow standardWindowButton:NSWindowMiniaturizeButton].hidden = YES;
  [originalWindow standardWindowButton:NSWindowZoomButton].hidden = YES;
  [originalParent addSubview:self];
  [self updateButtons];
}

- (void)doDisableButtons {
  [self removeFromSuperview];
  mouseInside = NO;
  [originalWindow standardWindowButton:NSWindowCloseButton].hidden = NO;
  [originalWindow standardWindowButton:NSWindowMiniaturizeButton].hidden = NO;
  [originalWindow standardWindowButton:NSWindowZoomButton].hidden = NO;
}

- (void)willEnterFullScreen:(NSNotification *)n {
  if (n.object == originalWindow) {
    [self doDisableButtons];
  }
}

- (void)willExitFullScreen:(NSNotification *)n {
  if (n.object == originalWindow) {
    mouseInside = NO;
    if (enabled) {
      [self doEnableButtons];
    }
  }
}

- (void)updateButtons {
  [closeButton setNeedsDisplay:YES];
  closeButton.enabled =
      (self.window.styleMask & NSWindowStyleMaskClosable) != 0;

  [minimizeButton setNeedsDisplay:YES];
  minimizeButton.enabled =
      (self.window.styleMask & NSWindowStyleMaskMiniaturizable) != 0;

  [zoomButton setNeedsDisplay:YES];
  zoomButton.enabled =
      (self.window.styleMask & NSWindowStyleMaskResizable) != 0;
}

- (void)mouseEntered:(NSEvent *)event {
  mouseInside = YES;
  [self updateButtons];
}

- (void)mouseExited:(NSEvent *)event {
  mouseInside = NO;
  [self updateButtons];
}

@end
