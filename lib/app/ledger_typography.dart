import 'package:flutter/material.dart';

/// Three font families, resolved once per platform. System fonts add no assets,
/// downloads or startup work. The OS retains responsibility for missing glyphs.
@immutable
class LedgerTypography {
  const LedgerTypography._(
    this.bodyFamily,
    this.chineseBodyFamily,
    this.englishTitleFamily,
    this.chineseTitleFamily,
  );

  static const _windows = LedgerTypography._(
    'Cambria',
    'Microsoft YaHei UI',
    'Cambria',
    'SimSun',
  );
  static const _system = LedgerTypography._(
    'serif',
    'sans-serif',
    'serif',
    'serif',
  );

  static LedgerTypography forPlatform(TargetPlatform platform) =>
      platform == TargetPlatform.windows ? _windows : _system;
  static LedgerTypography of(BuildContext context) =>
      forPlatform(Theme.of(context).platform);

  final String bodyFamily,
      chineseBodyFamily,
      englishTitleFamily,
      chineseTitleFamily;
  List<String> get bodyFallback =>
      bodyFamily == chineseBodyFamily ? const [] : [chineseBodyFamily];
  List<String> get titleFallback => englishTitleFamily == chineseTitleFamily
      ? const []
      : [chineseTitleFamily];

  TextStyle body({
    double size = 14,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: bodyFamily,
    fontFamilyFallback: bodyFallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
  );

  TextStyle title(double size) => TextStyle(
    fontFamily: englishTitleFamily,
    fontFamilyFallback: titleFallback,
    fontSize: size,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -.4,
  );

  /// Money, axes and percentages share the body face and aligned numeral widths.
  TextStyle number({
    double size = 20,
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) => body(
    size: size,
    color: color,
    weight: weight,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()], height: 1.3);
}
