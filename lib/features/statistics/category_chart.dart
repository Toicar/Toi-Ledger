import '../../l10n/statistics_labels.dart';
import '../../l10n/app_strings.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/ledger_statistics.dart';
import '../../app/ledger_typography.dart';
import 'statistics_controls.dart';

enum CategoryChartMode { pie, column, proportion }

Map<String, Color> statisticsCategoryColors(
  List<CategoryExpense> categories, {
  bool dark = false,
  Color? primary,
  Color? secondary,
}) {
  final ids = categories.map((c) => c.categoryId).toSet().toList()..sort();
  const light = [
    Color(0xffb75b3e),
    Color(0xff557563),
    Color(0xffb69c67),
    Color(0xff8d817b),
    Color(0xff7e8b99),
  ];
  const night = [
    Color(0xffe3a085),
    Color(0xffa4c1a8),
    Color(0xffd9c290),
    Color(0xffbca9a0),
    Color(0xffa2b3c4),
  ];
  return Map.unmodifiable({
    for (var i = 0; i < ids.length; i++)
      ids[i]: i == 0 && primary != null
          ? primary
          : i == 1 && secondary != null
          ? secondary
          : i < light.length
          ? (dark ? night[i] : light[i])
          : HSLColor.fromAHSL(
              1,
              (i * 137.507764) % 360,
              .55,
              dark ? .68 : .47,
            ).toColor(),
  });
}

class CategoryChartPanel extends StatefulWidget {
  const CategoryChartPanel({
    super.key,
    required this.categories,
    required this.income,
    required this.onSelected,
  });
  final List<CategoryExpense> categories;
  final bool income;
  final ValueChanged<CategoryExpense> onSelected;
  @override
  State<CategoryChartPanel> createState() => _CategoryChartPanelState();
}

class _CategoryChartPanelState extends State<CategoryChartPanel> {
  CategoryChartMode mode = CategoryChartMode.pie;
  @override
  Widget build(BuildContext context) {
    final categories = widget.categories;
    final colors = statisticsCategoryColors(
      categories,
      dark: Theme.of(context).brightness == Brightness.dark,
      primary: Theme.of(context).colorScheme.primary,
      secondary: Theme.of(context).colorScheme.secondary,
    );
    final total = categories.fold<int>(0, (sum, c) => sum + c.amountMinor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.income
                      ? context.l10n.incomeByCategory
                      : context.l10n.expensesByCategory,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.selectACategoryOrTransactionFor,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (total > 0)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CategoryChartMode>(
                      key: const ValueKey('category-mode-selector'),
                      value: mode,
                      style: LedgerTypography.of(context).body(
                        size: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        for (final value in CategoryChartMode.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(switch (value) {
                              CategoryChartMode.pie => context.l10n.pieChart,
                              CategoryChartMode.column =>
                                context.l10n.columnChart,
                              CategoryChartMode.proportion =>
                                context.l10n.shareBars,
                            }),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => mode = value);
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (total == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              widget.income
                  ? context.l10n.noIncomeInThisPeriod
                  : context.l10n.noExpensesInThisPeriod,
            ),
          )
        else ...[
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                constraints.maxWidth,
                mode == CategoryChartMode.proportion ? 80 : 220,
              );
              final painter = CategoryPlotPainter(
                strings: context.l10n,
                displayLabel: (category) => groupLabel(context, category),
                categories: categories,
                mode: mode,
                colors: colors,
                outline: Theme.of(context).colorScheme.surface,
                textColor: Theme.of(context).colorScheme.onSurface,
                textScaler: MediaQuery.textScalerOf(context),
                labelStyle: LedgerTypography.of(context).body(size: 11),
              );
              return Semantics(
                label: context.l10n.categoriesTheListProvidesAmountsShares(
                  switch (mode) {
                    CategoryChartMode.pie => context.l10n.categoryPieChart,
                    CategoryChartMode.column =>
                      context.l10n.categoryColumnChart,
                    CategoryChartMode.proportion =>
                      context.l10n.categoryShareChart,
                  },
                  categories.length,
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final index = painter.categoryAt(
                      details.localPosition,
                      size,
                    );
                    if (index != null) widget.onSelected(categories[index]);
                  },
                  child: CustomPaint(
                    key: const ValueKey('category-chart'),
                    painter: painter,
                    size: size,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < categories.length; index++)
            InkWell(
              key: ValueKey('category-entry-${categories[index].categoryId}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => widget.onSelected(categories[index]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final category = categories[index];
                    final muted = Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant;
                    final value = statisticsMoney(category.amountMinor);
                    final percent =
                        '${(category.share * 100).toStringAsFixed(1)}%';
                    final style = LedgerTypography.of(
                      context,
                    ).body(size: 14, weight: FontWeight.w500);
                    final measure = TextPainter(
                      text: TextSpan(text: '$value  $percent', style: style),
                      textDirection: TextDirection.ltr,
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout();
                    final label = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(top: 5, right: 8),
                          decoration: BoxDecoration(
                            color: colors[category.categoryId],
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                groupLabel(context, category),
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                category.groupKind == StatisticsGroupKind.other
                                    ? context.l10n.smallUncategorizedEntries(
                                        category.entries.length,
                                      )
                                    : context.l10n.entries(
                                        category.entries.length,
                                      ),
                                style: TextStyle(fontSize: 11, color: muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                    if (measure.width > constraints.maxWidth * .62) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          label,
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 12,
                            children: [
                              Text(value, style: style),
                              Text(
                                percent,
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: label),
                        const SizedBox(width: 8),
                        Text(value, style: style),
                        const SizedBox(width: 12),
                        Text(
                          percent,
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class CategoryPlotPainter extends CustomPainter {
  const CategoryPlotPainter({
    required this.categories,
    required this.mode,
    required this.colors,
    required this.outline,
    required this.textColor,
    required this.textScaler,
    this.labelStyle = const TextStyle(fontSize: 11),
    this.strings = const AppStrings(Locale('zh', 'CN')),
    this.displayLabel,
  });
  final List<CategoryExpense> categories;
  final CategoryChartMode mode;
  final Map<String, Color> colors;
  final Color outline, textColor;
  final TextScaler textScaler;
  final TextStyle labelStyle;
  int get total => categories.fold<int>(0, (sum, c) => sum + c.amountMinor);
  Rect _pieRect(Size size) => Rect.fromCircle(
    center: size.center(Offset.zero),
    radius: math.min(size.width * .31, size.height * .38),
  );
  Rect _barRect(int index, Size size) {
    final maximum = categories.fold<int>(
      0,
      (sum, c) => math.max(sum, c.amountMinor),
    );
    final left = _axisWidth(size);
    final cell = (size.width - left - 6) / categories.length;
    final height = (size.height - 42) * categories[index].amountMinor / maximum;
    return Rect.fromLTWH(
      left + cell * index + cell * .15,
      size.height - 28 - height,
      cell * .7,
      height,
    );
  }

  final AppStrings strings;
  final String Function(CategoryExpense)? displayLabel;
  String _axisLabel(int minor) => minor >= 10000000000
      ? strings.m((minor / 10000000000).toStringAsFixed(1))
      : minor >= 1000000
      ? strings.k((minor / 1000000).toStringAsFixed(1))
      : '¥${(minor / 100).toStringAsFixed(minor % 100 == 0 ? 0 : 2)}';
  double _axisWidth(Size size) {
    final maximum = categories.fold<int>(
      0,
      (sum, c) => math.max(sum, c.amountMinor),
    );
    final label = TextPainter(
      text: TextSpan(text: _axisLabel(maximum), style: labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    return math.min(size.width * .4, label.width + 8);
  }

  int? categoryAt(Offset point, Size size) {
    if (total <= 0 || !(Offset.zero & size).contains(point)) return null;
    if (mode == CategoryChartMode.pie) {
      final rect = _pieRect(size);
      final delta = point - rect.center;
      if (delta.distance > rect.width / 2) return null;
      final fraction =
          ((math.atan2(delta.dy, delta.dx) + math.pi / 2) % (2 * math.pi)) /
          (2 * math.pi);
      var sum = 0.0;
      for (var i = 0; i < categories.length; i++) {
        sum += categories[i].amountMinor / total;
        if (fraction < sum || i == categories.length - 1) return i;
      }
    } else if (mode == CategoryChartMode.column) {
      for (var i = 0; i < categories.length; i++) {
        if (_barRect(i, size).contains(point)) return i;
      }
    } else {
      var sum = 0.0;
      for (var i = 0; i < categories.length; i++) {
        sum += categories[i].amountMinor / total;
        if (point.dx / size.width < sum || i == categories.length - 1) return i;
      }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    if (mode == CategoryChartMode.column) {
      final left = _axisWidth(size);
      final maximum = categories.fold<int>(
        0,
        (sum, c) => math.max(sum, c.amountMinor),
      );
      for (var i = 0; i <= 2; i++) {
        final y = size.height - 28 - (size.height - 42) * i / 2;
        canvas.drawLine(
          Offset(left, y),
          Offset(size.width, y),
          Paint()..color = textColor.withValues(alpha: .12),
        );
        final text = TextPainter(
          text: TextSpan(
            text: _axisLabel(maximum * i ~/ 2),
            style: labelStyle.copyWith(color: textColor),
          ),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout();
        text.paint(
          canvas,
          Offset(math.max(0, left - text.width - 6), y - text.height / 2),
        );
      }
    }
    var offset = 0.0;
    for (var i = 0; i < categories.length; i++) {
      final share = categories[i].amountMinor / total;
      final paint = Paint()..color = colors[categories[i].categoryId]!;
      if (mode == CategoryChartMode.pie) {
        canvas.drawArc(
          _pieRect(size),
          -math.pi / 2 + offset * 2 * math.pi,
          share * 2 * math.pi,
          true,
          paint,
        );
        if (share >= .07) {
          final rect = _pieRect(size),
              angle = -math.pi / 2 + (offset + share / 2) * 2 * math.pi;
          final label = TextPainter(
            text: TextSpan(
              text: '${(share * 100).toStringAsFixed(0)}%',
              style: labelStyle.copyWith(color: textColor),
            ),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
          )..layout();
          final center =
              rect.center +
              Offset(math.cos(angle), math.sin(angle)) * (rect.width / 2 + 17);
          label.paint(
            canvas,
            Offset(
              (center.dx - label.width / 2).clamp(
                0,
                math.max(0, size.width - label.width),
              ),
              (center.dy - label.height / 2).clamp(
                0,
                math.max(0, size.height - label.height),
              ),
            ),
          );
        }
        canvas.drawArc(
          _pieRect(size),
          -math.pi / 2 + offset * 2 * math.pi,
          share * 2 * math.pi,
          true,
          Paint()
            ..color = outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      } else if (mode == CategoryChartMode.column) {
        final rect = _barRect(i, size);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          paint,
        );
        final label =
            TextPainter(
              text: TextSpan(
                text: displayLabel?.call(categories[i]) ?? categories[i].label,
                style: labelStyle.copyWith(color: textColor),
              ),
              textDirection: TextDirection.ltr,
              textScaler: textScaler,
              maxLines: 1,
              ellipsis: '…',
            )..layout(
              maxWidth: (size.width - _axisWidth(size) - 6) / categories.length,
            );
        label.paint(
          canvas,
          Offset(rect.center.dx - label.width / 2, size.height - 24),
        );
      } else {
        final rect = Rect.fromLTWH(
          offset * size.width,
          0,
          share * size.width,
          size.height,
        );
        canvas.drawRect(rect, paint);
        canvas.drawRect(
          rect,
          Paint()
            ..color = outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
      offset += share;
    }
  }

  @override
  bool shouldRepaint(CategoryPlotPainter oldDelegate) => true;
}
