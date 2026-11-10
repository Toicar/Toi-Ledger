import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/appearance_controller.dart';
import 'package:my_ledger/app/ledger_app.dart';
import 'package:my_ledger/app/providers.dart';
import 'package:my_ledger/data/ledger_repository.dart';
import 'package:my_ledger/domain/operation.dart';
import 'support.dart';
import 'widget_test.dart' show EmptyCredentials, settle;

Future<void> pumpLedger(
  WidgetTester tester,
  LedgerRepository repo, {
  Size size = const Size(1280, 900),
  ThemeMode mode = ThemeMode.light,
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        credentialProvider.overrideWithValue(EmptyCredentials()),
        initialThemeModeProvider.overrideWithValue(mode),
      ],
      child: const LedgerApp(),
    ),
  );
  await settle(tester);
}

Future<void> closeLedger(WidgetTester tester, LedgerRepository repo) async {
  await tester.pumpWidget(const SizedBox());
  final closing = repo.db.close();
  await tester.pumpAndSettle();
  await closing;
}

void main() {
  testWidgets(
    'desktop sidebar navigates and global create saves a real entry',
    (tester) async {
      final repo = memoryRepository();
      await tester.runAsync(() => category(repo, name: '午餐'));
      await pumpLedger(tester, repo);
      await tester.tap(find.text('快捷模板'));
      await settle(tester);
      expect(find.text('还没有快捷模板'), findsOneWidget);
      await tester.tap(find.text('记一笔'));
      await settle(tester);
      final navigation = find.widgetWithText(ListTile, '分类管理');
      expect(tester.widget<ListTile>(navigation).enabled, isFalse);
      await tester.enterText(
        find.widgetWithText(TextFormField, '金额（元）'),
        '28.50',
      );
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, '分类（可选）'),
      );
      await settle(tester);
      await tester.tap(find.text('午餐').last);
      await settle(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      final views = (await tester.runAsync(repo.snapshot))!;
      expect(
        views
            .where((v) => v.current.entityType == EntityType.entry)
            .single
            .current
            .data['amountMinor'],
        2850,
      );
      await tester.tap(find.text('我的账本'));
      await settle(tester);
      expect(find.text('¥28.50'), findsOneWidget);
      await tester.tap(find.text('分类管理'));
      await settle(tester);
      await tester.tap(find.text('同步设置'));
      await settle(tester);
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, '同步设置')).selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await closeLedger(tester, repo);
    },
  );

  testWidgets('search distinguishes no matches and reset restores the ledger', (
    tester,
  ) async {
    final repo = memoryRepository();
    await tester.runAsync(() async {
      final cat = await category(repo, name: '餐饮');
      await entry(
        repo,
        cat,
        date: DateTime.now().toIso8601String().substring(0, 10),
      );
    });
    await pumpLedger(tester, repo, size: const Size(420, 900));
    await tester.enterText(find.byType(TextField).first, '不存在的备注');
    await settle(tester);
    expect(find.text('还没有找到这笔记录'), findsOneWidget);
    await tester.ensureVisible(find.text('清除筛选'));
    await settle(tester);
    await tester.tap(find.text('清除筛选'));
    await settle(tester);
    expect(find.text('还没有找到这笔记录'), findsNothing);
    expect(find.text('餐饮'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await closeLedger(tester, repo);
  });

  testWidgets(
    'first entry can create a category in place and validates amount',
    (tester) async {
      final repo = memoryRepository();
      await pumpLedger(tester, repo, size: const Size(360, 800));
      await tester.tap(find.text('记一笔'));
      await settle(tester);
      await tester.tap(find.text('保存'));
      await settle(tester);
      expect(find.text('金额须为正数，最多两位小数'), findsOneWidget);
      await tester.ensureVisible(find.text('添加分类（可选）'));
      await tester.tap(find.text('添加分类（可选）'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, '名称'), '通勤');
      await tester.tap(find.text('保存').last);
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, '金额（元）'),
        '6.00',
      );
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, '分类（可选）'),
      );
      await settle(tester);
      await tester.tap(find.text('通勤').last);
      await settle(tester);
      await tester.tap(find.text('保存'));
      await settle(tester);
      final views = (await tester.runAsync(repo.snapshot))!;
      expect(
        views
            .where((v) => v.current.entityType == EntityType.entry)
            .single
            .current
            .data['amountMinor'],
        600,
      );
      expect(tester.takeException(), isNull);
      await closeLedger(tester, repo);
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(820, 900),
    const Size(1440, 960),
  ]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('long money and notes fit $size $mode at large text', (
        tester,
      ) async {
        final repo = memoryRepository();
        await tester.runAsync(() async {
          final cat = await category(repo, name: '这是一个名称很长但有效的日常支出分类');
          await entry(
            repo,
            cat,
            amount: maxAmountMinor,
            date: DateTime.now().toIso8601String().substring(0, 10),
          );
        });
        await pumpLedger(tester, repo, size: size, mode: mode, scale: 1.6);
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -1800),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        await closeLedger(tester, repo);
      });
    }
  }
}
