import 'package:flutter/src/widgets/_window_linux.dart';

import 'dart:ffi' as ffi;
import 'linux.g.dart';

/// Provides additional delegate methods for [WindowControllerLinux].
///
/// The delegate can be added to window controller using
/// [WindowControllerLinuxExtension.addDelegate] method.
abstract mixin class WindowDelegateLinux {
  /// Called right before the window is closed. This is the best place to add
  /// any platform specific cleanup code.
  void windowWillClose() {}

  /// Called when window state changes, e.g. when it is minimized,
  /// maximized, or enters fullscreen.
  void windowStateDidChange() {}
}

extension WindowControllerLinuxExtension on WindowControllerLinux {
  /// Register a Linux specific delegate to this window controller.
  void addDelegate(WindowDelegateLinux delegate) {
    _WindowControllerLinuxPrivate.forController(this).addDelegate(delegate);
  }

  /// Unregister a previously registered delegate.
  void removeDelegate(WindowDelegateLinux delegate) {
    _WindowControllerLinuxPrivate.forController(this).removeDelegate(delegate);
  }

  /// Returns current window state specific to Linux platform.
  WindowStateLinux getWindowStateLinux() {
    final state = cw_window_get_state(getWindowHandle());
    return WindowStateLinux._(state);
  }
}

/// Linux specific window state.
class WindowStateLinux {
  final bool withdrawn;
  final bool iconified;
  final bool maximized;
  final bool sticky;
  final bool fullscreen;
  final bool above;
  final bool below;
  final bool focused;
  final bool topTiled;
  final bool topResizable;
  final bool rightTiled;
  final bool rightResizable;
  final bool bottomTiled;
  final bool bottomResizable;
  final bool leftTiled;
  final bool leftResizable;

  WindowStateLinux._(int state)
    : withdrawn = (state & CW_WINDOW_STATE_WITHDRAWN) != 0,
      iconified = (state & CW_WINDOW_STATE_ICONIFIED) != 0,
      maximized = (state & CW_WINDOW_STATE_MAXIMIZED) != 0,
      sticky = (state & CW_WINDOW_STATE_STICKY) != 0,
      fullscreen = (state & CW_WINDOW_STATE_FULLSCREEN) != 0,
      above = (state & CW_WINDOW_STATE_ABOVE) != 0,
      below = (state & CW_WINDOW_STATE_BELOW) != 0,
      focused = (state & CW_WINDOW_STATE_FOCUSED) != 0,
      topTiled = (state & CW_WINDOW_STATE_TOP_TILED) != 0,
      topResizable = (state & CW_WINDOW_STATE_TOP_RESIZABLE) != 0,
      rightTiled = (state & CW_WINDOW_STATE_RIGHT_TILED) != 0,
      rightResizable = (state & CW_WINDOW_STATE_RIGHT_RESIZABLE) != 0,
      bottomTiled = (state & CW_WINDOW_STATE_BOTTOM_TILED) != 0,
      bottomResizable = (state & CW_WINDOW_STATE_BOTTOM_RESIZABLE) != 0,
      leftTiled = (state & CW_WINDOW_STATE_LEFT_TILED) != 0,
      leftResizable = (state & CW_WINDOW_STATE_LEFT_RESIZABLE) != 0;
}

//
// Implementation details.
//

class _WindowControllerLinuxPrivate {
  _WindowControllerLinuxPrivate._(this.controller) {
    final initRequest = ffi.Struct.create<cw_delegate_config_t>();
    initRequest.on_window_will_close = _windowWillClose.nativeFunction;
    initRequest.on_window_state_changed = _windowStateChanged.nativeFunction;
    cw_gtk_window_init_delegate(
      controller.getWindowHandle(),
      initRequest,
    );
  }

  final WindowControllerLinux controller;

  late final _windowWillClose =
      ffi.NativeCallable<ffi.Void Function()>.isolateLocal(
        _onWindowWillClose,
      );
  late final _windowStateChanged =
      ffi.NativeCallable<ffi.Void Function()>.isolateLocal(
        _onWindowStateChanged,
      );

  void _onWindowWillClose() {
    for (final delegate in delegates) {
      delegate.windowWillClose();
    }
    _windowWillClose.close();
    _windowStateChanged.close();
  }

  void _onWindowStateChanged() {
    for (final delegate in delegates) {
      delegate.windowStateDidChange();
    }
  }

  static _WindowControllerLinuxPrivate forController(
    WindowControllerLinux controller,
  ) {
    var existing = _expando[controller];
    if (existing != null) {
      return existing;
    }
    final created = _WindowControllerLinuxPrivate._(
      controller,
    );
    _expando[controller] = created;
    return created;
  }

  void addDelegate(WindowDelegateLinux delegate) {
    if (!_delegates.contains(delegate)) {
      _delegates.add(delegate);
    }
  }

  void removeDelegate(WindowDelegateLinux delegate) {
    _delegates.remove(delegate);
  }

  List<WindowDelegateLinux> get delegates => List.of(_delegates);

  final List<WindowDelegateLinux> _delegates = [];

  static final _expando = Expando<_WindowControllerLinuxPrivate>(
    'WindowControllerLinux',
  );
}
