import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/domain/ledger_statistics.dart';
import 'package:my_ledger/features/statistics/chart_viewport.dart';
import 'package:my_ledger/features/statistics/trend_chart.dart';
import 'statistics_test.dart' as data;

const plotKey = ValueKey('daily-expense-chart');
TrendPlotPainter plotPainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(plotKey)).painter!
        as TrendPlotPainter;
ChartViewport viewport(WidgetTester tester) => plotPainter(tester).viewport;

Future<void> pumpTrend(
  WidgetTester tester, {
  StatisticsPeriod period = StatisticsPeriod.month,
  bool reducedMotion = false,
  int expenseMinor = 12345,
}) async {
  final statistics = LedgerStatistics.forPeriod(
    data.heads([
      data.statisticsEntry(
        data.statisticsCategory().entityId,
        amount: expenseMinor,
        date: '2024-02-29',
      ),
      data.statisticsEntry(
        data.statisticsCategory().entityId,
        amount: 600,
        date: '2024-03-01',
        kind: 'income',
      ),
    ]),
    DateTime(2024, 2),
    period,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: SingleChildScrollView(
            child: Column(
              children: [
                StatisticsTrendChart(
                  statistics: statistics,
                  measure: StatisticsMeasure.both,
                ),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> wheel(
  WidgetTester tester,
  double amount, {
  double fraction = .5,
}) async {
  final rect = tester.getRect(find.byKey(plotKey));
  await tester.sendEventToBinding(
    PointerScrollEvent(
      position: Offset(rect.left + rect.width * fraction, rect.center.dy),
      scrollDelta: Offset(0, amount),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('first trackpad pinch initializes its focal baseline', (
    tester,
  ) async {
    await pumpTrend(tester);
    final before = viewport(tester);
    final trackpad = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    final center = tester.getCenter(find.byKey(plotKey));
    await trackpad.panZoomStart(center);
    await trackpad.panZoomUpdate(center, scale: 1.5);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final after = viewport(tester);
    expect(after.span, closeTo(before.span / 1.5, 1e-8));
    expect(
      after.start + after.span / 2,
      closeTo(before.start + before.span / 2, 1e-8),
    );
    await trackpad.panZoomEnd();
  });

  testWidgets(
    'trackpad after wheel and touch uses the current viewport baseline',
    (tester) async {
      await pumpTrend(tester);
      await wheel(tester, -100);
      await tester.drag(find.byKey(plotKey), const Offset(-40, 0));
      await tester.pump();
      final trackpad = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      for (var gesture = 0; gesture < 2; gesture++) {
        final before = viewport(tester);
        final center = tester.getCenter(find.byKey(plotKey));
        await trackpad.panZoomStart(center);
        await trackpad.panZoomUpdate(center, scale: 1.5);
        await tester.pump();
        expect(tester.takeException(), isNull);
        final after = viewport(tester);
        expect(after.span, closeTo(before.span / 1.5, 1e-8));
        expect(
          after.start + after.span / 2,
          closeTo(before.start + before.span / 2, 1e-8),
        );
        await trackpad.panZoomEnd();
        await wheel(tester, 50);
      }
    },
  );

  testWidgets(
    'data refresh clears stale selected amounts and retains date viewport',
    (tester) async {
      await pumpTrend(tester);
      await wheel(tester, -200);
      final before = viewport(tester);
      await tester.tap(find.byKey(plotKey));
      await tester.pump();
      expect(find.byKey(const ValueKey('trend-detail')), findsOneWidget);
      await pumpTrend(tester, expenseMinor: 67890);
      expect(find.byKey(const ValueKey('trend-detail')), findsNothing);
      expect(viewport(tester).start, before.start);
      expect(viewport(tester).span, before.span);
    },
  );

  testWidgets(
    'cursor wheel zoom anchors its date and shares one monetary scale',
    (tester) async {
      await pumpTrend(tester);
      final old = viewport(tester);
      await wheel(tester, -200, fraction: .75);
      final next = viewport(tester);
      expect(next.span, lessThan(old.span));
      expect(
        next.start + next.span * .75,
        closeTo(old.start + old.span * .75, 1e-8),
      );
      expect(plotPainter(tester).showIncome, isTrue);
      expect(plotPainter(tester).showExpense, isTrue);
      expect(find.text('人民币（元） · 按日汇总'), findsOneWidget);
      expect(find.text('收入'), findsOneWidget);
      expect(find.text('支出'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(Scrollbar), findsNothing);
    },
  );

  testWidgets(
    'touch horizontal drag pans while a vertical drag scrolls the page',
    (tester) async {
      await pumpTrend(tester);
      await wheel(tester, -400);
      final before = viewport(tester);
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      await tester.drag(find.byKey(plotKey), const Offset(-80, 0));
      await tester.pumpAndSettle();
      expect(viewport(tester).start, greaterThan(before.start));
      expect(viewport(tester).span, before.span);
      expect(scroll.pixels, 0);
      await tester.drag(find.byKey(plotKey), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(scroll.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mouse drag pans dates', (tester) async {
    await pumpTrend(tester);
    await wheel(tester, -400);
    final before = viewport(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final center = tester.getCenter(find.byKey(plotKey));
    await mouse.down(center);
    await mouse.moveBy(const Offset(-30, 0));
    await mouse.moveBy(const Offset(-70, 0));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(viewport(tester).start, greaterThan(before.start));
    expect(viewport(tester).span, before.span);
  });

  testWidgets('two fingers continuously pinch and then one finger can pan', (
    tester,
  ) async {
    await pumpTrend(tester);
    final center = tester.getCenter(find.byKey(plotKey));
    final left = await tester.startGesture(
      center - const Offset(45, 0),
      pointer: 1,
    );
    final right = await tester.startGesture(
      center + const Offset(45, 0),
      pointer: 2,
    );
    await left.moveTo(center - const Offset(75, 0));
    await right.moveTo(center + const Offset(75, 0));
    await tester.pump();
    final first = viewport(tester);
    await left.moveTo(center - const Offset(110, 0));
    await right.moveTo(center + const Offset(110, 0));
    await tester.pump();
    final second = viewport(tester);
    expect(first.span, lessThan(29));
    expect(second.span, lessThan(first.span));
    expect(
      second.start + second.span * .5,
      closeTo(first.start + first.span * .5, .01),
    );
    await right.up();
    await left.moveBy(const Offset(-20, 0));
    await left.moveBy(const Offset(-30, 0));
    await tester.pump();
    expect(viewport(tester).start, greaterThanOrEqualTo(second.start));
    expect(viewport(tester).start, greaterThanOrEqualTo(0));
    expect(viewport(tester).end, lessThanOrEqualTo(29));
    await left.up();
    expect(tester.takeException(), isNull);
  });

  testWidgets('year uses natural months then weeks and days as it zooms', (
    tester,
  ) async {
    await pumpTrend(tester, period: StatisticsPeriod.year);
    expect(plotPainter(tester).buckets.length, 12);
    final february = plotPainter(tester).buckets[1];
    expect(february.start, DateTime(2024, 2));
    expect(february.endExclusive, DateTime(2024, 3));
    await wheel(tester, -400);
    expect(find.text('人民币（元） · 按自然周汇总'), findsOneWidget);
    expect(
      plotPainter(
        tester,
      ).buckets.every((b) => b.start.weekday == DateTime.monday),
      isTrue,
    );
    await wheel(tester, -400);
    expect(find.text('人民币（元） · 按日汇总'), findsOneWidget);
    await tester.tap(find.byKey(plotKey));
    await tester.pump();
    expect(find.byKey(const ValueKey('trend-detail')), findsOneWidget);
    expect(find.textContaining('收入 ¥'), findsOneWidget);
  });

  testWidgets(
    'plot semantics keyboard and reduced-motion navigation remain usable',
    (tester) async {
      await pumpTrend(tester, reducedMotion: true);
      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp('收支趋势图，2024-02-01 至 2024-02-29')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();
      expect(viewport(tester).span, lessThan(29));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byKey(const ValueKey('trend-detail')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(viewport(tester).span, 29);
      semantics.dispose();
    },
  );
}
