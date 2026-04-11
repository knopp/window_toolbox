// ignore_for_file: invalid_use_of_internal_member, implementation_imports

import 'package:flutter/src/widgets/_window_linux.dart';
import 'package:flutter/widgets.dart';

import 'custom_window.dart';
import 'dart:ffi' as ffi;
import 'linux.g.dart';

class CustomWindowLinux extends CustomWindow {
  CustomWindowLinux(this.controller) {
    cw_gtk_window_remove_decorations(
      controller.getWindowHandle(),
      controller.getFlutterViewHandle(),
    );
    cw_init_event_hooks_if_needed();
  }

  final WindowControllerLinux controller;

  @override
  void requestClose() {
    _gtkWindowClose(controller.getWindowHandle());
  }

  @override
  void setDragExcludeRectForElement(BuildContext element, Rect? rect) {}

  @override
  void setDraggableRectForElement(BuildContext element, Rect? rect) {}

  @override
  void setMaximizeButtonFrame(BuildContext element, Rect? rect) {}

  @override
  void setTrafficLightPosition(Offset offset) {}

  @override
  Size getTrafficLightSize() {
    return Size.zero;
  }

  @override
  bool windowNeedsMoveDragDetector() {
    return true;
  }

  @override
  bool windowNeedsCustomBorder() {
    // TODO: Determine if we're running with SSD.
    return true;
  }

  @override
  bool titlebarNeedsDoubleClickDetector() {
    return true;
  }

  @override
  void setCustomBorderShadowWidth(
    double top,
    double left,
    double bottom,
    double right,
  ) {
    final window = controller.getWindowHandle();
    cw_window_set_shadow_width(
      window,
      top.round(),
      left.round(),
      bottom.round(),
      right.round(),
    );
  }

  @override
  void startWindowMoveDrag(Offset globalPosition) {
    final window = controller.getWindowHandle();
    cw_window_begin_move_drag(
      window,
      globalPosition.dx.round(),
      globalPosition.dy.round(),
    );
  }

  @override
  void startWindowResizeDrag(Offset globalPosition, WindowEdge edge) {
    final gtkEdge = switch (edge) {
      WindowEdge.northWest => cw_window_edge_t.CW_WINDOW_EDGE_NORTH_WEST,
      WindowEdge.north => cw_window_edge_t.CW_WINDOW_EDGE_NORTH,
      WindowEdge.northEast => cw_window_edge_t.CW_WINDOW_EDGE_NORTH_EAST,
      WindowEdge.west => cw_window_edge_t.CW_WINDOW_EDGE_WEST,
      WindowEdge.east => cw_window_edge_t.CW_WINDOW_EDGE_EAST,
      WindowEdge.southWest => cw_window_edge_t.CW_WINDOW_EDGE_SOUTH_WEST,
      WindowEdge.south => cw_window_edge_t.CW_WINDOW_EDGE_SOUTH,
      WindowEdge.southEast => cw_window_edge_t.CW_WINDOW_EDGE_SOUTH_EAST,
    };
    final window = controller.getWindowHandle();
    cw_window_begin_resize_drag(
      window,
      gtkEdge,
      globalPosition.dx.round(),
      globalPosition.dy.round(),
    );
  }
}

@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.NativeType>)>(
  symbol: 'gtk_window_close',
)
external void _gtkWindowClose(ffi.Pointer<ffi.NativeType> window);
