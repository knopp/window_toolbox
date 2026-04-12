import 'package:ffi/ffi.dart';
import 'package:flutter/widgets.dart';
import 'package:win32/win32.dart';

import 'custom_window.dart';
import 'package:flutter/src/widgets/_window_win32.dart' hide HWND;
import 'package:flutter/src/widgets/_window_win32.dart'
    as window_win32
    show HWND;

import 'dart:ffi' hide Size;

import 'win32_util.dart';

class SubclassState {
  bool needRearmMouseTracker = false;
}

final _subclassState = <int, SubclassState>{};

int _subclassProc(
  Pointer hwnd,
  int msg,
  int wparam,
  int lparam,
  int idSubclass,
  int refData,
) {
  final state = _subclassState.putIfAbsent(hwnd.address, () => SubclassState());
  if (msg == WM_DESTROY) {
    _subclassState.remove(hwnd.address);
  }
  if (msg == WM_MOUSELEAVE) {
    HWND parentWindow = GetAncestor(HWND(hwnd), GA_ROOT);
    if (parentWindow.isNotNull) {
      final cursorPos = malloc<POINT>();
      GetCursorPos(cursorPos);
      final cursorPosLparam = makeLParam(cursorPos.ref.x, cursorPos.ref.y);
      free(cursorPos);
      final parentHitTest = SendMessage(
        parentWindow,
        WM_NCHITTEST,
        WPARAM(0),
        LPARAM(cursorPosLparam),
      ).value;
      if (parentHitTest == HTMAXBUTTON || parentHitTest == HTCAPTION) {
        state.needRearmMouseTracker = true;
        return 0;
      }
    }
  } else if (msg == WM_NCHITTEST) {
    // NCHITTEST needs to cooperate with parent (top level) window.
    HWND parentWindow = GetAncestor(HWND(hwnd), GA_ROOT);
    if (parentWindow.isNotNull) {
      final parentResult = SendMessage(
        parentWindow,
        msg,
        WPARAM(wparam),
        LPARAM(lparam),
      ).value;
      if (parentResult == HTCLIENT) {
        return HTCLIENT;
      } else {
        return HTTRANSPARENT;
      }
    } else {
      return HTCLIENT;
    }
  } else if (msg == WM_MOUSEMOVE) {
    if (state.needRearmMouseTracker) {
      final trackMouseEvent = malloc<TRACKMOUSEEVENT>();
      trackMouseEvent.ref.cbSize = sizeOf<TRACKMOUSEEVENT>();
      trackMouseEvent.ref.hwndTrack = HWND(hwnd);
      trackMouseEvent.ref.dwFlags = TME_LEAVE;
      TrackMouseEvent(trackMouseEvent);
      malloc.free(trackMouseEvent);
      state.needRearmMouseTracker = false;
    }
  }
  return DefSubclassProc(HWND(hwnd), msg, WPARAM(wparam), LPARAM(lparam));
}

class CustomWindowWin32 extends CustomWindow implements WindowsMessageHandler {
  CustomWindowWin32(this.controller) {
    controller.addWindowsMessageHandler(this);
    _makeWindowUndecorated(_hwnd);
    _flutterView = _findFlutterView();
    SetWindowSubclass(
      _flutterView,
      Pointer.fromFunction<SUBCLASSPROC>(_subclassProc, 0),
      0,
      0,
    );
  }

  late final HWND _flutterView;

  HWND _findFlutterView() {
    final className = "FlutterView".toNativeUtf16();
    final child = FindWindowEx(_hwnd, null, PCWSTR(className), null);
    free(className);
    if (child.value.isNull) {
      throw Exception('Could not find FlutterView child window');
    }
    return child.value;
  }

  final WindowControllerWin32 controller;

  HWND get _hwnd => HWND(controller.getWindowHandle());

  static final int Function(Pointer<Void>) _getDpiForWindow =
      DynamicLibrary.process().lookupFunction<
        Uint32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('FlutterDesktopGetDpiForHWND');

  static void _makeWindowUndecorated(HWND hwnd) {
    SetWindowLongPtr(
      hwnd,
      GWL_STYLE,
      WS_THICKFRAME |
          WS_CAPTION |
          WS_SYSMENU |
          WS_MAXIMIZEBOX |
          WS_MINIMIZEBOX |
          WS_OVERLAPPED,
    );
    SetWindowPos(
      hwnd,
      null,
      0,
      0,
      0,
      0,
      SWP_FRAMECHANGED |
          SWP_NOMOVE |
          SWP_NOSIZE |
          SWP_NOZORDER |
          SWP_NOACTIVATE,
    );

    // final margins = malloc<MARGINS>();
    // margins.ref.cxLeftWidth = -1;
    // margins.ref.cxRightWidth = -1;
    // margins.ref.cyTopHeight = -1;
    // margins.ref.cyBottomHeight = -1;
    // DwmExtendFrameIntoClientArea(hwnd, margins);
    // malloc.free(margins);
  }

  final _dragExcludeRects = <BuildContext, Rect>{};
  final _maximizeButtonRects = <BuildContext, Rect>{};

  @override
  void setDragExcludeRectForElement(BuildContext element, Rect? rect) {
    if (rect == null) {
      _dragExcludeRects.remove(element);
    } else {
      _dragExcludeRects[element] = rect;
    }
  }

  @override
  void setDraggableRectForElement(BuildContext element, Rect? rect) {}

  @override
  void setMaximizeButtonFrame(BuildContext element, Rect? rect) {
    if (rect == null) {
      _maximizeButtonRects.remove(element);
    } else {
      _maximizeButtonRects[element] = rect;
    }
  }

  @override
  Size getTrafficLightSize() {
    return Size.zero;
  }

  @override
  void setTrafficLightPosition(Offset offset) {}

  @override
  void requestClose() {
    PostMessage(_hwnd, WM_CLOSE, WPARAM(0), LPARAM(0));
  }

  bool _trackingMouseLeave = false;

  @override
  int? handleWindowsMessage(
    window_win32.HWND windowHandle,
    int message,
    int wParam,
    int lParam,
  ) {
    switch (message) {
      case WM_ERASEBKGND:
        return 0;
      case WM_SIZE:
        // This would cause Flutter relayout with a very small size.
        if (wParam == SIZE_MINIMIZED) return 0;
        break;
      case WM_NCCALCSIZE:
        if (wParam == 1) {
          final dpi = _getDpiForWindow(windowHandle);
          int padding = GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi).value;
          int borderLR =
              GetSystemMetricsForDpi(SM_CXFRAME, dpi).value + padding;
          int borderTB =
              GetSystemMetricsForDpi(SM_CYFRAME, dpi).value + padding;
          final params = Pointer<NCCALCSIZE_PARAMS>.fromAddress(lParam);
          final rect = params.ref.rgrc[0];
          double scale = dpi / 96.0;
          if (IsZoomed(_hwnd)) {
            rect.top += borderTB;
          } else {
            // Otherwise we miss one pixel from top.
            rect.top += (1 * scale).round();
          }
          rect.left += borderLR;
          rect.right -= borderLR;
          rect.bottom -= borderTB;
          return 0;
        }
      case WM_NCHITTEST:
        final (xPos, yPos) = splitLParam(lParam);
        final (xClient, yClient) = screenToClient(_hwnd, xPos, yPos);

        double scale = _getDpiForWindow(windowHandle) / 96.0;
        double x = xClient / scale;
        double y = yClient / scale;

        final rect = malloc<RECT>();
        GetClientRect(_hwnd, rect);
        final width = (rect.ref.right - rect.ref.left) / scale;
        final height = (rect.ref.bottom - rect.ref.top) / scale;
        malloc.free(rect);

        // sides and bottom are extended through WM_NCCALCSIZE
        const edgeSize = 1;
        const topEdgeSize = 3; // 1px from WM_NCCALCSIZE + 3px

        if (_maximizeButtonRects.values.any((r) => r.contains(Offset(x, y)))) {
          return HTMAXBUTTON;
        }

        if (y < topEdgeSize) {
          if (x < topEdgeSize) {
            return HTTOPLEFT;
          } else if (x > width - topEdgeSize) {
            return HTTOPRIGHT;
          } else {
            return HTTOP;
          }
        } else if (y > height - edgeSize) {
          if (x < edgeSize) {
            return HTBOTTOMLEFT;
          } else if (x > width - edgeSize) {
            return HTBOTTOMRIGHT;
          } else {
            return HTBOTTOM;
          }
        } else if (x < edgeSize) {
          return HTLEFT;
        } else if (x > width - edgeSize) {
          return HTRIGHT;
        }

        for (final excludeRect in _dragExcludeRects.values) {
          if (excludeRect.contains(Offset(x, y))) {
            return HTCLIENT;
          }
        }
        return HTCLIENT;
      case WM_NCMOUSEMOVE:
        if (wParam == HTMAXBUTTON || wParam == HTCAPTION) {
          final (x, y) = splitLParam(lParam);
          final (flutterX, flutterY) = screenToClient(_flutterView, x, y);

          SendMessage(
            _flutterView,
            WM_MOUSEMOVE,
            WPARAM(0),
            LPARAM(makeLParam(flutterX, flutterY)),
          );

          if (!_trackingMouseLeave) {
            final trackMouseEvent = malloc<TRACKMOUSEEVENT>();
            trackMouseEvent.ref.cbSize = sizeOf<TRACKMOUSEEVENT>();
            trackMouseEvent.ref.hwndTrack = _hwnd;
            trackMouseEvent.ref.dwFlags = TME_LEAVE | TME_NONCLIENT;
            TrackMouseEvent(trackMouseEvent);
            malloc.free(trackMouseEvent);
            _trackingMouseLeave = true;
          }
          return 0;
        }
      case WM_NCLBUTTONDOWN:
        if (wParam == HTMAXBUTTON) {
          final (x, y) = splitLParam(lParam);
          final (flutterX, flutterY) = screenToClient(_flutterView, x, y);
          SendMessage(
            _flutterView,
            WM_LBUTTONDOWN,
            WPARAM(0),
            LPARAM(makeLParam(flutterX, flutterY)),
          );
          return 0;
        }
        return null;
      case WM_NCLBUTTONUP:
        if (wParam == HTMAXBUTTON) {
          final (x, y) = splitLParam(lParam);
          final (flutterX, flutterY) = screenToClient(_flutterView, x, y);
          SendMessage(
            _flutterView,
            WM_LBUTTONUP,
            WPARAM(0),
            LPARAM(makeLParam(flutterX, flutterY)),
          );
          return 0;
        }
        return null;
      case WM_NCMOUSELEAVE:
        _trackingMouseLeave = false;
        final cursorPos = malloc<POINT>();
        GetCursorPos(cursorPos);
        final cursorPosLparam = makeLParam(cursorPos.ref.x, cursorPos.ref.y);
        free(cursorPos);
        final flutterHitTest = SendMessage(
          _flutterView,
          WM_NCHITTEST,
          WPARAM(0),
          LPARAM(cursorPosLparam),
        ).value;
        if (flutterHitTest != HTCLIENT) {
          SendMessage(_flutterView, WM_MOUSELEAVE, WPARAM(0), LPARAM(0));
        }
        return 0;
    }
    return null;
  }

  @override
  bool windowNeedsCustomBorder() {
    return false;
  }

  @override
  bool windowNeedsMoveDragDetector() {
    return true;
  }

  @override
  void setCustomBorderShadowWidth(
    double top,
    double left,
    double bottom,
    double right,
  ) {}

  @override
  void startWindowMoveDrag(Offset globalPosition) {
    ReleaseCapture();
    SendMessage(_hwnd, WM_NCLBUTTONDOWN, WPARAM(HTCAPTION), LPARAM(0));
  }

  @override
  void startWindowResizeDrag(Offset globalPosition, WindowEdge edge) {}

  @override
  bool titlebarNeedsDoubleClickDetector() {
    return true;
  }
}
