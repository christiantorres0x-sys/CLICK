import 'package:flutter/material.dart';

import '../core/constants/app_info.dart';
import '../features/player/youtube_dock.dart';
import '../features/shell/app_shell.dart';
import 'theme/app_theme.dart';

class ClickApp extends StatelessWidget {
  const ClickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: buildClickTheme(),
      // The YouTube player is pinned above every screen while a YouTube track plays.
      builder: (context, child) => YoutubeDockHost(child: child ?? const SizedBox.shrink()),
      home: const AppShell(),
    );
  }
}
