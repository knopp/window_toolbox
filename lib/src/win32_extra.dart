import 'package:flutter/src/widgets/_window_win32.dart' hide HWND;
import 'dart:ui' show Size;
import 'dart:ffi' as ffi;

import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart' as ffi;

/// Provides additional delegate methods for [WindowControllerWin32].
///
/// The delegate can be added to window controller using
/// [WindowControllerWin32Extension.addDelegate] method.
abstract mixin class WindowDelegateWin32 {
  /// Called right before the window is closed. This is the best place to add
  /// any platform specific cleanup code.
  void windowWillClose() {}

  /// Called during window resizing. Implementation can override target size
  /// to enforce specific aspect ratio or other constraints.
  Size? windowWillResizeToSize(Size newSize) {
    return null;
  }
}

/// A message handler that can respond to windows message sent to window
/// of a specific window controller.
///
/// Returned value, if not null will be returned to the system as LRESULT
/// and will stop all registered other handlers from being called. See
/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nc-winuser-wndproc
/// for more information.
typedef WindowsMessageHandler =
    int? Function(
      HWND windowHandle,
      int message,
      int wParam,
      int lParam,
    );

extension WindowControllerWin32Extension on WindowControllerWin32 {
  /// Register a Win32 specific delegate to this window controller.
  void addDelegate(WindowDelegateWin32 delegate) {
    _WindowControllerWin32Private.forController(this).addDelegate(delegate);
  }

  /// Unregister a previously registered delegate.
  void removeDelegate(WindowDelegateWin32 delegate) {
    _WindowControllerWin32Private.forController(this).removeDelegate(delegate);
  }

  /// Registers a [WindowsMessageHandler] to receive Windows messages for this window.
  void addWindowsMessageHandler(WindowsMessageHandler handler) {
    _WindowControllerWin32Private.forController(
      this,
    )._messageHandlers.add(handler);
  }

  /// Unregisters a [WindowsMessageHandler] from receiving Windows messages for this window.
  void removeWindowsMessageHandler(WindowsMessageHandler handler) {
    _WindowControllerWin32Private.forController(
      this,
    )._messageHandlers.remove(handler);
  }

  /// Updates the window size. This is useful when delegate implements [windowWillResizeToSize]
  /// and needs to enforce new size.
  void updateSize() {
    final rect = ffi.malloc<RECT>();
    GetWindowRect(HWND(windowHandle), rect);

    SetWindowPos(
      HWND(windowHandle),
      null,
      rect.ref.left,
      rect.ref.top,
      rect.ref.right - rect.ref.left,
      rect.ref.bottom - rect.ref.top,
      SWP_NOMOVE | SWP_NOACTIVATE,
    );
    ffi.malloc.free(rect);
  }
}

//
// Implementation details.
//

final _subclassState = <int, _WindowControllerWin32Private>{};

int _subclassProc(
  ffi.Pointer hwnd,
  int msg,
  int wparam,
  int lparam,
  int idSubclass,
  int refData,
) {
  final state = _subclassState[hwnd.address];
  final result = state?.handleWindowsMessage(
    HWND(hwnd.cast()),
    msg,
    wparam,
    lparam,
  );
  if (result != null) {
    return result;
  } else {
    return DefSubclassProc(HWND(hwnd), msg, WPARAM(wparam), LPARAM(lparam));
  }
}

class _WindowControllerWin32Private {
  _WindowControllerWin32Private._(this.controller) {
    final windowHandle = controller.windowHandle;
    _subclassState[windowHandle.address] = this;
    SetWindowSubclass(
      HWND(windowHandle),
      ffi.Pointer.fromFunction<SUBCLASSPROC>(_subclassProc, 0),
      0,
      0,
    );
  }

  final _messageHandlers = <WindowsMessageHandler>{};

  final WindowControllerWin32 controller;

  int? handleWindowsMessage(
    HWND windowHandle,
    int message,
    int wParam,
    int lParam,
  ) {
    if (message == WM_DESTROY) {
      _subclassState.remove(windowHandle.address);
      for (final delegate in delegates) {
        delegate.windowWillClose();
      }
    }
    for (final WindowsMessageHandler handler in _messageHandlers) {
      final int? result = handler(windowHandle, message, wParam, lParam);
      if (result != null) {
        return result;
      }
    }
    if (message == WM_WINDOWPOSCHANGING) {
      DefWindowProc(
        HWND(windowHandle),
        message,
        WPARAM(wParam),
        LPARAM(lParam),
      );
      final windowPos = ffi.Pointer<WINDOWPOS>.fromAddress(lParam);
      final dpi = GetDpiForWindow(HWND(windowHandle));
      final originalSize = Size(
        windowPos.ref.cx * 96 / dpi,
        windowPos.ref.cy * 96 / dpi,
      );
      Size? newSize;
      for (final delegate in delegates) {
        newSize ??= delegate.windowWillResizeToSize(originalSize);
      }
      if (newSize != null) {
        windowPos.ref.cx = (newSize.width * dpi / 96).round();
        windowPos.ref.cy = (newSize.height * dpi / 96).round();
      }
      return 0;
    }
    return null;
  }

  static _WindowControllerWin32Private forController(
    WindowControllerWin32 controller,
  ) {
    var existing = _expando[controller];
    if (existing != null) {
      return existing;
    }
    final created = _WindowControllerWin32Private._(
      controller,
    );
    _expando[controller] = created;
    return created;
  }

  void addDelegate(WindowDelegateWin32 delegate) {
    if (!_delegates.contains(delegate)) {
      _delegates.add(delegate);
    }
  }

  void removeDelegate(WindowDelegateWin32 delegate) {
    _delegates.remove(delegate);
  }

  List<WindowDelegateWin32> get delegates => List.of(_delegates);

  final List<WindowDelegateWin32> _delegates = [];

  static final _expando = Expando<_WindowControllerWin32Private>(
    'WindowControllerWin32',
  );
}
