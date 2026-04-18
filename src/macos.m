#include "macos.h"

#import <AppKit/AppKit.h>
#import <objc/runtime.h>

#import "window_buttons_proxy.h"

static BOOL cw_mouseDownCanMoveWindow(id self, SEL _cmd) { return YES; }

@interface CWDefaultWindowDelegate : NSObject <NSWindowDelegate>

@end

@interface CWWindowDelegate : NSObject <NSWindowDelegate>

@end

@interface CWDelegateState : NSObject {
@public
  cw_delegate_config_t _config;
}
@end

static size_t associate_object_key;

@implementation CWDelegateState
- (instancetype)initWithConfig:(cw_delegate_config_t)config {
  if (self = [super init]) {
    _config = config;
  }
  return self;
}

- (void)setForObject:(id)object {
  objc_setAssociatedObject(object, &associate_object_key, self,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (CWDelegateState *)stateForObject:(id)object {
  return objc_getAssociatedObject(object, &associate_object_key);
}

@end

// We can call the original method (through [self __xxx]) because we know that
// the delegate implements all NSWindowDelegate method because we added them
// in the initSwizzleIfNeeded method.
@implementation CWWindowDelegate

- (void)__windowWillEnterFullScreen:(NSNotification *)notification {
  CWDelegateState *state = [CWDelegateState stateForObject:self];
  if (state) {
    state->_config.on_window_will_enter_fullscreen();
  }
  [self __windowWillEnterFullScreen:notification];
}

- (void)__windowDidEnterFullScreen:(NSNotification *)notification {
  CWDelegateState *state = [CWDelegateState stateForObject:self];
  if (state) {
    state->_config.on_window_did_enter_fullscreen();
  }
  [self __windowDidEnterFullScreen:notification];
}

- (void)__windowWillExitFullScreen:(NSNotification *)notification {
  CWDelegateState *state = [CWDelegateState stateForObject:self];
  if (state) {
    state->_config.on_window_will_exit_fullscreen();
  }
  [self __windowWillExitFullScreen:notification];
}

- (void)__windowDidExitFullScreen:(NSNotification *)notification {
  CWDelegateState *state = [CWDelegateState stateForObject:self];
  if (state) {
    state->_config.on_window_did_exit_fullscreen();
  }
  [self __windowDidExitFullScreen:notification];
}

- (NSSize)__windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize {
  CWDelegateState *state = [CWDelegateState stateForObject:self];
  if (state) {
    cw_size_t new_size = {frameSize.width, frameSize.height};
    cw_size_t size = state->_config.on_window_will_resize(new_size);
    if (size.w >= 0 && size.h >= 0) {
      return NSMakeSize(size.w, size.h);
    }
  }
  return [self __windowWillResize:sender toSize:frameSize];
}

// This depends on particular method that's not part of window delegate :-/
- (void)__windowWillClose {
  CWDelegateState *state = [CWDelegateState stateForObject:self];
  if (state) {
    state->_config.on_window_will_close();
  }
  [self __windowWillClose];
}

- (NSRect)__windowWillUseStandardFrame:(NSWindow *)window
                          defaultFrame:(NSRect)newFrame {
  CWDelegateState *state = [CWDelegateState stateForObject:self];
  if (state) {
    cw_rect_t new_frame = {newFrame.origin.x, newFrame.origin.y,
                           newFrame.size.width, newFrame.size.height};
    cw_rect_t frame =
        state->_config.on_window_will_use_standard_frame(new_frame);
    if (frame.w >= 0 && frame.h >= 0) {
      return NSMakeRect(frame.x, frame.y, frame.w, frame.h);
    }
  }
  return [self __windowWillUseStandardFrame:window defaultFrame:newFrame];
}

@end

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

    Class FlutterWindowOwner = NSClassFromString(@"FlutterWindowOwner");

    // Add all missing methods from CWDefaultWindowDelegate to
    // FlutterWindowingOwner
    unsigned int methodCount = 0;
    Method *methods =
        class_copyMethodList([CWDefaultWindowDelegate class], &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
      Method method = methods[i];
      SEL selector = method_getName(method);
      NSString *selectorName = NSStringFromSelector(selector);
      const char *typeEncoding = method_getTypeEncoding(method);
      if (class_getInstanceMethod(FlutterWindowOwner, selector) == NULL) {
        class_addMethod(FlutterWindowOwner, selector,
                        method_getImplementation(method), typeEncoding);
      }
    }
    free(methods);

    // Swizzle all methods from CWWindowDelegate with FlutterWindowOwner
    methodCount = 0;
    methods = class_copyMethodList([CWWindowDelegate class], &methodCount);
    // Go through all methods and exchange implementations with
    // FlutterWindowOwner
    for (unsigned int i = 0; i < methodCount; i++) {
      Method method = methods[i];
      SEL selector = method_getName(method);
      NSString *selectorName = NSStringFromSelector(selector);
      if ([selectorName hasPrefix:@"__"]) {
        NSString *originalSelectorName =
            [selectorName substringFromIndex:2]; // Remove __ prefix
        SEL originalSelector = NSSelectorFromString(originalSelectorName);
        const char *typeEncoding = method_getTypeEncoding(method);
        class_addMethod(FlutterWindowOwner, selector,
                        method_getImplementation(method), typeEncoding);
        method_exchangeImplementations(
            class_getInstanceMethod(FlutterWindowOwner, originalSelector),
            class_getInstanceMethod(FlutterWindowOwner, selector));
      }
    }
    free(methods);

    initialized = true;
  }
}

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
  WindowButtonsProxy *trafficLight;
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

- (WindowButtonsProxy *)trafficLight {
  if (trafficLight == nil) {
    trafficLight = [[WindowButtonsProxy alloc] initWithWindow:self.window];
  }
  return trafficLight;
}

- (void)layout {
  [[self trafficLight] performLayout];
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

void cw_nswindow_init_delegate(void *ns_window, cw_delegate_config_t config) {
  initSwizzleIfNeeded();
  CWDelegateState *state = [[CWDelegateState alloc] initWithConfig:config];
  NSWindow *window = (__bridge NSWindow *)ns_window;
  [state setForObject:window.delegate];

  // Seems like NSWindow will query delegate for supported methods when setting
  // the delegate. It is possible that we have swizzled the delegate methods
  // after it was already set to window, so we temporarily set it to nil and
  // then back to original delegate. Otherwise some newly added methods such as
  // windowDidEnterFullScreen might not be called.
  id<NSWindowDelegate> delegate = window.delegate;
  window.delegate = nil;
  window.delegate = delegate;
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

void cw_nswindow_set_style_mask(void *ns_window, unsigned long style_mask) {
  NSWindow *window = (__bridge NSWindow *)ns_window;
  window.styleMask = style_mask;
}

unsigned long cw_nswindow_get_style_mask(void *ns_window) {
  NSWindow *window = (__bridge NSWindow *)ns_window;
  return window.styleMask;
}

void cw_nswindow_set_collection_behavior(void *ns_window,
                                         unsigned long collection_behavior) {
  NSWindow *window = (__bridge NSWindow *)ns_window;
  window.collectionBehavior = collection_behavior;
}

unsigned long cw_nswindow_get_collection_behavior(void *ns_window) {
  NSWindow *window = (__bridge NSWindow *)ns_window;
  return window.collectionBehavior;
}

void cw_nswindow_update_traffic_light(void *ns_window, bool enabled, double x,
                                      double y) {
  NSWindow *window = (__bridge NSWindow *)ns_window;
  CWWindowDraggingView *draggingView = [CWWindowDraggingView forWindow:window];
  WindowButtonsProxy *trafficLight = draggingView.trafficLight;

  if (enabled) {
    NSPoint margin = NSMakePoint(x, y);
    [trafficLight setMargin:&margin];
  }
}

cw_size_t cw_nswindow_traffic_light_size(void *ns_window) {
  NSWindow *window = (__bridge NSWindow *)ns_window;
  CWWindowDraggingView *draggingView = [CWWindowDraggingView forWindow:window];
  WindowButtonsProxy *trafficLight = draggingView.trafficLight;
  NSRect bounds = [trafficLight getButtonsBounds];
  return (cw_size_t){bounds.size.width, bounds.size.height};
}

@implementation CWDefaultWindowDelegate

- (BOOL)windowShouldClose:(NSWindow *)sender {
  return YES;
}

- (nullable id)windowWillReturnFieldEditor:(NSWindow *)sender
                                  toObject:(nullable id)clien {
  return nil;
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize {
  return frameSize;
}

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window
                        defaultFrame:(NSRect)newFrame {
  return newFrame;
}

- (BOOL)windowShouldZoom:(NSWindow *)window toFrame:(NSRect)newFrame {
  return YES;
}

- (nullable NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
  return nil;
}

- (NSRect)window:(NSWindow *)window
    willPositionSheet:(NSWindow *)sheet
            usingRect:(NSRect)rect {
  return rect;
}

- (BOOL)window:(NSWindow *)window shouldPopUpDocumentPathMenu:(NSMenu *)menu {
  return YES;
}

- (BOOL)window:(NSWindow *)window
    shouldDragDocumentWithEvent:(NSEvent *)event
                           from:(NSPoint)dragImageLocation
                 withPasteboard:(NSPasteboard *)pasteboard {
  return NO;
}

- (NSSize)window:(NSWindow *)window
    willUseFullScreenContentSize:(NSSize)proposedSize {
  return proposedSize;
}

- (NSApplicationPresentationOptions)window:(NSWindow *)window
      willUseFullScreenPresentationOptions:
          (NSApplicationPresentationOptions)proposedOptions {
  return proposedOptions;
}

- (nullable NSArray<NSWindow *> *)customWindowsToEnterFullScreenForWindow:
    (NSWindow *)window {
  return nil;
}

- (void)window:(NSWindow *)window
    startCustomAnimationToEnterFullScreenWithDuration:(NSTimeInterval)duration {
}

- (void)windowDidFailToEnterFullScreen:(NSWindow *)window {
}

- (nullable NSArray<NSWindow *> *)customWindowsToExitFullScreenForWindow:
    (NSWindow *)window {
  return nil;
}

- (void)window:(NSWindow *)window
    startCustomAnimationToExitFullScreenWithDuration:(NSTimeInterval)duration {
}

- (nullable NSArray<NSWindow *> *)
    customWindowsToEnterFullScreenForWindow:(NSWindow *)window
                                   onScreen:(NSScreen *)screen {
  return nil;
}

- (void)window:(NSWindow *)window
    startCustomAnimationToEnterFullScreenOnScreen:(NSScreen *)screen
                                     withDuration:(NSTimeInterval)duration {
}

- (void)windowDidFailToExitFullScreen:(NSWindow *)window {
}

- (NSSize)window:(NSWindow *)window
    willResizeForVersionBrowserWithMaxPreferredSize:
        (NSSize)maxPreferredFrameSize
                                     maxAllowedSize:
                                         (NSSize)maxAllowedFrameSize {
  return maxPreferredFrameSize;
}

- (void)window:(NSWindow *)window willEncodeRestorableState:(NSCoder *)state {
}

- (void)window:(NSWindow *)window didDecodeRestorableState:(NSCoder *)state {
}

- (NSArray<id<NSPreviewRepresentableActivityItem>> *_Nullable)
    previewRepresentableActivityItemsForWindow:(NSWindow *)window {
  return nil;
}

- (nullable NSWindow *)windowForSharingRequestFromWindow:(NSWindow *)window {
  return nil;
}

- (void)windowDidResize:(NSNotification *)notification {
}

- (void)windowDidExpose:(NSNotification *)notification {
}

- (void)windowWillMove:(NSNotification *)notification {
}

- (void)windowDidMove:(NSNotification *)notification {
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
}

- (void)windowDidResignKey:(NSNotification *)notification {
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
}

- (void)windowDidResignMain:(NSNotification *)notification {
}

- (void)windowWillClose:(NSNotification *)notification {
}

- (void)windowWillMiniaturize:(NSNotification *)notification {
}

- (void)windowDidMiniaturize:(NSNotification *)notification {
}

- (void)windowDidDeminiaturize:(NSNotification *)notification {
}

- (void)windowDidUpdate:(NSNotification *)notification {
}

- (void)windowDidChangeScreen:(NSNotification *)notification {
}

- (void)windowDidChangeScreenProfile:(NSNotification *)notification {
}

- (void)windowDidChangeBackingProperties:(NSNotification *)notification {
}

- (void)windowWillBeginSheet:(NSNotification *)notification {
}

- (void)windowDidEndSheet:(NSNotification *)notification {
}

- (void)windowWillStartLiveResize:(NSNotification *)notification {
}

- (void)windowDidEndLiveResize:(NSNotification *)notification {
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification {
}

- (void)windowDidEnterFullScreen:(NSNotification *)notification {
}

- (void)windowWillExitFullScreen:(NSNotification *)notification {
}

- (void)windowDidExitFullScreen:(NSNotification *)notificatio {
}

- (void)windowWillEnterVersionBrowser:(NSNotification *)notification {
}

- (void)windowDidEnterVersionBrowser:(NSNotification *)notification {
}

- (void)windowWillExitVersionBrowser:(NSNotification *)notification {
}

- (void)windowDidExitVersionBrowser:(NSNotification *)notification {
}

- (void)windowDidChangeOcclusionState:(NSNotification *)notification {
}

@end
