import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkGold {
    final baseTextTheme = GoogleFonts.notoSerifScTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppTokens.background,
      colorScheme: const ColorScheme.dark(
        surface: AppTokens.surface,
        primary: AppTokens.primary,
        onPrimary: AppTokens.onPrimary,
        onSurface: AppTokens.textPrimary,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: AppTokens.pageTitle,
        headlineMedium: AppTokens.cardTitleStyle,
        bodyLarge: AppTokens.body,
        bodySmall: AppTokens.caption,
        labelLarge: AppTokens.buttonLabel,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTokens.pageTitle,
        iconTheme: IconThemeData(color: AppTokens.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppTokens.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          side: BorderSide(color: AppTokens.cardBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.primary,
          foregroundColor: AppTokens.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radius),
          ),
          textStyle: AppTokens.buttonLabel,
          minimumSize: const Size(0, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.textPrimary,
          side: const BorderSide(color: AppTokens.chipBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radius),
          ),
          textStyle: AppTokens.buttonLabel.copyWith(color: AppTokens.textPrimary),
          minimumSize: const Size(0, 48),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppTokens.primary,
        inactiveTrackColor: AppTokens.surface,
        thumbColor: AppTokens.primary,
        overlayColor: AppTokens.primary.withValues(alpha: 0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          borderSide: const BorderSide(color: AppTokens.inputBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          borderSide: const BorderSide(color: AppTokens.inputBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          borderSide: const BorderSide(color: AppTokens.primary, width: 1.5),
        ),
        labelStyle: AppTokens.caption,
        hintStyle: AppTokens.caption,
      ),
      dividerTheme: const DividerThemeData(
        color: AppTokens.chipBorder,
        thickness: 0.5,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppTokens.surface,
          border: Border.all(color: AppTokens.cardBorder),
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
        textStyle: AppTokens.caption,
      ),
    );
  }
}
