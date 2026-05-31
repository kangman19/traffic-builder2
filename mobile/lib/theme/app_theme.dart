import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // ── Palette ───────────────────────────────────────────────────────────────

  static const Color background  = Color(0xFF0D0D0F);
  static const Color surface     = Color(0xFF1A1A1D);
  static const Color surfaceAlt  = Color(0xFF222226);
  static const Color accent      = Color(0xFFCC1111);
  static const Color accentDim   = Color(0xFF7A0A0A);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textMuted   = Color(0xFF666672);
  static const Color border      = Color(0xFF2C2C32);

  // ── Text styles ───────────────────────────────────────────────────────────

  static const TextStyle labelStyle = TextStyle(
    color: textMuted,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );

  static const TextStyle statLabel = TextStyle(
    color: textMuted,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
  );

  static const TextStyle statValue = TextStyle(
    color: textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  // ── Theme ─────────────────────────────────────────────────────────────────

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        surface: surface,
        onSurface: textPrimary,
        outline: border,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Shared card decorator ─────────────────────────────────────────────────

  static BoxDecoration cardDecoration({Color? color}) => BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      );
}
