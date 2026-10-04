import 'package:flutter/material.dart';

/// Official ORION_COLOR palette from assets/images/ORION_COLOR.png:
/// 1. #F20505 - Vibrant Red (Primary Accent, Active Glow, CTA)
/// 2. #A60303 - Crimson Red (Secondary, Gradient End)
/// 3. #590202 - Oxblood (Borders, Elevated Surface, Indicator)
/// 4. #260101 - Dark Burgundy (Card Surface, Container Fill)
/// 5. #0D0D0D - Pitch Black (Scaffold Background, Deep Contrast)
abstract final class OrionColors {
  static const red = Color(0xFFF20505);
  static const crimson = Color(0xFFA60303);
  static const oxblood = Color(0xFF590202);
  static const darkRed = Color(0xFF260101);
  static const black = Color(0xFF0D0D0D);

  // Semantic mappings
  static const paper = black;
  static const surface = darkRed;
  static const raisedSurface = oxblood;
  static const muted = Color(0xBFFFFFFF);
  static const paleRed = darkRed;
  static const lightRed = Colors.white;

  // Preset gradients using official ORION_COLOR palette
  static const buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [red, crimson],
  );

  static const surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [oxblood, darkRed, black],
  );

  static const atmosphericOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.25, 0.55, 0.85, 1.0],
    colors: [
      Color(0x73000000),
      Colors.transparent,
      Color(0x8C0D0D0D),
      Color(0xEB0D0D0D),
      black,
    ],
  );
}

abstract final class OrionTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: OrionColors.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: OrionColors.crimson,
      primary: OrionColors.red,
      secondary: OrionColors.crimson,
      surface: OrionColors.paper,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: OrionColors.paper,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(color: OrionColors.surface),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: OrionColors.black,
      indicatorColor: OrionColors.oxblood,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(color: Colors.white)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OrionColors.surface,
      hintStyle: const TextStyle(color: OrionColors.muted),
      labelStyle: const TextStyle(color: OrionColors.muted),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: OrionColors.oxblood),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: OrionColors.red, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        color: Colors.white,
        fontSize: 29,
        height: 1.05,
        fontWeight: FontWeight.w700,
        fontFamily: 'serif',
      ),
      titleLarge: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
    ),
  );
}
