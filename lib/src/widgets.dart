import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:headless_widgets/headless_widgets.dart';
import 'custom_window.dart';

import 'package:flutter/src/widgets/_window.dart';

/// Represents an area in Window that can be used to drag the window. This is
/// typically used to implement custom title bars.
///
/// The widgets inside the area are still interactive, but pan gestures
/// will not work as pan gesture will result in dragging the window.
///
/// To mark sub-areas that should not trigger dragging, use [WindowDragExcludeArea].
class WindowDragArea extends StatefulWidget {
  const WindowDragArea({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<WindowDragArea> createState() => _WindowDragAreaState();
}

/// Represents area within [WindowDragArea] that should not trigger window dragging.
/// This is typically used for toolbar or tabs that are placed inside title bar.
class WindowDragExcludeArea extends StatefulWidget {
  const WindowDragExcludeArea({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<WindowDragExcludeArea> createState() => _WindowDragExcludeState();
}

enum WindowTrafficLightMode {
  /// Traffic light buttons are visible and take space in layout.
  visible,

  /// Traffic light buttons are invisible but still take space in layout.
  invisible,

  /// Traffic light buttons are absent and do not take space in layout.
  removed,
}

/// Represents macOS traffic light buttons. Wherever this width is placed, the
/// window traffic light buttons will be positioned.
///
/// On other platform this renders as [SizedBox.shrink] and has no effect.
class WindowTrafficLight extends StatefulWidget {
  const WindowTrafficLight({
    super.key,
    this.mode = WindowTrafficLightMode.visible,
  });

  /// Traffic light visibility mode.
  final WindowTrafficLightMode mode;

  @override
  State<WindowTrafficLight> createState() => _WindowTrafficLightState();
}

/// Represents state of a titlebar button (close, minimize, maximize).
/// This is used in content builder of [CloseButton], [MinimizeButton]
/// and [MaximizeButton].
class TitlebarButtonState {
  TitlebarButtonState({
    required this.enabled,
    required this.hovered,
    required this.pressed,
  });

  /// Whether the button is enabled (clickable).
  final bool enabled;

  /// Whether the button is currently hovered by mouse cursor.
  final bool hovered;

  /// Whether the button is currently pressed and mouse cursor is inside button area.
  final bool pressed;
}

/// Button for maximizing and restoring the window.
///
/// Supports displaying [snap layout](https://support.microsoft.com/en-us/windows/snap-your-windows-885a9b1e-a983-a3b1-16cd-c531795e6241)
/// on Windows when hovered.
class MaximizeButton extends StatefulWidget {
  const MaximizeButton({
    super.key,
    required this.builder,
    this.enabled = true,
  });

  final Widget Function(
    BuildContext context,
    TitlebarButtonState state,
    bool isMaximized,
  )
  builder;

  final bool enabled;

  @override
  State<MaximizeButton> createState() => _MaximizeButtonState();
}

/// Button for minimizing the window.
class MinimizeButton extends StatefulWidget {
  const MinimizeButton({super.key, required this.builder, this.enabled = true});

  final Widget Function(BuildContext context, TitlebarButtonState state)
  builder;

  final bool enabled;

  @override
  State<MinimizeButton> createState() => _MinimizeButtonState();
}

/// Button for closing the window.
///
/// This button triggers same action as native close button would,
/// meaning that the action can be prevented by overriding
/// [RegularWindowControllerDelegate.onWindowCloseRequested].
class CloseButton extends StatefulWidget {
  const CloseButton({super.key, required this.builder, this.enabled = true});

  final Widget Function(BuildContext context, TitlebarButtonState state)
  builder;

  final bool enabled;

  @override
  State<CloseButton> createState() => _CloseButtonState();
}

/// Widget that draws custom border and shadow around the window.
/// This will only have effect on Linux, on other platforms system
/// compositor will draw the border and shadow.
class WindowBorder extends StatefulWidget {
  const WindowBorder({
    super.key,
    required this.child,
    this.cornerRadius = 12.0,
  });

  final Widget child;
  final double cornerRadius;

  @override
  State<WindowBorder> createState() => _WindowBorderState();
}

//
// Implementation details.
//

class _CloseButtonState extends State<CloseButton> {
  @override
  Widget build(BuildContext context) {
    return WindowDragExcludeArea(
      child: Button(
        builder: (context, buttonState, child) {
          return widget.builder(
            context,
            TitlebarButtonState(
              enabled: buttonState.enabled,
              hovered: buttonState.hovered,
              pressed: buttonState.pressed,
            ),
          );
        },
        focusNode: _buttonNode,
        onPressed: widget.enabled ? _onPressed : null,
      ),
    );
  }

  void _onPressed() {
    final customWindow = CustomWindow.forController(WindowScope.of(context));
    customWindow?.requestClose();
  }

  final _buttonNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _buttonNode.canRequestFocus = false;
    _buttonNode.skipTraversal = true;
  }

  @override
  void dispose() {
    super.dispose();
    _buttonNode.dispose();
  }
}

class _MinimizeButtonState extends State<MinimizeButton> {
  @override
  Widget build(BuildContext context) {
    return WindowDragExcludeArea(
      child: Button(
        builder: (context, buttonState, child) {
          return widget.builder(
            context,
            TitlebarButtonState(
              enabled: buttonState.enabled,
              hovered: buttonState.hovered,
              pressed: buttonState.pressed,
            ),
          );
        },
        focusNode: _buttonNode,
        onPressed: widget.enabled ? _onPressed : null,
      ),
    );
  }

  void _onPressed() {
    final controller = WindowScope.of(context);
    if (controller is RegularWindowController) {
      controller.setMinimized(true);
    } else if (controller is DialogWindowController) {
      controller.setMinimized(true);
    }
  }

  final _buttonNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _buttonNode.canRequestFocus = false;
    _buttonNode.skipTraversal = true;
  }

  @override
  void dispose() {
    super.dispose();
    _buttonNode.dispose();
  }
}

class _MaximizeButtonState extends _FrameReportingState<MaximizeButton> {
  @override
  Widget build(BuildContext context) {
    return WindowDragExcludeArea(
      child: Button(
        builder: (context, buttonState, child) {
          return widget.builder(
            context,
            TitlebarButtonState(
              enabled: buttonState.enabled,
              hovered: buttonState.hovered,
              pressed: buttonState.pressed,
            ),
            _isMaximized,
          );
        },
        focusNode: _buttonNode,
        onPressed: widget.enabled ? _onPressed : null,
      ),
    );
  }

  void _onPressed() {
    final controller = WindowScope.of(context) as RegularWindowController;
    controller.setMaximized(!controller.isMaximized);
  }

  BaseWindowController? _controller;
  bool _lastMaximized = false;
  final _buttonNode = FocusNode();
  bool get _isMaximized => (_controller as RegularWindowController).isMaximized;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller?.removeListener(_controllerListener);
    _controller = WindowScope.of(context);
    _controller!.addListener(_controllerListener);
  }

  void _controllerListener() {
    if (!mounted) {
      return;
    }
    if (_isMaximized != _lastMaximized) {
      _lastMaximized = _isMaximized;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _buttonNode.canRequestFocus = false;
    _buttonNode.skipTraversal = true;
  }

  @override
  void dispose() {
    super.dispose();
    _buttonNode.dispose();
    _controller?.removeListener(_controllerListener);
  }

  @override
  void reportFrame(CustomWindow window, Rect? rect) {
    window.setMaximizeButtonFrame(context, rect);
  }
}

abstract class _FrameReportingState<T extends StatefulWidget> extends State<T> {
  void reportFrame(CustomWindow window, Rect? rect);

  CustomWindow? _customWindow;

  void _frameTick() {
    if (!mounted) {
      return;
    }

    final customWindow = CustomWindow.forController(WindowScope.of(context));
    if (customWindow != null) {
      final view = context.findRenderObject() as RenderBox;
      final transform = view.getTransformTo(null);
      final rect = MatrixUtils.transformRect(
        transform,
        Offset.zero & view.size,
      );
      if (_customWindow != customWindow) {
        if (_customWindow != null) {
          reportFrame(customWindow, null);
        }
        _customWindow = customWindow;
      }
      reportFrame(customWindow, rect);
    }
  }

  @override
  void initState() {
    super.initState();
    _PersistentFrameCallbackManager.instance.addCallback(_frameTick);
  }

  @override
  void dispose() {
    _PersistentFrameCallbackManager.instance.removeCallback(_frameTick);
    if (_customWindow != null) {
      reportFrame(_customWindow!, null);
    }
    super.dispose();
  }
}

class _WindowDragAreaState extends _FrameReportingState<WindowDragArea> {
  @override
  Widget build(BuildContext context) {
    final gestures = <Type, GestureRecognizerFactory>{};
    final customWindow = CustomWindow.forController(WindowScope.of(context));
    if (customWindow?.windowNeedsMoveDragDetector() == true) {
      gestures[_DragPanGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<_DragPanGestureRecognizer>(
            () => _DragPanGestureRecognizer(debugOwner: this),
            (_DragPanGestureRecognizer instance) {
              instance.onStart = (details) {
                final customWindow = CustomWindow.forController(
                  WindowScope.of(context),
                )!;
                customWindow.startWindowMoveDrag(details.globalPosition);
              };
            },
          );
    }
    final controller = WindowScope.of(context);
    if (customWindow?.titlebarNeedsDoubleClickDetector() == true &&
        controller is RegularWindowController) {
      gestures[_DoubleTapToMaximizeGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<
            _DoubleTapToMaximizeGestureRecognizer
          >(() => _DoubleTapToMaximizeGestureRecognizer(debugOwner: this), (
            _DoubleTapToMaximizeGestureRecognizer instance,
          ) {
            instance.onDoubleTap = () {
              controller.setMaximized(!controller.isMaximized);
            };
          });
    }
    if (gestures.isNotEmpty) {
      return RawGestureDetector(
        gestures: gestures,
        behavior: HitTestBehavior.translucent,
        child: widget.child,
      );
    } else {
      return widget.child;
    }
  }

  @override
  void reportFrame(CustomWindow window, Rect? rect) {
    window.setDraggableRectForElement(context, rect);
  }
}

class _WindowDragExcludeState
    extends _FrameReportingState<WindowDragExcludeArea> {
  @override
  Widget build(BuildContext context) {
    return _DragExcludeWidget(child: widget.child);
  }

  @override
  void reportFrame(CustomWindow window, Rect? rect) {
    window.setDragExcludeRectForElement(context, rect);
  }
}

class _WindowTrafficLightState
    extends _FrameReportingState<WindowTrafficLight> {
  @override
  Widget build(BuildContext context) {
    final customWindow = CustomWindow.forController(WindowScope.of(context));
    if (customWindow == null || widget.mode == WindowTrafficLightMode.removed) {
      return const SizedBox.shrink();
    } else {
      return SizedBox.fromSize(size: customWindow.getTrafficLightSize());
    }
  }

  @override
  void reportFrame(CustomWindow window, Rect? rect) {
    if (widget.mode == WindowTrafficLightMode.invisible ||
        widget.mode == WindowTrafficLightMode.removed) {
      window.setTrafficLightPosition(Offset(0, -100));
    } else if (rect != null) {
      window.setTrafficLightPosition(rect.topLeft);
    }
  }
}

class _WindowBorderState extends State<WindowBorder> {
  // Complete padding around the content, must be enough for shadow to blend smoothly
  static const _borderPadding = 16.0;
  // Part of border padding that can is user interactive (resizing handles)
  static const _resizingHandleThickness = 12.0;
  // Part of resizing handles that is inside window frame
  static const _resizingHandleThicknessInside = 2.0;

  @override
  void didChangeDependencies() {
    final customWindow = CustomWindow.forController(WindowScope.of(context));
    if (customWindow != null && customWindow.windowNeedsCustomBorder()) {
      customWindow.setCustomBorderShadowWidth(
        _borderPadding,
        _borderPadding,
        _borderPadding,
        _borderPadding,
      );
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final customWindow = CustomWindow.forController(WindowScope.of(context));
    if (customWindow == null || !customWindow.windowNeedsCustomBorder()) {
      return widget.child;
    }
    // TODO: This should be adjusted when window is maximized
    // (or docked to the side of screen)
    final effectiveCornerRadius = widget.cornerRadius;
    return Padding(
      padding: const EdgeInsets.all(
        _borderPadding -
            _resizingHandleThickness +
            _resizingHandleThicknessInside,
      ),
      child: _ResizingHandles(
        thickness: _resizingHandleThickness,
        cornerSize: _resizingHandleThickness + effectiveCornerRadius / 2.0,
        child: Padding(
          padding: const EdgeInsets.all(
            _resizingHandleThickness - _resizingHandleThicknessInside,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(effectiveCornerRadius),
              border: Border.all(
                width: 1,
                color: Color(0xFF000000).withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF000000).withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(effectiveCornerRadius),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResizingHandles extends StatelessWidget {
  const _ResizingHandles({
    // ignore: unused_element_parameter
    super.key,
    required this.thickness,
    required this.cornerSize,
    required this.child,
  });

  final Widget child;
  final double cornerSize;
  final double thickness;

  Widget _buildHandle(WindowEdge edge, BuildContext context) {
    final cursor = switch (edge) {
      WindowEdge.northWest => SystemMouseCursors.resizeUpLeftDownRight,
      WindowEdge.north => SystemMouseCursors.resizeUpDown,
      WindowEdge.northEast => SystemMouseCursors.resizeUpRightDownLeft,
      WindowEdge.west => SystemMouseCursors.resizeLeftRight,
      WindowEdge.east => SystemMouseCursors.resizeLeftRight,
      WindowEdge.southWest => SystemMouseCursors.resizeUpRightDownLeft,
      WindowEdge.south => SystemMouseCursors.resizeUpDown,
      WindowEdge.southEast => SystemMouseCursors.resizeUpLeftDownRight,
    };
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          final customWindow = CustomWindow.forController(
            WindowScope.of(context),
          )!;
          customWindow.startWindowResizeDrag(details.globalPosition, edge);
        },
        child: SizedBox.expand(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      alignment: Alignment.topLeft,
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          width: cornerSize,
          height: cornerSize,
          child: _buildHandle(WindowEdge.northWest, context),
        ),
        Positioned(
          top: 0,
          left: cornerSize,
          right: cornerSize,
          height: thickness,
          child: _buildHandle(WindowEdge.north, context),
        ),
        Positioned(
          top: 0,
          right: 0,
          width: cornerSize,
          height: cornerSize,
          child: _buildHandle(WindowEdge.northEast, context),
        ),
        Positioned(
          top: cornerSize,
          left: 0,
          bottom: cornerSize,
          width: thickness,
          child: _buildHandle(WindowEdge.west, context),
        ),
        Positioned(
          top: cornerSize,
          right: 0,
          bottom: cornerSize,
          width: thickness,
          child: _buildHandle(WindowEdge.east, context),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          width: cornerSize,
          height: cornerSize,
          child: _buildHandle(WindowEdge.southWest, context),
        ),
        Positioned(
          bottom: 0,
          left: cornerSize,
          right: cornerSize,
          height: thickness,
          child: _buildHandle(WindowEdge.south, context),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          width: cornerSize,
          height: cornerSize,
          child: _buildHandle(WindowEdge.southEast, context),
        ),
      ],
    );
  }
}

class _PersistentFrameCallbackManager {
  _PersistentFrameCallbackManager._() {
    WidgetsBinding.instance.addPersistentFrameCallback((_) {
      final callbacksCopy = List<VoidCallback>.from(
        _callbacks,
        growable: false,
      );
      for (final callback in callbacksCopy) {
        callback();
      }
    });
  }

  void addCallback(VoidCallback callback) {
    _callbacks.add(callback);
  }

  void removeCallback(VoidCallback callback) {
    _callbacks.remove(callback);
  }

  final _callbacks = <VoidCallback>[];
  static final instance = _PersistentFrameCallbackManager._();
}

class _DragExcludeWidget extends SingleChildRenderObjectWidget {
  // ignore: unused_element_parameter
  const _DragExcludeWidget({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _DragExcludeRenderObject();
  }
}

class _DragExcludeRenderObject extends RenderProxyBox {}

class _DragPanGestureRecognizer extends PanGestureRecognizer {
  _DragPanGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    final HitTestResult result = HitTestResult();
    RendererBinding.instance.hitTestInView(
      result,
      event.position,
      event.viewId,
    );
    for (final hit in result.path) {
      if (hit.target is _DragExcludeRenderObject) {
        return;
      }
    }
    super.addAllowedPointer(event);
  }
}

class _DoubleTapToMaximizeGestureRecognizer extends DoubleTapGestureRecognizer {
  _DoubleTapToMaximizeGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    final HitTestResult result = HitTestResult();
    RendererBinding.instance.hitTestInView(
      result,
      event.position,
      event.viewId,
    );
    for (final hit in result.path) {
      if (hit.target is _DragExcludeRenderObject) {
        return;
      }
    }
    super.addAllowedPointer(event);
  }
}
