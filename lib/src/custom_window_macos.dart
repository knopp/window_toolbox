import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter/src/widgets/_window_macos.dart';

import 'custom_window.dart';
import 'invert_rectanges.dart';
import 'macos.g.dart';
import 'macos_extra.dart';
import 'widgets.dart' show WindowTrafficLightInactiveConfigration;

import 'dart:ffi' hide Size;
import 'package:ffi/ffi.dart' as ffi;

class CustomWindowMacOS extends CustomWindow with WindowDelegateMacOS {
  CustomWindowMacOS(this.controller, {required this.onClose}) {
    cw_nswindow_remove_titlebar(controller.windowHandle);
    controller.addDelegate(this);
  }

  final VoidCallback onClose;

  @override
  void windowWillClose() {
    onClose();
  }

  final WindowControllerMacOS controller;

  @override
  Size getTrafficLightSize() {
    final size = cw_nswindow_traffic_light_size(controller.windowHandle);
    return Size(size.w, size.h);
  }

  @override
  void setTrafficLightConfiguration(
    Offset offset,
    Brightness? brightness,
    WindowTrafficLightInactiveConfigration? inactiveConfigration,
  ) {
    final config = ffi.calloc<cw_traffic_light_config_t>();
    config.ref.offset_x = offset.dx;
    config.ref.offset_y = offset.dy;

    config.ref.appearanceAsInt = switch (brightness) {
      Brightness.light => cw_appearance_t.CW_APPEARANCE_LIGHT.value,
      Brightness.dark => cw_appearance_t.CW_APPEARANCE_DARK.value,
      null => cw_appearance_t.CW_APPEARANCE_AUTO.value,
    };

    if (inactiveConfigration != null) {
      config.ref.custom_inactive_traffic_light = true;
      config.ref.inactive_background_color = inactiveConfigration
          .backgroundColor
          .toARGB32();
      config.ref.inactive_border_color = inactiveConfigration.borderColor
          .toARGB32();
      config.ref.inactive_border_width = inactiveConfigration.borderWidth;
      config.ref.show_as_inactive_in_key_window =
          inactiveConfigration.showAsInactiveInKeyWindow;
    } else {
      config.ref.custom_inactive_traffic_light = false;
    }
    cw_nswindow_update_traffic_light(
      controller.windowHandle,
      config,
    );
    ffi.calloc.free(config);
  }

  bool _updateScheduled = false;

  void _update() {
    _updateScheduled = false;

    if (_draggableRects.isEmpty) {
      cw_nswindow_disable_draggable_areas(controller.windowHandle);
    } else {
      final view = _draggableRects.keys.first
          .findAncestorRenderObjectOfType<RenderView>();
      if (view == null) {
        throw StateError('Unexpectedly missing RenderView in heirarchy');
      }
      final bounds = Offset.zero & view.size;

      final invertedRects = invert(bounds, _draggableRects.values);
      final count = invertedRects.length + _dragExcludeRects.length;

      final rectsPointer = ffi.malloc<cw_rect_t>(count);
      for (final (index, rect)
          in invertedRects.followedBy(_dragExcludeRects.values).indexed) {
        rectsPointer[index].x = rect.left;
        rectsPointer[index].y = rect.top;
        rectsPointer[index].w = rect.width;
        rectsPointer[index].h = rect.height;
      }
      cw_nswindow_update_draggable_areas(
        controller.windowHandle,
        rectsPointer,
        count,
      );
    }
  }

  void _scheduleUpdate() {
    if (_updateScheduled) {
      return;
    }
    _updateScheduled = true;
    Future.microtask(_update);
  }

  final _draggableRects = <BuildContext, Rect>{};
  final _dragExcludeRects = <BuildContext, Rect>{};

  @override
  void setDraggableRectForElement(BuildContext element, Rect? rect) {
    if (rect != null) {
      _draggableRects[element] = rect;
    } else {
      _draggableRects.remove(element);
    }
    _scheduleUpdate();
  }

  @override
  void setDragExcludeRectForElement(BuildContext element, Rect? rect) {
    if (rect != null) {
      _dragExcludeRects[element] = rect;
    } else {
      _dragExcludeRects.remove(element);
    }
    _scheduleUpdate();
  }

  @override
  void setMaximizeButtonFrame(BuildContext element, Rect? rect) {}

  @override
  void requestClose() {
    cw_nswindow_request_close(controller.windowHandle);
  }

  @override
  bool windowNeedsMoveDragDetector() {
    return true;
  }

  @override
  bool windowNeedsCustomBorder() {
    return false;
  }

  @override
  void setCustomBorderShadowWidth(
    double top,
    double left,
    double bottom,
    double right,
  ) {}

  @override
  void startWindowMoveDrag(Offset globalPosition) {}

  @override
  void startWindowResizeDrag(Offset globalPosition, WindowEdge edge) {}

  @override
  bool titlebarNeedsDoubleClickDetector() {
    return true;
  }
}
