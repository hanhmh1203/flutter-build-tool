import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.accent,
      onPrimary: AppColors.surface,
      primaryContainer: AppColors.accentSoft,
      onPrimaryContainer: AppColors.accent,
      secondary: AppColors.text2,
      onSecondary: AppColors.surface,
      secondaryContainer: AppColors.surface2,
      onSecondaryContainer: AppColors.text2,
      tertiary: AppColors.ok,
      onTertiary: AppColors.surface,
      tertiaryContainer: AppColors.accentTint,
      onTertiaryContainer: AppColors.text,
      error: AppColors.danger,
      onError: AppColors.surface,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: AppColors.danger,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.surface2,
      onSurfaceVariant: AppColors.text2,
      outline: AppColors.border,
      outlineVariant: AppColors.hairline,
      shadow: Color(0x1A000000),
      scrim: Color(0x33000000),
      inverseSurface: AppColors.text,
      onInverseSurface: AppColors.bg,
      inversePrimary: AppColors.accentSoft,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    dividerColor: AppColors.hairline,
    dividerTheme: const DividerThemeData(
      color: AppColors.hairline,
      thickness: 1,
      space: 1,
    ),
  );

  final dmSans = GoogleFonts.dmSansTextTheme(base.textTheme);

  return base.copyWith(
    textTheme: dmSans,
    primaryTextTheme: dmSans,
  );
}
