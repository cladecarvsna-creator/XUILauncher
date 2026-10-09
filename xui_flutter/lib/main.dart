import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'core/launcher_controller.dart';
import 'core/paths.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    // Window in the proportions of the design, frameless and transparent so
    // the rounded corners of the launcher are the corners of the window.
    const options = WindowOptions(
      size: Size(Scale.designWidth * 1.4, Scale.designHeight * 1.4),
      minimumSize: Size(Scale.designWidth, Scale.designHeight),
      center: true,
      title: 'XUI Launcher',
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final controller = LauncherController(await LauncherPaths.resolve());
  await controller.load();
  runApp(XuiLauncherApp(controller: controller));
}

class XuiLauncherApp extends StatelessWidget {
  const XuiLauncherApp({super.key, required this.controller});

  final LauncherController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XUI Launcher',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      color: Colors.transparent,
      // The scale factor lives above the navigator so dialogs scale too.
      builder: (context, child) {
        final size = MediaQuery.sizeOf(context);
        final k = (size.width / Scale.designWidth)
            .clamp(0.5, size.height / Scale.designHeight)
            .toDouble();
        return Scale(k: k, child: child!);
      },
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: LauncherShell(c: controller),
      ),
    );
  }
}
