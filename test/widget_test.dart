import 'package:my_ledger/app/language_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/ledger_app.dart';
import 'package:my_ledger/app/appearance_controller.dart';
import 'package:my_ledger/app/providers.dart';
import 'package:my_ledger/data/credential_store.dart';
import 'package:my_ledger/domain/operation.dart';
import 'package:my_ledger/sync/webdav.dart';
import 'support.dart';

class EmptyCredentials implements CredentialStore {
  @override
  Future<DavConfig?> read() async => null;
  @override
  Future<void> write(DavConfig config) async {}
  @override
  Future<void> clear() async {}
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('small screen and large text: $mode', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = memoryRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            initialLanguageProvider.overrideWithValue(LedgerLanguage.zh),
            credentialProvider.overrideWithValue(EmptyCredentials()),
            initialThemeModeProvider.overrideWithValue(mode),
          ],
          child: const LedgerApp(),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('同步设置'));
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text('验证并保存'),
        200,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      final closing = repo.db.close();
      await tester.pumpAndSettle();
      await closing;
    });
  }
  testWidgets('appearance switches light, dark and system on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = memoryRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          initialLanguageProvider.overrideWithValue(LedgerLanguage.zh),
          credentialProvider.overrideWithValue(EmptyCredentials()),
        ],
        child: const LedgerApp(),
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('外观'));
    await settle(tester);
    await tester.ensureVisible(find.text('深色'));
    await settle(tester);
    await tester.tap(find.text('深色'));
    await settle(tester);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.ensureVisible(find.text('浅色'));
    await settle(tester);
    await tester.tap(find.text('浅色'));
    await settle(tester);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    await tester.ensureVisible(find.text('跟随系统'));
    await settle(tester);
    await tester.tap(find.text('跟随系统'));
    await settle(tester);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await settle(tester);
    expect(
      Theme.of(tester.element(find.text('外观'))).brightness,
      Brightness.dark,
    );
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    final closing = repo.db.close();
    await tester.pumpAndSettle();
    await closing;
  });
  testWidgets('mobile: create category, record expense, search and delete', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = memoryRepository();
    await tester.runAsync(() async {
      await repo.ledgerId;
      await repo.deviceId;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          initialLanguageProvider.overrideWithValue(LedgerLanguage.zh),
          credentialProvider.overrideWithValue(EmptyCredentials()),
        ],
        child: const LedgerApp(),
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('分类管理'));
    await settle(tester);
    await tester.tap(find.byTooltip('添加分类'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, '测试餐饮');
    await tester.tap(find.text('保存'));
    await settle(tester);
    expect(find.text('测试餐饮'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(find.text('记一笔'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, '金额（元）'),
      '12.34',
    );
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, '分类（可选）'),
    );
    await settle(tester);
    await tester.tap(find.text('测试餐饮').last);
    await settle(tester);
    await tester.tap(find.text('保存'));
    await settle(tester);
    expect(find.text('支出 ¥12.34'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '不存在');
    await settle(tester);
    expect(find.text('测试餐饮 · ¥12.34'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '');
    await settle(tester);
    await tester.ensureVisible(find.byTooltip('删除'));
    await settle(tester);
    await tester.tap(find.byTooltip('删除'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await settle(tester);
    expect(find.text('支出 ¥0.00'), findsOneWidget);
    expect(
      (await tester.runAsync(repo.snapshot))!
          .where((v) => v.current.entityType == EntityType.entry)
          .single
          .current
          .deleted,
      true,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    final closing = repo.db.close();
    await tester.pumpAndSettle();
    await closing;
  });
  testWidgets('desktop: settings render without overflow', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = memoryRepository();
    await tester.runAsync(() async {
      await repo.ledgerId;
      await repo.deviceId;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          initialLanguageProvider.overrideWithValue(LedgerLanguage.zh),
          credentialProvider.overrideWithValue(EmptyCredentials()),
        ],
        child: const LedgerApp(),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('同步设置'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('验证并保存'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await settle(tester);
    expect(find.text('验证并保存'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    final closing = repo.db.close();
    await tester.pumpAndSettle();
    await closing;
  });
  testWidgets(
    'mobile: every conflict version is visible and explicitly resolvable',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = memoryRepository(), other = memoryRepository();
      await tester.runAsync(() async {
        final cat = await category(repo);
        final first = await entry(repo, cat);
        await other.joinEmptyLedger(await repo.ledgerId);
        await other.ingest(await repo.allOperations());
        await edit(repo, first, amount: 111);
        await edit(other, first, amount: 222);
        await repo.ingest(await other.allOperations());
        await other.db.close();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            initialLanguageProvider.overrideWithValue(LedgerLanguage.zh),
            credentialProvider.overrideWithValue(EmptyCredentials()),
          ],
          child: const LedgerApp(),
        ),
      );
      await settle(tester);
      await tester.tap(find.textContaining('处理全部冲突'));
      await settle(tester);
      expect(find.textContaining('分类 ID：'), findsNWidgets(2));
      await tester.tap(find.text('2026-10-21 · ¥1.11'));
      await settle(tester);
      final snapshot = await tester.runAsync(repo.snapshot);
      expect(snapshot!.any((v) => v.hasConflict), false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      final closing = repo.db.close();
      await tester.pumpAndSettle();
      await closing;
    },
  );
}
