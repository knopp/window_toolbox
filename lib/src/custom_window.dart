import 'package:flutter/src/widgets/_window.dart';
import 'package:flutter/src/widgets/_window_macos.dart';
import 'package:flutter/src/widgets/_window_win32.dart';
import 'package:flutter/src/widgets/_window_linux.dart';
import 'package:flutter/widgets.dart';

import 'custom_window_macos.dart';
import 'custom_window_win32.dart';
import 'custom_window_linux.dart';

abstract class CustomWindow {
  static CustomWindow? forController(BaseWindowController controller) {
    return _expando[controller];
  }

  static void init(BaseWindowController controller) {
    final created = _create(
      controller,
      onClose: () {
        _expando[controller] = null;
      },
    );
    if (created != null) {
      _expando[controller] = created;
    }
  }

  static final _expando = Expando<CustomWindow>('CustomWindow');

  static CustomWindow? _create(
    BaseWindowController controller, {
    required VoidCallback onClose,
  }) {
    if (controller is WindowControllerMacOS) {
      return CustomWindowMacOS(
        controller as WindowControllerMacOS,
        onClose: onClose,
      );
    } else if (controller is WindowControllerWin32) {
      return CustomWindowWin32(controller as WindowControllerWin32);
    } else if (controller is WindowControllerLinux) {
      return CustomWindowLinux(controller as WindowControllerLinux);
    } else {
      return null;
    }
  }

  void setDraggableRectForElement(BuildContext element, Rect? rect);
  void setDragExcludeRectForElement(BuildContext element, Rect? rect);
  void setTrafficLightPosition(Offset offset);
  void setMaximizeButtonFrame(BuildContext element, Rect? rect);
  Size getTrafficLightSize();
  void requestClose();

  bool windowNeedsMoveDragDetector();
  bool windowNeedsCustomBorder();
  bool titlebarNeedsDoubleClickDetector();
  void setCustomBorderShadowWidth(
    double top,
    double left,
    double bottom,
    double right,
  );

  void startWindowMoveDrag(Offset globalPosition);
  void startWindowResizeDrag(Offset globalPosition, WindowEdge edge);
}

enum WindowEdge {
  northWest,
  north,
  northEast,
  west,
  east,
  southWest,
  south,
  southEast,
}
