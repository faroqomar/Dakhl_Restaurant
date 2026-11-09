import 'package:flutter/material.dart';

/// Approved Phase 01 roles, reconciled against styles → commerce → ux.css.
abstract final class DakhlTokens {
  static const background = Color(0xFFF6F7F2);
  static const paper = Color(0xFFFEFEFA);
  static const ink = Color(0xFF17382D);
  static const muted = Color(0xFF4C6051);
  static const line = Color(0xFFE2E8DD);
  static const green = Color(0xFF245B42);
  static const lime = Color(0xFFD6E7B8);
  static const soft = Color(0xFFEAF0E4);
  static const red = Color(0xFF9A493E);
  static const focus = Color(0xFF28633F);
  static const double panelRadius = 10;
  static const double inputRadius = 7;
  static const double buttonRadius = 9;
  static const double dialogRadius = 14;
  static const double productRadius = 12;
  static const double photoRadius = 8;
  static const double target = 44;
  static const double panelPadding = 20;
  static double gutter(double width) => width <= 760 ? 14 : 24;
  static bool stacked(BuildContext context, double width) =>
      width < 620 || MediaQuery.textScalerOf(context).scale(16) >= 25.6;
  static const numberStyle = TextStyle(
    fontFamily: 'Inter',
    letterSpacing: 0,
    fontFamilyFallback: ['Amiri'],
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

abstract final class DakhlTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: DakhlTokens.green,
      onPrimary: DakhlTokens.paper,
      secondary: DakhlTokens.soft,
      onSecondary: DakhlTokens.ink,
      surface: DakhlTokens.paper,
      onSurface: DakhlTokens.ink,
      error: DakhlTokens.red,
      onError: DakhlTokens.paper,
      outline: DakhlTokens.line,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(DakhlTokens.inputRadius),
      borderSide: const BorderSide(color: DakhlTokens.line),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Amiri',
      scaffoldBackgroundColor: DakhlTokens.background,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: NoSplash.splashFactory,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          fontSize: 16,
          height: 1.6,
          color: DakhlTokens.ink,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: DakhlTokens.muted,
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          height: 1.5,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.5,
          fontWeight: FontWeight.bold,
        ),
        labelLarge: TextStyle(fontSize: 16, height: 1.5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DakhlTokens.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: DakhlTokens.focus, width: 3),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: DakhlTokens.red),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: DakhlTokens.red, width: 3),
        ),
        errorMaxLines: 4,
      ),
      dividerTheme: const DividerThemeData(
        color: DakhlTokens.line,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: DakhlTokens.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DakhlTokens.dialogRadius),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: DakhlTokens.green,
        selectionColor: DakhlTokens.lime,
      ),
      tooltipTheme: const TooltipThemeData(preferBelow: true),
    );
  }
}
