import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'statistics_test.dart' as data;
import 'statistics_widget_test.dart' show pumpStatistics;

void main() {
  testWidgets(
    'phone statistics follows the approved compact trend-first layout',
    (tester) async {
      tester.view.physicalSize = const Size(360, 796);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final category = data.statisticsCategory();
      await pumpStatistics(
        tester,
        data.heads([
          category,
          data.statisticsEntry(category.entityId, amount: 12345),
        ]),
      );
      final summary = find.byKey(const ValueKey('period-summary'));
      final income = find.descendant(of: summary, matching: find.text('收入'));
      final expense = find.descendant(of: summary, matching: find.text('支出'));
      final balance = find.descendant(of: summary, matching: find.text('结余'));
      expect(
        tester.getTopLeft(income).dy,
        closeTo(tester.getTopLeft(expense).dy, 1),
      );
      expect(
        tester.getTopLeft(balance).dy,
        greaterThan(tester.getTopLeft(income).dy),
      );
      final balanceAmount = find.descendant(
        of: summary,
        matching: find.text('¥-123.45'),
      );
      expect(
        tester.getRect(summary).right - tester.getRect(balanceAmount).right,
        closeTo(12, 1),
      );
      expect(tester.getTopLeft(find.text('收支趋势')).dy, lessThan(420));
      expect(
        tester
            .getBottomRight(find.byKey(const ValueKey('daily-expense-chart')))
            .dy,
        lessThan(760),
      );
      expect(find.text('对比'), findsOneWidget);
      expect(find.byTooltip('隐藏金额'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.text('向前查看'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
