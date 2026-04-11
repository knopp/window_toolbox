// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:windowkit/src/custom_window.dart';
import 'package:windowkit/src/widgets.dart';
import 'package:flutter/material.dart' hide CloseButton;
import 'package:flutter/src/widgets/_window.dart';

class MainControllerWindowDelegate with RegularWindowControllerDelegate {
  @override
  void onWindowDestroyed() {
    super.onWindowDestroyed();
    exit(0);
  }
}

void main() async {
  final info = await Service.getInfo();
  if (info.serverUri != null) {
    final json = {'uri': info.serverUri.toString()};
    File('vmservice.json').writeAsStringSync(jsonEncode(json));
  }
  WidgetsFlutterBinding.ensureInitialized();

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
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade300),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          TitleBar(),
          SizedBox(height: 50),
          Center(
            child: WindowDraggableArea(
              child: Container(
                color: Colors.green,
                padding: EdgeInsets.all(40),
                child: Text('Draggable Area Widget'),
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
    return WindowDraggableArea(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade500, width: 1),
          ),
        ),
        height: 50,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 20),
            GestureDetector(
              onTap: () {
                print('Titlebar tapped');
              },
              child: Center(
                child: Text('Custom Titlebar', style: TextStyle(fontSize: 18)),
              ),
            ),
            Center(child: WindowTrafficLight()),
            Spacer(),
            Center(
              child: WindowDraggableExclude(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    border: Border.all(color: Colors.grey.shade500, width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text('Non-draggable area for tabs or other controls'),
                ),
              ),
            ),
            Spacer(),
            Container(
              alignment: Alignment.topCenter,
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade500, width: 1),
                    bottom: BorderSide(color: Colors.grey.shade500, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    MinimizeButton(
                      builder: (context, state) {
                        Color color;
                        if (state.pressed) {
                          color = Colors.white.withValues(alpha: 0.5);
                        } else if (state.hovered) {
                          color = Colors.white.withValues(alpha: 0.3);
                        } else {
                          color = Colors.transparent;
                        }
                        return Container(
                          width: 40,
                          color: color,
                          alignment: Alignment.center,
                          child: Icon(Icons.horizontal_rule_outlined),
                        );
                      },
                    ),
                    MaximizeButton(
                      builder: (context, state, isMaximized) {
                        Color color;
                        if (state.pressed) {
                          color = Colors.white.withValues(alpha: 0.5);
                        } else if (state.hovered) {
                          color = Colors.white.withValues(alpha: 0.3);
                        } else {
                          color = Colors.transparent;
                        }
                        return Container(
                          width: 40,
                          color: color,
                          alignment: Alignment.center,
                          child: Icon(Icons.square_outlined),
                        );
                      },
                    ),
                    CloseButton(
                      builder: (context, state) {
                        Color color;
                        if (state.pressed) {
                          color = Colors.red.shade700;
                        } else if (state.hovered) {
                          color = Colors.red;
                        } else {
                          color = Colors.transparent;
                        }
                        return Container(
                          width: 40,
                          color: color,
                          alignment: Alignment.center,
                          child: Icon(Icons.close_outlined),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    CustomWindow.init(controller);
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
