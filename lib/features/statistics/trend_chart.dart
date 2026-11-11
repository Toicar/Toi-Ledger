import '../../l10n/statistics_labels.dart';
import '../../l10n/app_strings.dart';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/ledger_statistics.dart';
import '../../domain/operation.dart';
import 'chart_viewport.dart';

enum StatisticsMeasure { income, expense, both }

const incomeTrendColor = Color(0xff557563);
const expenseTrendColor = Color(0xffb75b3e);

class StatisticsTrendChart extends StatefulWidget {
  const StatisticsTrendChart({
    super.key,
    required this.statistics,
    required this.measure,
    this.controls,
  });
  final LedgerStatistics statistics;
  final StatisticsMeasure measure;
  final Widget? controls;
  @override
  State<StatisticsTrendChart> createState() => _StatisticsTrendChartState();
}

class _StatisticsTrendChartState extends State<StatisticsTrendChart> {
  late ChartViewport viewport = ChartViewport.full(
    widget.statistics.range.dayCount,
  );
  late ChartViewport gestureStart;
  double initialFocal = .5;
  TrendBucket? selected;
  @override
  void didUpdateWidget(StatisticsTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statistics != widget.statistics) selected = null;
    if (oldWidget.statistics.range.start != widget.statistics.range.start ||
        oldWidget.statistics.range.period != widget.statistics.range.period) {
      viewport = ChartViewport.full(widget.statistics.range.dayCount);
      selected = null;
    }
  }

  void change(ChartViewport next) => setState(() {
    viewport = next;
    selected = null;
  });
  bool get income => widget.measure != StatisticsMeasure.expense;
  bool get expense => widget.measure != StatisticsMeasure.income;
  @override
  Widget build(BuildContext context) {
    final range = widget.statistics.range;
    final unit = range.period == StatisticsPeriod.year && viewport.span > 120
        ? StatisticsBucketUnit.month
        : viewport.span > 35
        ? StatisticsBucketUnit.week
        : StatisticsBucketUnit.day;
    final buckets = widget.statistics
        .trendBuckets(unit)
        .where(
          (b) =>
              civilDaysBetween(range.start, b.endExclusive) > viewport.start &&
              civilDaysBetween(range.start, b.start) < viewport.end,
        )
        .toList();
    final maximum = buckets.fold<int>(
      0,
      (value, b) => math.max(
        value,
        math.max(income ? b.incomeMinor : 0, expense ? b.expenseMinor : 0),
      ),
    );
    final top = _axisMaximum(maximum);
    final first = civilDay(range.start, viewport.start.floor());
    final last = civilDay(
      range.start,
      (viewport.end.ceil() - 1).clamp(0, range.dayCount - 1),
    );
    final rangeText = context.l10n.to(
      statisticsDate(first),
      statisticsDate(last),
    );
    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall!.copyWith(fontSize: 11);
    final incomeColor = Theme.of(context).colorScheme.secondary;
    final expenseColor = Theme.of(context).colorScheme.primary;
    final scaler = MediaQuery.textScalerOf(context);
    String tick(int i) => _axisLabel(top * i ~/ 4, context.l10n);
    final periodTop = _axisMaximum(
      math.max(
        widget.statistics.totals.income,
        widget.statistics.totals.expense,
      ),
    );
    // Keep the plot's coordinate frame stable throughout a pinch, even when
    // visible values change the Y scale or its compact unit.
    final axisWidth =
        [
              for (var i = 0; i <= 4; i++)
                _axisLabel(periodTop * i ~/ 4, context.l10n),
              '9999.99',
              context.l10n.k2,
              context.l10n.m2,
            ]
            .map((label) {
              final painter = TextPainter(
                text: TextSpan(text: label, style: textStyle),
                textDirection: TextDirection.ltr,
                textScaler: scaler,
              )..layout();
              return painter.width;
            })
            .reduce(math.max) +
        8;
    void select(double fraction) {
      final day = viewport.start + fraction.clamp(0.0, 1.0) * viewport.span;
      final bucket = buckets.firstWhere(
        (b) => day < civilDaysBetween(range.start, b.endExclusive),
        orElse: () => buckets.last,
      );
      setState(() => selected = bucket);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              context.l10n.incomeAndExpenseTrend,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            if (widget.controls case final controls?) controls,
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.chineseYuanCny(switch (unit) {
            StatisticsBucketUnit.month => context.l10n.byCalendarMonth,
            StatisticsBucketUnit.week => context.l10n.byCalendarWeek,
            StatisticsBucketUnit.day => context.l10n.byDay,
          }),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: axisWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i <= 4; i++)
                      Positioned(
                        left: 0,
                        right: 8,
                        top: 184 * (1 - i / 4),
                        child: Text(
                          tick(i),
                          style: textStyle,
                          textAlign: TextAlign.right,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return Focus(
                      onKeyEvent: (_, event) {
                        if (event is! KeyDownEvent &&
                            event is! KeyRepeatEvent) {
                          return KeyEventResult.ignored;
                        }
                        final key = event.logicalKey;
                        if (key == LogicalKeyboardKey.arrowLeft) {
                          change(viewport.pan(-viewport.span / 5));
                        } else if (key == LogicalKeyboardKey.arrowRight) {
                          change(viewport.pan(viewport.span / 5));
                        } else if (key == LogicalKeyboardKey.equal ||
                            key == LogicalKeyboardKey.add) {
                          change(viewport.zoom(1.5, .5));
                        } else if (key == LogicalKeyboardKey.minus ||
                            key == LogicalKeyboardKey.numpadSubtract) {
                          change(viewport.zoom(1 / 1.5, .5));
                        } else if (key == LogicalKeyboardKey.home) {
                          change(ChartViewport.full(range.dayCount));
                        } else if (key == LogicalKeyboardKey.enter ||
                            key == LogicalKeyboardKey.space) {
                          select(.5);
                        } else {
                          return KeyEventResult.ignored;
                        }
                        return KeyEventResult.handled;
                      },
                      child: Semantics(
                        label: context.l10n.incomeAndExpenseChart(rangeText),
                        hint: context.l10n.dragToPanPinchOrScroll,
                        onIncrease: () => change(viewport.zoom(1.5, .5)),
                        onDecrease: () => change(viewport.zoom(1 / 1.5, .5)),
                        onTap: () => select(.5),
                        child: Listener(
                          onPointerSignal: (event) {
                            if (event is PointerScrollEvent) {
                              GestureBinding.instance.pointerSignalResolver
                                  .register(event, (resolved) {
                                    if (!mounted) return;
                                    final scroll =
                                        resolved as PointerScrollEvent;
                                    change(
                                      viewport.zoom(
                                        math.exp(
                                          (-scroll.scrollDelta.dy / 300).clamp(
                                            -4.0,
                                            4.0,
                                          ),
                                        ),
                                        scroll.localPosition.dx / width,
                                      ),
                                    );
                                  });
                            }
                          },
                          child: RawGestureDetector(
                            behavior: HitTestBehavior.opaque,
                            gestures: {
                              _ChartScaleRecognizer:
                                  GestureRecognizerFactoryWithHandlers<
                                    _ChartScaleRecognizer
                                  >(_ChartScaleRecognizer.new, (recognizer) {
                                    recognizer.onConfiguration = (focalPoint) {
                                      gestureStart = viewport;
                                      initialFocal = focalPoint.dx / width;
                                    };
                                    recognizer.onUpdate = (details) => change(
                                      gestureStart.transform(
                                        scale: details.scale,
                                        initialFocal: initialFocal,
                                        currentFocal:
                                            details.localFocalPoint.dx / width,
                                      ),
                                    );
                                  }),
                              TapGestureRecognizer:
                                  GestureRecognizerFactoryWithHandlers<
                                    TapGestureRecognizer
                                  >(
                                    TapGestureRecognizer.new,
                                    (r) => r.onTapUp = (details) => select(
                                      details.localPosition.dx / width,
                                    ),
                                  ),
                              LongPressGestureRecognizer:
                                  GestureRecognizerFactoryWithHandlers<
                                    LongPressGestureRecognizer
                                  >(
                                    LongPressGestureRecognizer.new,
                                    (r) => r.onLongPressStart = (details) =>
                                        select(
                                          details.localPosition.dx / width,
                                        ),
                                  ),
                            },
                            child: CustomPaint(
                              key: const ValueKey('daily-expense-chart'),
                              painter: TrendPlotPainter(
                                buckets: buckets,
                                range: range,
                                viewport: viewport,
                                maximum: top,
                                showIncome: income,
                                showExpense: expense,
                                incomeColor: incomeColor,
                                expenseColor: expenseColor,
                                gridColor: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: axisWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth >= 200 * scaler.scale(1)
                  ? 4
                  : 2;
              return Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: Text(
                        () {
                          final date = civilDay(
                            range.start,
                            (viewport.start + viewport.span * i / (count - 1))
                                .floor()
                                .clamp(0, range.dayCount - 1),
                          );
                          return '${date.month}/${date.day}';
                        }(),
                        style: textStyle,
                        textAlign: i == 0
                            ? TextAlign.left
                            : i == count - 1
                            ? TextAlign.right
                            : TextAlign.center,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            if (expense) _TrendLegend(context.l10n.expense, expenseColor),
            if (income) _TrendLegend(context.l10n.income, incomeColor),
          ],
        ),
        const SizedBox(height: 4),
        Text(rangeText, key: const ValueKey('trend-range'), style: textStyle),
        if (selected case final bucket?) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              '${bucketLabel(context, bucket)}${income ? context.l10n.incomeAmountLine(formatAmount(bucket.incomeMinor)) : ''}${expense ? context.l10n.expenseAmountLine(formatAmount(bucket.expenseMinor)) : ''}',
              key: const ValueKey('trend-detail'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

int _axisMaximum(int amount) {
  if (amount <= 0) return 100;
  final power = math.pow(10, (math.log(amount) / math.ln10).floor()).toInt();
  for (final step in [1, 2, 5, 10]) {
    if (power * step >= amount) return ((power * step + 3) ~/ 4) * 4;
  }
  return amount;
}

String _axisLabel(
  int minor, [
  AppStrings strings = const AppStrings(Locale('zh', 'CN')),
]) {
  if (minor >= 10000000000) {
    return strings.m3((minor / 10000000000).toStringAsFixed(1));
  }
  if (minor >= 1000000) return strings.k3((minor / 1000000).toStringAsFixed(1));
  return formatAmount(minor);
}

class TrendPlotPainter extends CustomPainter {
  const TrendPlotPainter({
    required this.buckets,
    required this.range,
    required this.viewport,
    required this.maximum,
    required this.showIncome,
    required this.showExpense,
    required this.gridColor,
    this.incomeColor = incomeTrendColor,
    this.expenseColor = expenseTrendColor,
  });
  final List<TrendBucket> buckets;
  final StatisticsRange range;
  final ChartViewport viewport;
  final int maximum;
  final bool showIncome, showExpense;
  final Color gridColor;
  final Color incomeColor, expenseColor;
  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height - 16;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      canvas.drawLine(
        Offset(0, height * i / 4),
        Offset(size.width, height * i / 4),
        grid,
      );
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, height + 2));
    final series = [if (showExpense) false, if (showIncome) true];
    for (final bucket in buckets) {
      final start = civilDaysBetween(range.start, bucket.start);
      final end = civilDaysBetween(range.start, bucket.endExclusive);
      final center =
          ((start + end) / 2 - viewport.start) / viewport.span * size.width;
      final slot = (end - start) / viewport.span * size.width;
      final width = math.min(24.0, slot * .68 / series.length);
      for (var i = 0; i < series.length; i++) {
        final isIncome = series[i];
        final amount = isIncome ? bucket.incomeMinor : bucket.expenseMinor;
        if (amount == 0) continue;
        final barHeight = height * amount / maximum;
        final rect = Rect.fromLTWH(
          center + (i - (series.length - 1) / 2) * (width + 2) - width / 2,
          height - barHeight,
          width,
          barHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
          ),
          Paint()..color = isIncome ? incomeColor : expenseColor,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(TrendPlotPainter oldDelegate) => true;
}

/// A single vertical finger belongs to the page; horizontal drags and pinches
/// belong to the plot. The gesture arena still handles taps and long presses.
class _ChartScaleRecognizer extends ScaleGestureRecognizer {
  _ChartScaleRecognizer() : super(dragStartBehavior: DragStartBehavior.down);
  final origins = <int, Offset>{}, positions = <int, Offset>{};
  ValueChanged<Offset>? onConfiguration;
  bool accepted = false;
  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerPanZoomStartEvent) {
      onConfiguration?.call(event.localPosition);
    }
    if (event is PointerDownEvent) {
      origins[event.pointer] = event.position;
      positions[event.pointer] = event.position;
    }
    if (event is PointerMoveEvent) positions[event.pointer] = event.position;
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      origins.remove(event.pointer);
      positions.remove(event.pointer);
    }
    if ((event is PointerDownEvent ||
            event is PointerUpEvent ||
            event is PointerCancelEvent) &&
        positions.isNotEmpty) {
      final focal =
          positions.values.reduce((a, b) => a + b) /
          positions.length.toDouble();
      onConfiguration?.call(
        PointerEvent.transformPosition(event.transform, focal),
      );
    }
    super.handleEvent(event);
  }

  @override
  void resolve(GestureDisposition disposition) {
    if (disposition == GestureDisposition.accepted &&
        !accepted &&
        positions.length == 1) {
      final id = positions.keys.single;
      final delta = positions[id]! - origins[id]!;
      if (delta.dy.abs() > delta.dx.abs()) {
        super.resolve(GestureDisposition.rejected);
        return;
      }
    }
    super.resolve(disposition);
  }

  @override
  void acceptGesture(int pointer) {
    accepted = true;
    super.acceptGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    accepted = false;
    origins.clear();
    positions.clear();
  }
}
