import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'presentation_controller.dart';
import 'ledger_typography.dart';
import 'theme_accent.dart';

abstract final class LedgerColors {
  static const clay = Color(0xffb75b3e);
  static const sage = Color(0xff557563);
  static const paper = Color(0xfffaf8f3);
  static const ink = Color(0xff30302b);
  static const darkPaper = Color(0xff20211e);
  static const line = Color(0xffe4e0d7);
}

abstract final class AppTheme {
  static final _themes =
      <(Brightness, LedgerStyle, TargetPlatform, LedgerAccent), ThemeData>{};
  static ThemeData get light => resolve(Brightness.light, LedgerStyle.satin);
  static ThemeData get dark => resolve(Brightness.dark, LedgerStyle.satin);
  static ThemeData resolve(
    Brightness brightness,
    LedgerStyle style, {
    TargetPlatform? platform,
    LedgerAccent accent = LedgerAccent.clay,
  }) {
    final target = platform ?? defaultTargetPlatform;
    return _themes.putIfAbsent(
      (brightness, style, target, accent),
      () => _build(
        brightness,
        glass: style == LedgerStyle.glass,
        platform: target,
        accent: accent,
      ),
    );
  }

  static ThemeData _build(
    Brightness brightness, {
    bool glass = false,
    required TargetPlatform platform,
    required LedgerAccent accent,
  }) {
    final dark = brightness == Brightness.dark;
    final legacy = accent == LedgerAccent.clay;
    final surface = Color.alphaBlend(
      accent.seed.withValues(alpha: legacy ? 0 : .035),
      dark ? const Color(0xff292a26) : const Color(0xfffffefa),
    );
    final background = Color.alphaBlend(
      accent.seed.withValues(alpha: .03),
      dark ? LedgerColors.darkPaper : LedgerColors.paper,
    );
    final tones = ColorScheme.fromSeed(
      seedColor: accent.seed,
      brightness: brightness,
      surface: surface,
    );
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent.seed,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: legacy
              ? (dark ? const Color(0xffe3a085) : LedgerColors.clay)
              : tones.primary,
          onPrimary: legacy
              ? (dark ? const Color(0xff382318) : Colors.white)
              : tones.onPrimary,
          primaryContainer: !legacy
              ? tones.primaryContainer
              : dark
              ? const Color(0xff49352b)
              : const Color(0xfff1e2d8),
          onPrimaryContainer: !legacy
              ? tones.onPrimaryContainer
              : dark
              ? const Color(0xfff3c6b2)
              : const Color(0xff793d29),
          secondary: legacy
              ? (dark ? const Color(0xffa4c1a8) : LedgerColors.sage)
              : tones.secondary,
          onSurface: dark ? const Color(0xffeeeae1) : LedgerColors.ink,
          onSurfaceVariant: dark
              ? const Color(0xffb1b1a6)
              : const Color(0xff77776b),
          outline: dark ? const Color(0xff6c6d62) : const Color(0xffb5b2a7),
          outlineVariant: dark ? const Color(0xff42443b) : LedgerColors.line,
          surfaceContainerHighest: !legacy
              ? tones.surfaceContainerHighest
              : dark
              ? const Color(0xff363830)
              : const Color(0xffeeece4),
          surfaceContainerLow: glass
              ? Color.alphaBlend(
                  accent.seed.withValues(alpha: .04),
                  surface,
                ).withValues(alpha: .52)
              : !legacy
              ? tones.surfaceContainerLow
              : dark
              ? const Color(0xff252621)
              : const Color(0xfff4f1e9),
        );
    final typography = LedgerTypography.forPlatform(platform);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      platform: platform,
      fontFamily: typography.bodyFamily,
      fontFamilyFallback: typography.bodyFallback,
    );
    TextStyle? editorial(TextStyle? style, double size) =>
        style?.merge(typography.title(size));
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: scheme.outlineVariant, width: .8),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: base.textTheme.copyWith(
        headlineLarge: editorial(base.textTheme.headlineLarge, 36),
        headlineMedium: editorial(base.textTheme.headlineMedium, 30),
        headlineSmall: editorial(base.textTheme.headlineSmall, 26),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.6),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.6),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.6,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: glass ? surface.withValues(alpha: .50) : background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 24,
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 21),
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: glass ? surface.withValues(alpha: .56) : surface,
        elevation: glass ? 0 : 1,
        shadowColor: scheme.onSurface.withValues(alpha: .05),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: shape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: typography.body(size: 14, color: scheme.onSurfaceVariant),
        hintStyle: typography.body(size: 14, color: scheme.onSurfaceVariant),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          textStyle: typography.body(size: 14, weight: FontWeight.w500),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          textStyle: typography.body(size: 14, weight: FontWeight.w500),
          minimumSize: const Size(48, 44),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        highlightElevation: 5,
        extendedTextStyle: typography.body(size: 15, weight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: scheme.outlineVariant),
        selectedColor: scheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: .8,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        iconColor: scheme.onSurfaceVariant,
        selectedColor: scheme.primary,
        selectedTileColor: scheme.primaryContainer.withValues(alpha: .6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xffe8e2d6) : LedgerColors.ink,
        contentTextStyle: typography.body(
          color: dark ? LedgerColors.ink : LedgerColors.paper,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
