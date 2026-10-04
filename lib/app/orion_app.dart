import 'package:flutter/material.dart';

import '../core/theme/orion_theme.dart';
import '../features/auth/presentation/landing_screen.dart';

class OrionApp extends StatelessWidget {
  const OrionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orion Marketplace',
      debugShowCheckedModeBanner: false,
      theme: OrionTheme.light,
      home: const LandingScreen(),
    );
  }
}
