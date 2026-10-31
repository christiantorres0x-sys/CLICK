import 'package:flutter/material.dart';

import '../core/constants/app_info.dart';
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
      home: const AppShell(),
    );
  }
}
