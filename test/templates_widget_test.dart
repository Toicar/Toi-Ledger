import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/providers.dart';
import 'package:my_ledger/app/presentation_controller.dart';
import 'package:my_ledger/data/database.dart';
import 'package:my_ledger/data/entry_templates.dart';
import 'package:my_ledger/data/ledger_repository.dart';
import 'package:my_ledger/domain/operation.dart';
import 'package:my_ledger/features/ledger/entry_editor.dart';
import 'package:my_ledger/features/templates/templates_page.dart';
import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pumpAndSettle();
}

Future<void> showTemplates(
  WidgetTester tester,
  LedgerRepository repo, {
  bool hideAmounts = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        initialPresentationProvider.overrideWithValue(
          PresentationSettings(hideAmounts: hideAmounts),
        ),
      ],
      child: const MaterialApp(home: TemplatesPage()),
    ),
  );
  await settle(tester);
}

Future<void> close(WidgetTester tester, LedgerRepository repo) async {
  await tester.pumpWidget(const SizedBox());
  final closing = repo.db.close();
  await tester.pumpAndSettle();
  await closing;
}

EntryTemplate savedTemplate(String categoryId) => EntryTemplate(
  id: uuid.v4(),
  name: '工作日午餐',
  kind: 'expense',
  categoryId: categoryId,
  amountMinor: 1234,
  note: '楼下食堂',
);

void main() {
  testWidgets(
    'hidden amounts mask previews while deliberate editing stays visible',
    (tester) async {
      final repo = memoryRepository();
      await tester.runAsync(() async {
        final cat = await category(repo, name: '餐饮');
        await EntryTemplatePreferences(
          repo.db,
        ).write([savedTemplate(cat.entityId)]);
      });
      await showTemplates(tester, repo, hideAmounts: true);
      expect(find.text('金额已隐藏'), findsOneWidget);
      expect(find.textContaining('12.34'), findsNothing);
      await tester.tap(find.byTooltip('编辑模板'));
      await settle(tester);
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, '金额（元）'))
            .controller!
            .text,
        '12.34',
      );
      await tester.tap(find.text('取消'));
      await settle(tester);
      await tester.tap(find.text('使用模板'));
      await settle(tester);
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, '金额（元）'))
            .controller!
            .text,
        '12.34',
      );
      await tester.tap(find.text('取消'));
      await settle(tester);
      await close(tester, repo);
    },
  );

  testWidgets(
    'corrupt storage shows retry and prevents creating over unread templates',
    (tester) async {
      final repo = memoryRepository();
      await tester.runAsync(() async {
        await repo.db
            .into(repo.db.settings)
            .insert(
              SettingsCompanion.insert(
                key: EntryTemplatePreferences.key,
                value: '{broken',
              ),
            );
      });
      await showTemplates(tester, repo);
      expect(find.text('无法读取快捷模板'), findsOneWidget);
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNull,
      );
      await tester.runAsync(() => EntryTemplatePreferences(repo.db).write([]));
      await tester.tap(find.text('重试'));
      await settle(tester);
      expect(find.text('还没有快捷模板'), findsOneWidget);
      await close(tester, repo);
    },
  );

  testWidgets(
    'failed template write preserves list and form so save can be retried',
    (tester) async {
      final repo = memoryRepository();
      await tester.runAsync(() async {
        final cat = await category(repo, name: '餐饮');
        await EntryTemplatePreferences(
          repo.db,
        ).write([savedTemplate(cat.entityId)]);
      });
      await showTemplates(tester, repo);
      await tester.tap(find.byTooltip('编辑模板'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextFormField, '模板名称'), '新午餐');
      await tester.runAsync(
        () => repo.db.customStatement('PRAGMA query_only = ON'),
      );
      await tester.tap(find.text('保存模板'));
      await settle(tester);
      expect(find.text('操作失败，数据未提交；请重试'), findsOneWidget);
      expect(find.text('编辑快捷模板'), findsOneWidget);
      expect(
        (await tester.runAsync(
          () => EntryTemplatePreferences(repo.db).read(),
        ))!.single.name,
        '工作日午餐',
      );
      await tester.runAsync(
        () => repo.db.customStatement('PRAGMA query_only = OFF'),
      );
      await tester.tap(find.text('保存模板'));
      await settle(tester);
      expect(find.text('编辑快捷模板'), findsNothing);
      expect(find.text('新午餐'), findsOneWidget);
      await close(tester, repo);
    },
  );

  testWidgets('using a template fills today and cancellation writes no entry', (
    tester,
  ) async {
    final repo = memoryRepository();
    late EntryTemplate saved;
    await tester.runAsync(() async {
      saved = savedTemplate((await category(repo, name: '餐饮')).entityId);
      await EntryTemplatePreferences(repo.db).write([saved]);
    });
    await showTemplates(tester, repo);
    await tester.tap(find.text('使用模板'));
    await settle(tester);
    expect(find.byType(EntryEditor), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, '金额（元）'))
          .controller!
          .text,
      '12.34',
    );
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, '备注（可选）'))
          .controller!
          .text,
      '楼下食堂',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, '日期 YYYY-MM-DD'),
          )
          .controller!
          .text,
      DateTime.now().toIso8601String().substring(0, 10),
    );
    expect(find.text('餐饮'), findsWidgets);
    await tester.tap(find.text('取消'));
    await settle(tester);
    expect(
      (await tester.runAsync(
        repo.allOperations,
      ))!.where((op) => op.entityType == EntityType.entry),
      isEmpty,
    );
    await tester.tap(find.text('使用模板'));
    await settle(tester);
    await tester.tap(find.text('保存'));
    await settle(tester);
    final entry = (await tester.runAsync(
      repo.allOperations,
    ))!.where((op) => op.entityType == EntityType.entry).single;
    expect(entry.data, {
      'amountMinor': 1234,
      'kind': 'expense',
      'categoryId': saved.categoryId,
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'note': '楼下食堂',
    });
    expect(find.byType(EntryEditor), findsNothing);
    expect(
      (await tester.runAsync(
        () => EntryTemplatePreferences(repo.db).read(),
      ))!.single.id,
      saved.id,
    );
    await close(tester, repo);
  });

  testWidgets(
    'empty list creates edits and confirms template deletion without entry operations',
    (tester) async {
      final repo = memoryRepository();
      await tester.runAsync(() => category(repo, name: '餐饮'));
      await showTemplates(tester, repo);
      expect(find.text('还没有快捷模板'), findsOneWidget);
      await tester.tap(find.byTooltip('添加模板'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextFormField, '模板名称'), '午餐');
      await tester.enterText(
        find.widgetWithText(TextFormField, '金额（元）'),
        '18.50',
      );
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, '分类（可选）'),
      );
      await settle(tester);
      await tester.tap(find.text('餐饮').last);
      await settle(tester);
      await tester.tap(find.text('保存模板'));
      await settle(tester);
      expect(find.text('午餐'), findsOneWidget);
      await tester.tap(find.byTooltip('编辑模板'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextFormField, '模板名称'), '晚餐');
      await tester.tap(find.text('保存模板'));
      await settle(tester);
      expect(find.text('晚餐'), findsOneWidget);
      await tester.tap(find.byTooltip('删除模板'));
      await settle(tester);
      expect(find.text('删除快捷模板？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await settle(tester);
      expect(find.text('晚餐'), findsOneWidget);
      await tester.tap(find.byTooltip('删除模板'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await settle(tester);
      expect(find.text('还没有快捷模板'), findsOneWidget);
      expect(
        (await tester.runAsync(
          repo.allOperations,
        ))!.where((op) => op.entityType == EntityType.entry),
        isEmpty,
      );
      await close(tester, repo);
    },
  );

  testWidgets(
    'unusable category disables apply while allowing template repair',
    (tester) async {
      final repo = memoryRepository();
      await tester.runAsync(() async {
        final cat = await category(repo, name: '旧餐饮');
        await EntryTemplatePreferences(
          repo.db,
        ).write([savedTemplate(cat.entityId)]);
        await repo.remove(EntityView([cat]));
        await category(repo, name: '新餐饮');
      });
      await showTemplates(tester, repo);
      expect(find.textContaining('分类已归档'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '使用模板'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('编辑模板'));
      await settle(tester);
      expect(find.textContaining('分类已归档'), findsWidgets);
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, '分类（可选）'),
      );
      await settle(tester);
      await tester.tap(find.text('新餐饮').last);
      await settle(tester);
      await tester.tap(find.text('保存模板'));
      await settle(tester);
      expect(find.textContaining('分类已归档'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '使用模板'))
            .onPressed,
        isNotNull,
      );
      await close(tester, repo);
    },
  );

  testWidgets('small screen and large text keep template actions reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = memoryRepository();
    await tester.runAsync(() async {
      final cat = await category(repo, name: '长分类名称' * 8);
      await EntryTemplatePreferences(
        repo.db,
      ).write([savedTemplate(cat.entityId)]);
    });
    await showTemplates(tester, repo);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byTooltip('编辑模板'));
    await settle(tester);
    await tester.tap(find.byTooltip('编辑模板'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('取消'));
    await settle(tester);
    await close(tester, repo);
  });
}
