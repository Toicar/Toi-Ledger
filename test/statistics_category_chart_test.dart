import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/domain/ledger_statistics.dart';
import 'package:my_ledger/features/statistics/category_chart.dart';

List<CategoryExpense> categories() => [
  CategoryExpense(
    categoryId: 'Aa',
    label: '餐饮',
    amountMinor: 300,
    share: .75,
    entries: [],
  ),
  CategoryExpense(
    categoryId: 'BB',
    label: '交通',
    amountMinor: 100,
    share: .25,
    entries: [],
  ),
];

void main() {
  test(
    'category colors are deterministic and distinct even for hash collisions',
    () {
      final colors = statisticsCategoryColors(categories());
      expect(colors['Aa'], isNot(colors['BB']));
      expect(statisticsCategoryColors(categories().reversed.toList()), colors);
    },
  );

  testWidgets(
    'all graph geometries hit the category represented by that shape',
    (tester) async {
      CategoryExpense? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryChartPanel(
                categories: categories(),
                income: false,
                onSelected: (category) => selected = category,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final graph = find.byKey(const ValueKey('category-chart'));
      for (final label in ['饼状图', '柱状图', '横向占比条']) {
        await tester.tap(find.byKey(const ValueKey('category-mode-selector')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        final rect = tester.getRect(graph);
        final point = switch (label) {
          '饼状图' => rect.center + const Offset(-25, -25),
          '柱状图' => Offset(rect.left + rect.width * .75, rect.bottom - 40),
          _ => Offset(rect.left + rect.width * .9, rect.center.dy),
        };
        await tester.tapAt(point);
        expect(selected?.label, '交通');
        final painter =
            tester.widget<CustomPaint>(graph).painter! as CategoryPlotPainter;
        final scheme = Theme.of(tester.element(graph)).colorScheme;
        expect(painter.colors['Aa'], scheme.primary);
        expect(painter.colors['BB'], scheme.secondary);
        selected = null;
      }
      expect(find.text('¥3.00'), findsOneWidget);
      expect(find.text('75.0%'), findsOneWidget);
      expect(find.text('¥1.00'), findsOneWidget);
      expect(find.text('25.0%'), findsOneWidget);
    },
  );

  testWidgets(
    'empty categories show a real empty state without chart graphics',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryChartPanel(
              categories: const [],
              income: true,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('本期暂无收入'), findsOneWidget);
      expect(find.byKey(const ValueKey('category-chart')), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
