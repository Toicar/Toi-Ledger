import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/presentation_controller.dart';
import 'package:my_ledger/app/theme_accent.dart';
import 'package:my_ledger/data/entry_templates.dart';
import 'package:my_ledger/domain/operation.dart';
import 'support.dart';
import 'redesign_test.dart' show pumpLedger, closeLedger;
import 'widget_test.dart' show settle;

void main() {
  testWidgets('first entry saves without creating or selecting a category', (
    tester,
  ) async {
    final repo = memoryRepository();
    await pumpLedger(tester, repo, size: const Size(1280, 900));
    await tester.tap(find.text('记一笔'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, '金额（元）'),
      '18.50',
    );
    await tester.tap(find.text('保存'));
    await settle(tester);
    final ops = await tester.runAsync(repo.allOperations);
    expect(ops!.length, 1);
    expect(ops.single.entityType, EntityType.entry);
    expect(ops.single.data['categoryId'], isNull);
    expect(find.text('未分类'), findsWidgets);
    expect(tester.takeException(), isNull);
    await closeLedger(tester, repo);
  });

  testWidgets(
    'template with only name and note saves and leaves amount blank until used',
    (tester) async {
      final repo = memoryRepository();
      await pumpLedger(tester, repo, size: const Size(1280, 900));
      await tester.tap(find.text('快捷模板').first);
      await settle(tester);
      await tester.tap(find.byTooltip('添加模板'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextFormField, '模板名称'), '随手记');
      await tester.enterText(
        find.widgetWithText(TextFormField, '备注（可选）'),
        '日常记录',
      );
      await tester.tap(find.text('保存模板'));
      await settle(tester);
      final saved = await tester.runAsync(
        () => EntryTemplatePreferences(repo.db).read(),
      );
      expect(saved!.single.categoryId, isNull);
      expect(saved.single.amountMinor, isNull);
      expect(await tester.runAsync(repo.allOperations), isEmpty);
      await tester.tap(find.text('使用模板'));
      await settle(tester);
      final amount = find.widgetWithText(TextFormField, '金额（元）');
      expect(tester.widget<TextFormField>(amount).controller!.text, isEmpty);
      await tester.enterText(amount, '25.00');
      await tester.tap(find.text('保存'));
      await settle(tester);
      final ops = await tester.runAsync(repo.allOperations);
      expect(ops!.single.data['categoryId'], isNull);
      expect(ops.single.data['note'], '日常记录');
      expect(ops.single.data['amountMinor'], 2500);
      await closeLedger(tester, repo);
    },
  );

  testWidgets(
    'other opens second-level statistics and reclassification refreshes it',
    (tester) async {
      final repo = memoryRepository();
      final date = DateTime.now().toIso8601String().substring(0, 10);
      await tester.runAsync(() async {
        await category(repo, name: '餐饮');
        for (final (amount, note) in [
          (1000, '小额甲'),
          (2000, '小额乙'),
          (50000, '大额租房'),
        ]) {
          await repo.save(
            type: EntityType.entry,
            data: {
              'kind': 'expense',
              'amountMinor': amount,
              'categoryId': null,
              'date': date,
              'note': note,
            },
          );
        }
      });
      await pumpLedger(tester, repo, size: const Size(1280, 1000));
      await tester.tap(find.text('统计分析').first);
      await settle(tester);
      await tester.ensureVisible(find.text('其他'));
      await settle(tester);
      await tester.tap(find.text('其他'));
      await settle(tester);
      expect(
        find.byKey(const ValueKey('category-statistics-page')),
        findsOneWidget,
      );
      expect(find.text('本期合计'), findsOneWidget);
      expect(find.text('平均每笔'), findsOneWidget);
      expect(find.text('最大单笔'), findsOneWidget);
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, '统计分析')).selected,
        isTrue,
      );
      expect(find.text('大额租房'), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('detail-sort')));
      await tester.tap(find.byKey(const ValueKey('detail-sort')));
      await settle(tester);
      expect(
        tester.getTopLeft(find.text('小额乙')).dy,
        lessThan(tester.getTopLeft(find.text('小额甲')).dy),
      );
      final search = find.widgetWithText(TextField, '搜索明细备注或日期');
      await tester.enterText(search, '小额甲');
      await settle(tester);
      expect(find.text('匹配 1 / 2 笔'), findsOneWidget);
      expect(find.text('小额乙'), findsNothing);
      await tester.enterText(search, '');
      await settle(tester);
      await tester.ensureVisible(find.text('小额甲'));
      await settle(tester);
      await tester.tap(find.text('小额甲'));
      await settle(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await settle(tester);
      await tester.tap(find.text('餐饮').last);
      await settle(tester);
      await tester.tap(find.text('保存'));
      await settle(tester);
      expect(find.text('小额甲'), findsNothing);
      await tester.ensureVisible(find.text('小额乙'));
      await settle(tester);
      expect(find.text('小额乙'), findsOneWidget);
      await tester.tap(find.byTooltip('隐藏金额'));
      await settle(tester);
      expect(find.textContaining('¥'), findsNothing);
      expect(tester.takeException(), isNull);
      await closeLedger(tester, repo);
    },
  );

  testWidgets(
    'changing large threshold regroups other and persists the preference',
    (tester) async {
      final repo = memoryRepository();
      await tester.runAsync(() async {
        await repo.save(
          type: EntityType.entry,
          data: {
            'kind': 'expense',
            'amountMinor': 50000,
            'categoryId': null,
            'date': DateTime.now().toIso8601String().substring(0, 10),
            'note': '边界账单',
          },
        );
      });
      await pumpLedger(tester, repo, size: const Size(1280, 900));
      await tester.tap(find.text('统计分析').first);
      await settle(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('uncategorized-rule')),
      );
      await tester.tap(find.byKey(const ValueKey('uncategorized-rule')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('uncategorized-threshold-input')),
        '1000',
      );
      await tester.tap(find.text('保存规则'));
      await settle(tester);
      expect(
        (await tester.runAsync(
          () => PresentationPreferences(repo.db).read(),
        ))!.uncategorizedThresholdMinor,
        100000,
      );
      await tester.ensureVisible(find.text('其他'));
      expect(find.text('其他'), findsOneWidget);
      expect(find.text('未分类 · 边界账单'), findsNothing);
      expect((await tester.runAsync(repo.allOperations))!.length, 1);
      await closeLedger(tester, repo);
    },
  );

  testWidgets(
    'material previews and Chinese accent selection change the real theme',
    (tester) async {
      final repo = memoryRepository();
      await pumpLedger(tester, repo, size: const Size(1280, 900));
      await tester.tap(find.text('外观'));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('material-glass')));
      await tester.tap(find.byKey(const ValueKey('material-glass')));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('accent-bamboo')));
      await tester.tap(find.byKey(const ValueKey('accent-bamboo')));
      await settle(tester);
      var restored = await tester.runAsync(
        () => PresentationPreferences(repo.db).read(),
      );
      expect(restored!.style, LedgerStyle.glass);
      expect(restored.accent, LedgerAccent.bamboo);
      expect(
        Theme.of(tester.element(find.text('主题色'))).cardTheme.color!.a,
        lessThan(.8),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('material-satin')));
      await tester.tap(find.byKey(const ValueKey('material-satin')));
      await settle(tester);
      restored = await tester.runAsync(
        () => PresentationPreferences(repo.db).read(),
      );
      expect(restored!.style, LedgerStyle.satin);
      expect(restored.accent, LedgerAccent.bamboo);
      expect(Theme.of(tester.element(find.text('界面材质'))).cardTheme.color!.a, 1);
      expect(tester.takeException(), isNull);
      await closeLedger(tester, repo);
    },
  );
}
