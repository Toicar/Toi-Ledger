import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/app_theme.dart';
import 'package:my_ledger/app/presentation_controller.dart';
import 'package:my_ledger/app/providers.dart';
import 'package:my_ledger/domain/operation.dart';
import 'package:my_ledger/features/statistics/statistics_page.dart';
import 'statistics_test.dart' as data;
import 'support.dart';

Future<ProviderContainer> pumpStatistics(
  WidgetTester tester,
  List<EntityView> views, {
  DateTime? month,
  bool hidden = false,
  LedgerStyle style = LedgerStyle.satin,
  Brightness brightness = Brightness.light,
}) async {
  final repo = memoryRepository();
  final container = ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      entitiesProvider.overrideWith((ref) => Stream.value(views)),
      initialPresentationProvider.overrideWithValue(
        PresentationSettings(style: style, hideAmounts: hidden),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.runAsync(repo.db.close);
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.resolve(brightness, style),
        home: StatisticsPage(initialMonth: month ?? DateTime(2026, 10)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> revealDetail(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    220,
    scrollable: find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .last,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('trend is before categories with period and measure controls', (
    tester,
  ) async {
    final category = data.statisticsCategory();
    await pumpStatistics(
      tester,
      data.heads([category, data.statisticsEntry(category.entityId)]),
    );
    expect(find.text('周'), findsOneWidget);
    expect(find.text('月'), findsOneWidget);
    expect(find.text('年'), findsOneWidget);
    expect(find.text('对比'), findsOneWidget);
    expect(find.text('收支趋势'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(Scrollbar), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('daily-expense-chart')),
    );
    expect(
      tester.getTopLeft(find.text('收支趋势')).dy,
      lessThan(tester.getTopLeft(find.text('分类支出')).dy),
    );
    await tester.ensureVisible(find.text('周'));
    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final anchor = now.year == 2026 && now.month == 10
        ? now
        : DateTime(2026, 10);
    final monday = DateTime(
      anchor.year,
      anchor.month,
      anchor.day - anchor.weekday + 1,
    );
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    String date(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    expect(find.text('${date(monday)} 至 ${date(sunday)}'), findsWidgets);
    await tester.tap(find.text('年'));
    await tester.pumpAndSettle();
    expect(find.text('2026年'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == '本年收支',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'wheel zoom changes range without changing totals or page scroll',
    (tester) async {
      final category = data.statisticsCategory();
      await pumpStatistics(
        tester,
        data.heads([
          category,
          data.statisticsEntry(category.entityId, amount: 12345, note: '期初支出'),
          data.statisticsEntry(
            category.entityId,
            amount: 500,
            date: '2026-10-31',
            note: '期末支出',
          ),
        ]),
      );
      final plot = find.byKey(const ValueKey('daily-expense-chart'));
      await tester.ensureVisible(plot);
      await tester.pumpAndSettle();
      final before = tester
          .widget<Text>(find.byKey(const ValueKey('trend-range')))
          .data;
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final offset = scroll.pixels;
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(plot),
          scrollDelta: const Offset(0, -250),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('trend-range'))).data,
        isNot(before),
      );
      expect(scroll.pixels, offset);
      await tester.ensureVisible(find.byKey(const ValueKey('period-summary')));
      expect(find.text('¥128.45'), findsWidgets);
      await tester.ensureVisible(find.text('餐饮'));
      await tester.pumpAndSettle();
      expect(find.text('100.0%'), findsOneWidget);
      expect(find.text('2 笔'), findsOneWidget);
      await tester.tap(find.text('餐饮'));
      await tester.pumpAndSettle();
      await revealDetail(tester, find.text('期初支出'));
      expect(find.text('期初支出'), findsOneWidget);
      expect(find.text('期末支出'), findsOneWidget);
    },
  );

  testWidgets(
    'income categories and three graph modes open whole-period real entries',
    (tester) async {
      final category = data.statisticsCategory(name: '工资');
      await pumpStatistics(
        tester,
        data.heads([
          category,
          data.statisticsEntry(
            category.entityId,
            kind: 'income',
            amount: 100,
            note: '月初工资',
          ),
          data.statisticsEntry(
            category.entityId,
            kind: 'income',
            amount: 200,
            date: '2026-10-31',
            note: '月底工资',
          ),
          data.statisticsEntry(category.entityId, note: '支出不应出现'),
        ]),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('measure-income')));
      await tester.tap(find.byKey(const ValueKey('measure-income')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('分类收入'));
      for (final label in ['饼状图', '柱状图', '横向占比条']) {
        final selector = find.byKey(const ValueKey('category-mode-selector'));
        await tester.ensureVisible(selector);
        await tester.tap(selector);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        final graph = find.byKey(const ValueKey('category-chart'));
        await tester.ensureVisible(graph);
        await tester.tapAt(tester.getCenter(graph));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('category-statistics-page')),
          findsOneWidget,
        );
        await revealDetail(tester, find.text('月初工资'));
        expect(find.text('月初工资'), findsOneWidget);
        expect(find.text('月底工资'), findsOneWidget);
        expect(find.text('支出不应出现'), findsNothing);
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('category opens real current-month expense details', (
    tester,
  ) async {
    final category = data.statisticsCategory();
    await pumpStatistics(
      tester,
      data.heads([
        category,
        data.statisticsEntry(category.entityId, amount: 12345, note: '本月午餐'),
        data.statisticsEntry(
          category.entityId,
          amount: 500,
          date: '2026-10-02',
          note: '本月晚餐',
        ),
        data.statisticsEntry(
          category.entityId,
          date: '2026-09-30',
          note: '上月午餐',
        ),
        data.statisticsEntry(category.entityId, kind: 'income', note: '收入记录'),
        data.statisticsEntry(category.entityId, deleted: true, note: '已删记录'),
      ]),
    );

    expect(find.text('¥128.45'), findsWidgets);
    await tester.ensureVisible(find.text('餐饮'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('category-statistics-page')),
      findsOneWidget,
    );
    await revealDetail(tester, find.text('本月午餐'));
    expect(find.text('本月午餐'), findsOneWidget);
    expect(find.text('本月晚餐'), findsOneWidget);
    expect(find.text('¥123.45'), findsWidgets);
    expect(find.text('上月午餐'), findsNothing);
    expect(find.text('收入记录'), findsNothing);
    expect(find.text('已删记录'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'month navigation crosses years and zero denominator has no percent',
    (tester) async {
      final category = data.statisticsCategory();
      await pumpStatistics(
        tester,
        data.heads([
          category,
          data.statisticsEntry(
            category.entityId,
            amount: 200,
            date: '2026-01-01',
          ),
          data.statisticsEntry(
            category.entityId,
            amount: 400,
            date: '2025-12-31',
          ),
        ]),
        month: DateTime(2026, 1),
      );
      expect(find.text('2026年1月'), findsOneWidget);
      await tester.tap(find.byTooltip('上个月'));
      await tester.pumpAndSettle();
      expect(find.text('2025年12月'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('month-comparison')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('与上月对比'));
      await tester.tap(find.text('与上月对比'));
      await tester.pumpAndSettle();
      expect(find.textContaining('上月为零'), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('month-comparison')),
          matching: find.textContaining('%'),
        ),
        findsNothing,
      );
      await tester.ensureVisible(find.byTooltip('下个月'));
      await tester.tap(find.byTooltip('下个月'));
      await tester.pumpAndSettle();
      expect(find.text('2026年1月'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty month does not display an amount chart', (tester) async {
    await pumpStatistics(tester, []);
    expect(find.text('本月暂无账目'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-expense-chart')), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hidden amounts remove numeric amounts percentages and graphics',
    (tester) async {
      final category = data.statisticsCategory();
      await pumpStatistics(
        tester,
        data.heads([
          category,
          data.statisticsEntry(category.entityId, amount: 12345),
        ]),
        hidden: true,
      );
      expect(find.text('金额已隐藏'), findsOneWidget);
      expect(find.text('2026年10月'), findsOneWidget);
      expect(find.textContaining('¥'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.byKey(const ValueKey('daily-expense-chart')), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets('an open detail dialog responds when amounts become hidden', (
    tester,
  ) async {
    final category = data.statisticsCategory();
    final container = await pumpStatistics(
      tester,
      data.heads([
        category,
        data.statisticsEntry(category.entityId, amount: 12345),
      ]),
    );
    await tester.ensureVisible(find.text('餐饮'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    expect(find.text('¥123.45'), findsWidgets);
    await tester.runAsync(
      () => container.read(presentationProvider.notifier).setHideAmounts(true),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('¥'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(find.byKey(const ValueKey('daily-expense-chart')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final style in LedgerStyle.values) {
    for (final brightness in Brightness.values) {
      testWidgets('statistics narrow large text: $style $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final category = data.statisticsCategory(name: '这是一个很长的历史分类名称');
        await pumpStatistics(
          tester,
          data.heads([
            category,
            data.statisticsEntry(category.entityId, amount: maxAmountMinor),
          ]),
          style: style,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        final vertical = find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        );
        await tester.scrollUntilVisible(
          find.text('收支趋势'),
          300,
          scrollable: vertical,
        );
        expect(
          find.byKey(const ValueKey('daily-expense-chart')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('这是一个很长的历史分类名称'),
          300,
          scrollable: vertical,
        );
        await tester.tap(find.text('这是一个很长的历史分类名称'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('category-statistics-page')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
