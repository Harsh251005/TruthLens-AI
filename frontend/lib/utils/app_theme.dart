// utils/app_theme.dart
// ============================================================
// Dark theme — Deep Navy + Electric Blue + Gold accent.
// Professional, unique, non-generic design language.
// ============================================================

import 'package:flutter/material.dart';

class AppTheme {
  // ── Background & Surface ──────────────────────────────────────
  static const Color background  = Color(0xFF0A0E1A); // Deep space black
  static const Color surface     = Color(0xFF111827); // Dark navy card
  static const Color surface2    = Color(0xFF1C2333); // Slightly lighter card
  static const Color surfaceBorder = Color(0xFF2A3347); // Subtle card border

  // ── Brand Colors ──────────────────────────────────────────────
  static const Color primary     = Color(0xFF4F8EF7); // Electric blue
  static const Color primaryDark = Color(0xFF2D6CDF); // Deeper blue
  static const Color accent      = Color(0xFFF5A623); // Gold / amber
  static const Color accentDark  = Color(0xFFD4891A); // Darker gold

  // ── Status Colors ─────────────────────────────────────────────
  static const Color success     = Color(0xFF10B981); // Emerald green
  static const Color error       = Color(0xFFEF4444); // Bright red

  // ── Text Colors ───────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF9FAFB); // Near white
  static const Color textSecondary = Color(0xFF9CA3AF); // Muted grey
  static const Color textHint      = Color(0xFF4B5563); // Dim hint text

  // ── Spacing ───────────────────────────────────────────────────
  static const double paddingS  = 8.0;
  static const double paddingM  = 16.0;
  static const double paddingL  = 24.0;
  static const double paddingXL = 32.0;

  // ── Border Radius ─────────────────────────────────────────────
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 20.0;
  static const double radiusXL = 28.0;

  // ── Gradients ─────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F8EF7), Color(0xFF2D6CDF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFF5A623), Color(0xFFD4891A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF0A0E1A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Card Decoration ───────────────────────────────────────────
  /// Standard dark card with subtle border — use everywhere
  static BoxDecoration cardDecoration({Color? borderColor}) => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusL),
    border: Border.all(
      color: borderColor ?? surfaceBorder,
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  /// Glowing card — used for verdict/result highlights
  static BoxDecoration glowDecoration(Color glowColor) => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusL),
    border: Border.all(color: glowColor.withValues(alpha: 0.4), width: 1.5),
    boxShadow: [
      BoxShadow(
        color: glowColor.withValues(alpha: 0.15),
        blurRadius: 24,
        spreadRadius: 2,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // ── ThemeData ─────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary:   primary,
      secondary: accent,
      surface:   surface,
      error:     error,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: paddingM,
        vertical: paddingM,
      ),
      hintStyle: const TextStyle(color: textHint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: const BorderSide(color: surfaceBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: const BorderSide(color: surfaceBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusM),
        borderSide: const BorderSide(color: error),
      ),
    ),

    // Elevated button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
      ),
    ),

    // Text theme
    textTheme: const TextTheme(
      bodyLarge:  TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textPrimary),
      bodySmall:  TextStyle(color: textSecondary),
    ),
  );
}