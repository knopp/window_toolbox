import 'package:flutter/src/widgets/_window_macos.dart';
import 'dart:ui' show Size, Rect;

import 'dart:ffi' as ffi;

import 'macos.g.dart';

/// Provides additional delegate methods for [WindowControllerMacOS]. This is subset
/// of `NSWindowDelegate` methods.
///
/// The delegate can be added to window controller using
/// [WindowControllerMacOSExtension.addDelegate] method.
abstract mixin class WindowDelegateMacOS {
  /// Called during window resizing. Implementation can override target size
  /// to enforce specific aspect ratio or other constraints.
  Size? windowWillResizeToSize(Size newSize) {
    return null;
  }

  /// Called when the window is about to be zoomed. Allows customization of the
  /// zoomed frame.
  Rect? windowWillUseStandardFrame(Rect defaultFrame) {
    return null;
  }

  /// Called right before the window is closed. This is the best place to add
  /// any platform specific cleanup code.
  void windowWillClose() {}

  void windowWillEnterFullScreen() {}

  void windowDidEnterFullScreen() {}

  void windowWillExitFullScreen() {}

  void windowDidExitFullScreen() {}
}

extension WindowControllerMacOSExtension on WindowControllerMacOS {
  /// Register a macOS specific delegate to this window controller.
  void addDelegate(WindowDelegateMacOS delegate) {
    _WindowControllerMacOSPrivate.forController(this).addDelegate(delegate);
  }

  /// Unregister a previously registered delegate.
  void removeDelegate(WindowDelegateMacOS delegate) {
    _WindowControllerMacOSPrivate.forController(this).removeDelegate(delegate);
  }
}

//
// Implementation details.
//

class _WindowControllerMacOSPrivate {
  _WindowControllerMacOSPrivate._(this.controller) {
    final initRequest = ffi.Struct.create<cw_delegate_config_t>();
    initRequest.on_window_will_close = _windowWillClose.nativeFunction;
    initRequest.on_window_will_resize = _windowWillResize.nativeFunction;
    initRequest.on_window_will_enter_fullscreen =
        _windowWillEnterFullScreen.nativeFunction;
    initRequest.on_window_did_enter_fullscreen =
        _windowDidEnterFullScreen.nativeFunction;
    initRequest.on_window_will_exit_fullscreen =
        _windowWillExitFullScreen.nativeFunction;
    initRequest.on_window_did_exit_fullscreen =
        _windowDidExitFullScreen.nativeFunction;
    initRequest.on_window_will_use_standard_frame =
        _windowWillUseStandardFrame.nativeFunction;
    cw_nswindow_init_delegate(
      controller.getWindowHandle(),
      initRequest,
    );
  }

  late final _windowWillClose =
      ffi.NativeCallable<ffi.Void Function()>.isolateLocal(
        _onWindowWillClose,
      );
  late final _windowWillResize =
      ffi.NativeCallable<cw_size_t Function(cw_size_t)>.isolateLocal(
        _onWindowWillResize,
      );
  late final _windowWillEnterFullScreen =
      ffi.NativeCallable<ffi.Void Function()>.isolateLocal(
        _onWindowWillEnterFullScreen,
      );
  late final _windowDidEnterFullScreen =
      ffi.NativeCallable<ffi.Void Function()>.isolateLocal(
        _onWindowDidEnterFullScreen,
      );
  late final _windowWillExitFullScreen =
      ffi.NativeCallable<ffi.Void Function()>.isolateLocal(
        _onWindowWillExitFullScreen,
      );
  late final _windowDidExitFullScreen =
      ffi.NativeCallable<ffi.Void Function()>.isolateLocal(
        _onWindowDidExitFullScreen,
      );
  late final _windowWillUseStandardFrame =
      ffi.NativeCallable<cw_rect_t Function(cw_rect_t)>.isolateLocal(
        _onWindowWillUseStandardFrame,
      );

  void _onWindowWillClose() {
    for (final delegate in delegates) {
      delegate.windowWillClose();
    }
    _windowWillClose.close();
    _windowWillResize.close();
    _windowWillEnterFullScreen.close();
    _windowDidEnterFullScreen.close();
    _windowWillExitFullScreen.close();
    _windowDidExitFullScreen.close();
    _windowWillUseStandardFrame.close();
  }

  cw_size_t _onWindowWillResize(cw_size_t newSize) {
    Size? result;
    final flutterSize = Size(newSize.w, newSize.h);
    for (final delegate in delegates) {
      result ??= delegate.windowWillResizeToSize(flutterSize);
    }
    result ??= Size(-1, -1);
    final cwSize = ffi.Struct.create<cw_size_t>();
    cwSize.w = result.width;
    cwSize.h = result.height;
    return cwSize;
  }

  cw_rect_t _onWindowWillUseStandardFrame(cw_rect_t defaultFrame) {
    Rect? result;
    final flutterRect = Rect.fromLTWH(
      defaultFrame.x,
      defaultFrame.y,
      defaultFrame.w,
      defaultFrame.h,
    );
    for (final delegate in delegates) {
      result ??= delegate.windowWillUseStandardFrame(flutterRect);
    }

    result ??= Rect.fromLTWH(0, 0, -1, -1);
    final cwRect = ffi.Struct.create<cw_rect_t>();
    cwRect.x = result.left;
    cwRect.y = result.top;
    cwRect.w = result.width;
    cwRect.h = result.height;
    return cwRect;
  }

  void _onWindowWillEnterFullScreen() {
    for (final delegate in delegates) {
      delegate.windowWillEnterFullScreen();
    }
  }

  void _onWindowDidEnterFullScreen() {
    for (final delegate in delegates) {
      delegate.windowDidEnterFullScreen();
    }
  }

  void _onWindowWillExitFullScreen() {
    for (final delegate in delegates) {
      delegate.windowWillExitFullScreen();
    }
  }

  void _onWindowDidExitFullScreen() {
    for (final delegate in delegates) {
      delegate.windowDidExitFullScreen();
    }
  }

  static _WindowControllerMacOSPrivate forController(
    WindowControllerMacOS controller,
  ) {
    var existing = _expando[controller];
    if (existing != null) {
      return existing;
    }
    final created = _WindowControllerMacOSPrivate._(
      controller,
    );
    _expando[controller] = created;
    return created;
  }

  void addDelegate(WindowDelegateMacOS delegate) {
    if (!delegates.contains(delegate)) {
      delegates.add(delegate);
    }
  }

  void removeDelegate(WindowDelegateMacOS delegate) {
    delegates.remove(delegate);
  }

  final List<WindowDelegateMacOS> delegates = [];

  final WindowControllerMacOS controller;

  static final _expando = Expando<_WindowControllerMacOSPrivate>(
    'WindowControllerMacOS',
  );
}
