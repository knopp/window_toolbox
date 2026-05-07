import 'package:flutter/src/widgets/_window_win32.dart' hide HWND;
import 'dart:ui' show Size, Rect;
import 'dart:ffi' as ffi;

import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart' as ffi;
import 'win32_util.dart';

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
  ///
  /// The size is provided in physical pixels.
  Size? windowWillResizeToSize(Size newSize) {
    return null;
  }

  /// Called when user starts resizing or moving the window.
  void enterSizeMove() {}

  /// Called when user finishes resizing or moving the window.
  void exitSizeMove() {}
}

/// A message handler that can respond to windows message sent to window
/// of a specific window controller.
///
/// Returned value, if not null will be returned to the system as LRESULT
/// and will stop all registered other handlers from being called. See
/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nc-winuser-wndproc
/// for more information.
typedef Win32MessageHandler =
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

  /// Registers a [Win32MessageHandler] to receive Windows messages for this window.
  void addWindowsMessageHandler(Win32MessageHandler handler) {
    _WindowControllerWin32Private.forController(
      this,
    )._messageHandlers.add(handler);
  }

  /// Unregisters a [Win32MessageHandler] from receiving Windows messages for this window.
  void removeWindowsMessageHandler(Win32MessageHandler handler) {
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

  /// Controls whether the window can be minimized. This disables or enables the
  /// window minimize button in the title bar.
  set canMinimize(bool value) {
    int style = GetWindowLongPtr(HWND(windowHandle), GWL_STYLE).value;
    if (value) {
      style |= WS_MINIMIZEBOX;
    } else {
      style &= ~WS_MINIMIZEBOX;
    }
    SetWindowLongPtr(HWND(windowHandle), GWL_STYLE, style);
  }

  /// Returns whether the window can be minimized.
  bool get canMinimize {
    int style = GetWindowLongPtr(HWND(windowHandle), GWL_STYLE).value;
    return (style & WS_MINIMIZEBOX) != 0;
  }

  /// Controls whether the window can be maximized. This disables or enables the
  /// window maximize button in the title bar.
  set canMaximize(bool value) {
    int style = GetWindowLongPtr(HWND(windowHandle), GWL_STYLE).value;
    if (value) {
      style |= WS_MAXIMIZEBOX;
    } else {
      style &= ~WS_MAXIMIZEBOX;
    }
    SetWindowLongPtr(HWND(windowHandle), GWL_STYLE, style);
  }

  /// Returns whether the window can be maximized.
  bool get canMaximize {
    int style = GetWindowLongPtr(HWND(windowHandle), GWL_STYLE).value;
    return (style & WS_MAXIMIZEBOX) != 0;
  }

  /// Returns the current window frame in screen (physical) coordinates.
  /// The window frame includes the non-client area (title bar and borders).
  /// The origin of the coordinate system is top left corner of the primary display.
  Rect getWindowFrame() {
    final rect = ffi.malloc<RECT>();
    GetWindowRect(HWND(windowHandle), rect);
    final result = Rect.fromLTRB(
      rect.ref.left.toDouble(),
      rect.ref.top.toDouble(),
      rect.ref.right.toDouble(),
      rect.ref.bottom.toDouble(),
    );
    ffi.malloc.free(rect);
    return result;
  }

  /// Sets the window frame in screen (physical) coordinates.
  /// The window frame includes the non-client area (title bar and borders).
  /// The origin of the coordinate system is top left corner of the primary display.
  void setWindowFrame(Rect frame) {
    SetWindowPos(
      HWND(windowHandle),
      null,
      frame.left.round(),
      frame.top.round(),
      frame.width.round(),
      frame.height.round(),
      SWP_NOZORDER | SWP_NOACTIVATE,
    );
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

  final _messageHandlers = <Win32MessageHandler>{};

  final WindowControllerWin32 controller;

  bool _inResizeMove = false;

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
    for (final Win32MessageHandler handler in _messageHandlers) {
      final int? result = handler(windowHandle, message, wParam, lParam);
      if (result != null) {
        return result;
      }
    }
    if (message == WM_SIZING) {
      final rect = ffi.Pointer<RECT>.fromAddress(lParam);
      final newSize = Size(
        (rect.ref.right - rect.ref.left).toDouble(),
        (rect.ref.bottom - rect.ref.top).toDouble(),
      );
      Size? modifiedSize;
      for (final delegate in delegates) {
        modifiedSize ??= delegate.windowWillResizeToSize(newSize);
      }
      if (modifiedSize != null) {
        switch (wParam) {
          case WMSZ_TOP:
            rect.ref.top = rect.ref.bottom - modifiedSize.height.round();
            rect.ref.left -= ((modifiedSize.width - newSize.width) / 2).round();
            rect.ref.right = rect.ref.left + modifiedSize.width.round();
            break;
          case WMSZ_TOPLEFT:
            rect.ref.top = rect.ref.bottom - modifiedSize.height.round();
            rect.ref.left = rect.ref.right - modifiedSize.width.round();
            break;
          case WMSZ_TOPRIGHT:
            rect.ref.top = rect.ref.bottom - modifiedSize.height.round();
            rect.ref.right = rect.ref.left + modifiedSize.width.round();
            break;
          case WMSZ_LEFT:
            rect.ref.left = rect.ref.right - modifiedSize.width.round();
            rect.ref.top -= ((modifiedSize.height - newSize.height) / 2)
                .round();
            rect.ref.bottom = rect.ref.top + modifiedSize.height.round();
            break;
          case WMSZ_RIGHT:
            rect.ref.right = rect.ref.left + modifiedSize.width.round();
            rect.ref.top -= ((modifiedSize.height - newSize.height) / 2)
                .round();
            rect.ref.bottom = rect.ref.top + modifiedSize.height.round();
            break;
          case WMSZ_BOTTOMLEFT:
            rect.ref.bottom = rect.ref.top + modifiedSize.height.round();
            rect.ref.left = rect.ref.right - modifiedSize.width.round();
            break;
          case WMSZ_BOTTOMRIGHT:
            rect.ref.bottom = rect.ref.top + modifiedSize.height.round();
            rect.ref.right = rect.ref.left + modifiedSize.width.round();
            break;
          case WMSZ_BOTTOM:
            rect.ref.bottom = rect.ref.top + modifiedSize.height.round();
            rect.ref.left -= ((modifiedSize.width - newSize.width) / 2).round();
            rect.ref.right = rect.ref.left + modifiedSize.width.round();
            break;
          default:
        }
        return 1;
      }
    }
    if (message == WM_WINDOWPOSCHANGING) {
      if (_inResizeMove) {
        // Ignore - live resizing is handled by WM_SIZING which gives us more
        // control over which border is dragged to preserve the opposite border.
        return null;
      }
      DefWindowProc(
        HWND(windowHandle),
        message,
        WPARAM(wParam),
        LPARAM(lParam),
      );
      final windowPos = ffi.Pointer<WINDOWPOS>.fromAddress(lParam);

      final originalSize = Size(
        windowPos.ref.cx.toDouble(),
        windowPos.ref.cy.toDouble(),
      );
      Size? newSize;
      for (final delegate in delegates) {
        newSize ??= delegate.windowWillResizeToSize(originalSize);
      }
      if (newSize != null) {
        windowPos.ref.cx = newSize.width.round();
        windowPos.ref.cy = newSize.height.round();
      }
      return 0;
    }
    if (message == WM_ENTERSIZEMOVE) {
      _inResizeMove = true;
      for (final delegate in delegates) {
        delegate.enterSizeMove();
      }
      return null;
    }
    if (message == WM_EXITSIZEMOVE) {
      _inResizeMove = false;
      for (final delegate in delegates) {
        delegate.exitSizeMove();
      }
      return null;
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
