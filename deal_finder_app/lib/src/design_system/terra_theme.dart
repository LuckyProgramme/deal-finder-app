import 'package:flutter/material.dart';

abstract final class Terra {
  static const primary = Color(0xFF4A7C59),
      background = Color(0xFFFAF6F0),
      surface = Color(0xFFFFFFFF),
      sandstone = Color(0xFFF2ECE1),
      amber = Color(0xFF705C30),
      ink = Color(0xFF2D332D),
      muted = Color(0xFF687066),
      savings = Color(0xFF3E704D),
      warning = Color(0xFF996826),
      outline = Color(0x1F4A7C59);
  static const radius = 12.0;
  static const mobileMargin = 16.0, desktopMargin = 32.0, contentWidth = 1100.0;
  static const shellBreakpoint = 840.0;

  static ThemeData get theme {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          secondary: amber,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: muted,
          outlineVariant: outline,
          surfaceContainerLow: background,
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Nunito Sans',
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontFamily: 'Literata',
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: ink,
          height: 1.3,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'Literata',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ink,
          height: 1.35,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Literata',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ink,
          height: 1.4,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'Nunito Sans',
          fontSize: 14,
          color: ink,
          height: 1.6,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontFamily: 'Literata',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ink,
          height: 1.35,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: sandstone,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        indicatorColor: primary.withValues(alpha: .15),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: sandstone,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
