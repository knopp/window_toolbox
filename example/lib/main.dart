// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:window_toolbox/window_toolbox.dart';
import 'package:flutter/material.dart' hide CloseButton;
import 'package:flutter/src/widgets/_window.dart';
import 'package:window_toolbox_example/icons.dart';

class MainControllerWindowDelegate with RegularWindowControllerDelegate {
  @override
  void onWindowDestroyed() {
    super.onWindowDestroyed();
    exit(0);
  }
}

void main() async {
  runWidget(MultiWindowApp());
}

class MultiWindowApp extends StatefulWidget {
  const MultiWindowApp({super.key});

  @override
  State<MultiWindowApp> createState() => _MultiWindowAppState();
}

class MainWindow extends StatelessWidget {
  final RegularWindowController controller;

  const MainWindow({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.grey.shade300,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitleBar(),
          Spacer(),
          WindowDragArea(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade500, width: 1),
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Text(
                'Additional Draggable Area',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return WindowDragArea(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade500, width: 1),
          ),
        ),
        height: 50,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Spacer(),
                Center(
                  child: WindowDragExcludeArea(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        border: Border.all(
                          color: Colors.grey.shade500,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        'Non-draggable area for tabs or other controls',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
                Spacer(),
              ],
            ),
            if (Platform.isMacOS)
              Positioned(
                left: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: WindowTrafficLight(
                    mode: WindowTrafficLightMode.visible,
                  ),
                ),
              ),
            if (!Platform.isMacOS)
              Positioned(
                right: 0,
                top: 0,
                child: _WindowButtons(),
              ),
          ],
        ),
      ),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  // ignore: unused_element_parameter
  const _WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    const buttonSize = Size(40, 34);
    return SizedBox(
      height: buttonSize.height,
      child: Row(
        children: [
          MinimizeButton(
            builder: (context, state) {
              final Color backgroundColor;
              if (state.pressed) {
                backgroundColor = Colors.white.withValues(alpha: 0.5);
              } else if (state.hovered) {
                backgroundColor = Colors.white.withValues(alpha: 0.3);
              } else {
                backgroundColor = Colors.transparent;
              }
              return Container(
                width: buttonSize.width,
                color: backgroundColor,
                alignment: Alignment.center,
                child: MinimizeIcon(color: Colors.black),
              );
            },
          ),
          MaximizeButton(
            builder: (context, state, isMaximized) {
              final Color backgroundColor;
              if (state.pressed) {
                backgroundColor = Colors.white.withValues(alpha: 0.5);
              } else if (state.hovered) {
                backgroundColor = Colors.white.withValues(alpha: 0.3);
              } else {
                backgroundColor = Colors.transparent;
              }
              return Container(
                width: buttonSize.width,
                color: backgroundColor,
                alignment: Alignment.center,
                child: isMaximized
                    ? RestoreIcon(color: Colors.black)
                    : MaximizeIcon(color: Colors.black),
              );
            },
          ),
          CloseButton(
            builder: (context, state) {
              final Color backgroundColor;
              final Color iconColor;
              if (state.pressed) {
                backgroundColor = Colors.red.shade700;
                iconColor = Colors.white;
              } else if (state.hovered) {
                backgroundColor = Colors.red;
                iconColor = Colors.white;
              } else {
                backgroundColor = Colors.transparent;
                iconColor = Colors.black;
              }
              return Container(
                width: buttonSize.width,
                color: backgroundColor,
                alignment: Alignment.center,
                child: CloseIcon(color: iconColor),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MultiWindowAppState extends State<MultiWindowApp> {
  late final RegularWindowController controller;

  @override
  void initState() {
    controller = RegularWindowController(
      preferredSize: const Size(800, 600),
      title: 'Multi-Window Reference Application',
      delegate: MainControllerWindowDelegate(),
    );
    controller.enableCustomWindow();
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RegularWindow(
      controller: controller,
      child: WindowBorder(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: MainWindow(controller: controller)),
        ),
      ),
    );
  }
}
