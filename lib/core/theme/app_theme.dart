import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static const List<ThemeColorOption> colorOptions = [
    ThemeColorOption(name: '珊瑚', seed: AppColors.coral),
    ThemeColorOption(name: '薰衣草', seed: AppColors.lavender),
    ThemeColorOption(name: '薄荷', seed: AppColors.mint),
    ThemeColorOption(name: '奶油黄', seed: AppColors.butter),
    ThemeColorOption(name: '天空蓝', seed: AppColors.sky),
    ThemeColorOption(name: '杏桃', seed: AppColors.apricot),
  ];

  static ThemeData fromSeedColor(
    Color seedColor, {
    required Brightness brightness,
  }) {
    final dark = brightness == Brightness.dark;
    final surface = dark
        ? Color.lerp(seedColor, AppColors.darkSurface, .92)!
        : Color.lerp(seedColor, AppColors.warmWhite, .91)!;
    final background = dark
        ? Color.lerp(seedColor, AppColors.darkBackground, .89)!
        : Color.lerp(seedColor, AppColors.cream, .88)!;
    final onSurface = dark ? AppColors.darkInk : AppColors.ink;
    final muted = dark ? AppColors.darkMutedInk : AppColors.mutedInk;
    final container = dark
        ? AppColors.darkSurfaceHigh
        : Color.lerp(seedColor, AppColors.warmWhite, .84)!;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: seedColor,
      onPrimary: dark ? AppColors.ink : Colors.white,
      primaryContainer: container,
      onPrimaryContainer: onSurface,
      secondary: AppColors.lavender,
      onSecondary: AppColors.ink,
      secondaryContainer:
          dark ? AppColors.darkSurfaceHigh : AppColors.tint(AppColors.lavender),
      onSecondaryContainer: onSurface,
      tertiary: AppColors.mint,
      onTertiary: AppColors.ink,
      tertiaryContainer:
          dark ? AppColors.darkSurfaceHigh : AppColors.tint(AppColors.mint),
      onTertiaryContainer: onSurface,
      error: AppColors.softError,
      onError: Colors.white,
      errorContainer: dark
          ? const Color(0xFF5E3731)
          : AppColors.tint(AppColors.coral, amount: .72),
      onErrorContainer: onSurface,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: dark
          ? Color.lerp(seedColor, AppColors.darkSurfaceHigh, .88)!
          : Color.lerp(seedColor, AppColors.divider, .84)!,
      onSurfaceVariant: muted,
      outline: muted.withValues(alpha: .42),
      outlineVariant: dark
          ? Color.lerp(seedColor, AppColors.darkMutedInk, .86)!
              .withValues(alpha: .28)
          : Color.lerp(seedColor, AppColors.divider, .82)!,
      shadow: const Color(0xFF6E554B),
      scrim: Colors.black,
      inverseSurface: onSurface,
      onInverseSurface: surface,
      inversePrimary: seedColor,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: scheme.outlineVariant,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          color: onSurface,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          color: onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(color: onSurface),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: onSurface),
        bodySmall: base.textTheme.bodySmall?.copyWith(color: muted),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: muted.withValues(alpha: .82)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder:
            _inputBorder(seedColor.withValues(alpha: .72), width: 1.5),
        errorBorder: _inputBorder(AppColors.softError),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: muted.withValues(alpha: .3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLarge),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        ),
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: onSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seedColor,
        foregroundColor: dark ? AppColors.ink : Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seedColor,
          foregroundColor: dark ? AppColors.ink : Colors.white,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: scheme.outlineVariant),
          shape: const StadiumBorder(),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: container,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark
            ? Color.lerp(seedColor, AppColors.darkSurfaceHigh, .72)
            : container,
        contentTextStyle: TextStyle(
          color: onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: seedColor,
        behavior: SnackBarBehavior.floating,
        width: 306,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: seedColor),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
        borderSide: BorderSide(color: color, width: width),
      );
}

class ThemeColorOption {
  final String name;
  final Color seed;
  const ThemeColorOption({required this.name, required this.seed});
}
