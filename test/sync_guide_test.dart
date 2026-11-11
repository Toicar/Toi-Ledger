import 'package:my_ledger/app/language_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/ledger_app.dart';
import 'package:my_ledger/app/app_theme.dart';
import 'package:my_ledger/app/presentation_controller.dart';
import 'package:my_ledger/app/providers.dart';
import 'package:my_ledger/data/credential_store.dart';
import 'package:my_ledger/features/sync/sync_guide_page.dart';
import 'package:my_ledger/sync/webdav.dart';
import 'redesign_test.dart' show closeLedger;
import 'support.dart';
import 'widget_test.dart' show settle;

Finder guideScroll() => find
    .descendant(
      of: find.byKey(const ValueKey('sync-guide-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

class _Credentials implements CredentialStore {
  DavConfig? value;
  int writes = 0, clears = 0;
  @override
  Future<DavConfig?> read() async => value;
  @override
  Future<void> write(DavConfig config) async {
    writes++;
    value = config;
  }

  @override
  Future<void> clear() async {
    clears++;
    value = null;
  }
}

void main() {
  testWidgets(
    'saved connection can be copied without password or unsaved edits',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = memoryRepository();
      final credentials = _Credentials();
      final clipboard = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            initialLanguageProvider.overrideWithValue(LedgerLanguage.zh),
            credentialProvider.overrideWithValue(credentials),
          ],
          child: const LedgerApp(),
        ),
      );
      await settle(tester);
      // Keep startup offline. Guide navigation never starts a network request.
      credentials.value = DavConfig(
        endpoint: 'https://dav.example.invalid/ledger/',
        username: 'saved-user',
        password: 'private-password-never-copy',
      );
      await tester.tap(find.text('同步设置'));
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextField, '用户名'),
        'unsaved-user',
      );
      await tester.tap(find.byKey(const ValueKey('open-sync-guide')));
      await settle(tester);
      expect(find.text('多设备连接指引'), findsOneWidget);
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, '同步设置')).selected,
        isTrue,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('copy-safe-sync-info')),
        400,
        scrollable: guideScroll(),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('copy-safe-sync-info')));
      await settle(tester);
      final id = (await tester.runAsync(() => repo.ledgerId))!;
      expect(clipboard.single, contains(id));
      expect(clipboard.single, contains('https://dav.example.invalid/ledger/'));
      expect(clipboard.single, contains('saved-user'));
      expect(clipboard.single, isNot(contains('unsaved-user')));
      expect(clipboard.single, isNot(contains('private-password-never-copy')));
      expect(credentials.writes, 0);
      expect(credentials.clears, 0);
      expect((await tester.runAsync(repo.allOperations))!, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.widgetWithText(TextField, '用户名'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '用户名'))
            .controller!
            .text,
        'unsaved-user',
      );
      await closeLedger(tester, repo);
    },
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'guide roles, network modes and recovery fit narrow large text: $mode',
      (tester) async {
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
              credentialProvider.overrideWithValue(_Credentials()),
            ],
            child: MaterialApp(
              theme: AppTheme.resolve(Brightness.light, LedgerStyle.satin),
              darkTheme: AppTheme.resolve(Brightness.dark, LedgerStyle.glass),
              themeMode: mode,
              home: const SyncGuidePage(
                ledgerId: '11111111-1111-4111-8111-111111111111',
              ),
            ),
          ),
        );
        await settle(tester);
        // Selectable connection text has its own inner scrollable.
        final vertical = guideScroll();
        expect(vertical, findsOneWidget);
        await tester.ensureVisible(find.text('加入现有账本'));
        await settle(tester);
        await tester.tap(find.text('加入现有账本'));
        await settle(tester);
        await tester.scrollUntilVisible(
          find.text('跨网络'),
          180,
          scrollable: vertical,
        );
        await settle(tester);
        await tester.tap(find.text('跨网络'));
        await settle(tester);
        expect(find.textContaining('局域网 IP 无法'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('在这台空设备填写相同配置'),
          180,
          scrollable: vertical,
        );
        expect(find.textContaining('删除全部账单后仍有历史记录'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('copy-safe-sync-info')),
          300,
          scrollable: vertical,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const ValueKey('copy-safe-sync-info')),
              )
              .onPressed,
          isNull,
        );
        await tester.scrollUntilVisible(
          find.text('身份验证失败或权限不足'),
          220,
          scrollable: vertical,
        );
        await settle(tester);
        await tester.tap(find.text('身份验证失败或权限不足'));
        await settle(tester);
        expect(find.textContaining('不要把密码发给他人'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await closeLedger(tester, repo);
      },
    );
  }
}
