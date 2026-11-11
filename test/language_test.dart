import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/language_controller.dart';
import 'package:my_ledger/app/ledger_app.dart';
import 'package:my_ledger/app/providers.dart';
import 'package:my_ledger/data/database.dart';
import 'package:my_ledger/data/entry_templates.dart';
import 'package:my_ledger/l10n/app_strings.dart';
import 'support.dart';
import 'redesign_test.dart' show closeLedger;
import 'widget_test.dart' show EmptyCredentials, settle;

void systemLocale(WidgetTester tester, Locale locale) {
  tester.platformDispatcher.localesTestValue = [locale];
  tester.platformDispatcher.localeTestValue = locale;
}

void restoreSystemLocale(WidgetTester tester) =>
    addTearDown(() => systemLocale(tester, const Locale('zh', 'CN')));

void main() {
  test(
    'locale preferences default, tolerate unknown values and serialize independently',
    () async {
      final repo = memoryRepository();
      addTearDown(repo.db.close);
      final preferences = LanguagePreferences(repo.db);
      expect(await preferences.read(), LedgerLanguage.system);
      await repo.db
          .into(repo.db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(
              key: LanguagePreferences.key,
              value: 'future-language',
            ),
          );
      expect(await preferences.read(), LedgerLanguage.system);
      final controller = LanguageController(preferences, LedgerLanguage.system);
      addTearDown(controller.dispose);
      await Future.wait([
        controller.setLanguage(LedgerLanguage.zh),
        controller.setLanguage(LedgerLanguage.en),
      ]);
      expect(controller.state, LedgerLanguage.en);
      expect(await LanguagePreferences(repo.db).read(), LedgerLanguage.en);
      expect(await repo.allOperations(), isEmpty);
      await repo.db.customStatement('PRAGMA query_only = ON');
      await expectLater(
        controller.setLanguage(LedgerLanguage.zh),
        throwsA(isA<Exception>()),
      );
      expect(controller.state, LedgerLanguage.en);
      await repo.db.customStatement('PRAGMA query_only = OFF');
      await controller.setLanguage(LedgerLanguage.system);
      expect(await preferences.read(), LedgerLanguage.system);
    },
  );

  test(
    'system locale resolution supports Chinese variants and English fallback',
    () {
      expect(
        resolveLedgerLocale([const Locale('zh', 'HK')]),
        const Locale('zh', 'CN'),
      );
      expect(
        resolveLedgerLocale([const Locale('en', 'GB')]),
        const Locale('en'),
      );
      expect(
        resolveLedgerLocale([const Locale('fr', 'FR')]),
        const Locale('en'),
      );
      expect(resolveLedgerLocale(null), const Locale('en'));
    },
  );

  test(
    'catalog placeholders match and status/errors translate in both directions',
    () {
      final rows =
          (jsonDecode(File('lib/l10n/messages.json').readAsStringSync())
                  as List)
              .cast<Map<String, dynamic>>();
      final keys = <String>{};
      for (final row in rows) {
        expect(keys.add(row['key'] as String), isTrue);
        expect((row['en'] as String).trim(), isNotEmpty);
        final placeholder = RegExp(r'\{arg\d+\}');
        expect(
          placeholder.allMatches(row['zh'] as String).map((m) => m[0]).toSet(),
          placeholder.allMatches(row['en'] as String).map((m) => m[0]).toSet(),
        );
      }
      const en = AppStrings(Locale('en')), zh = AppStrings(Locale('zh', 'CN'));
      expect(
        en.message('WebDAV 身份验证失败或权限不足'),
        'WebDAV authentication failed or access denied',
      );
      expect(
        en.message('WebDAV 暂时不可用（HTTP 503）'),
        'WebDAV temporarily unavailable (HTTP 503)',
      );
      expect(
        zh.message(en.message('同步完成 · 下载 2 / 上传 3 · 冲突 0')),
        '同步完成 · 下载 2 / 上传 3 · 冲突 0',
      );
      expect(en.message('unrecognized diagnostic'), 'unrecognized diagnostic');
      expect(en.message('123'), '123');
      expect(en.message('本月已计入 3 笔账目'), '3 entries included this month');
      expect(zh.message('3 entries included this month'), '本月已计入 3 笔账目');
    },
  );

  testWidgets(
    'system default and runtime settings switch preserve records and persist',
    (tester) async {
      restoreSystemLocale(tester);
      systemLocale(tester, const Locale('en', 'US'));
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = memoryRepository();
      await tester.runAsync(() async {
        final c = await category(repo, name: '收入');
        await entry(
          repo,
          c,
          date: DateTime.now().toIso8601String().substring(0, 10),
        );
      });
      Future<void> open({
        LedgerLanguage initial = LedgerLanguage.system,
      }) async {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              repositoryProvider.overrideWithValue(repo),
              credentialProvider.overrideWithValue(EmptyCredentials()),
              initialLanguageProvider.overrideWithValue(initial),
            ],
            child: const LedgerApp(),
          ),
        );
        await settle(tester);
      }

      await open();
      expect(find.text('My ledger'), findsOneWidget);
      final before = (await tester.runAsync(
        repo.allOperations,
      ))!.map((op) => op.canonical).toList();
      await tester.tap(find.text('Sync settings'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('language-zh')));
      await settle(tester);
      expect(find.text('我的账本'), findsOneWidget);
      expect(
        (await tester.runAsync(() => LanguagePreferences(repo.db).read()))!,
        LedgerLanguage.zh,
      );
      await tester.tap(find.byKey(const ValueKey('language-en')));
      await settle(tester);
      expect(find.text('My ledger'), findsOneWidget);
      expect(
        (await tester.runAsync(() => LanguagePreferences(repo.db).read()))!,
        LedgerLanguage.en,
      );
      final saved = (await tester.runAsync(
        () => LanguagePreferences(repo.db).read(),
      ))!;
      await open(initial: saved);
      expect(find.text('My ledger'), findsOneWidget);
      expect(
        find.text('收入'),
        findsWidgets,
      ); // The user's category name is not translated.
      expect(
        (await tester.runAsync(
          repo.allOperations,
        ))!.map((op) => op.canonical).toList(),
        before,
      );
      systemLocale(tester, const Locale('zh', 'CN'));
      await settle(tester);
      expect(
        find.text('My ledger'),
        findsOneWidget,
      ); // Explicit English beats system.
      await tester.tap(find.text('Sync settings'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('language-system')));
      await settle(tester);
      expect(find.text('我的账本'), findsOneWidget);
      systemLocale(tester, const Locale('en', 'GB'));
      await settle(tester);
      expect(find.text('My ledger'), findsOneWidget);
      await closeLedger(tester, repo);
    },
  );

  testWidgets(
    'English entry, category and template forms fit narrow large text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = memoryRepository();
      await tester.runAsync(() async {
        final archived = await category(repo, name: '餐饮');
        await EntryTemplatePreferences(repo.db).write([
          EntryTemplate(
            id: uuid.v4(),
            name: '旧模板',
            kind: 'expense',
            note: '',
            categoryId: archived.entityId,
          ),
        ]);
        await repo.remove(
          (await repo.snapshot()).singleWhere(
            (view) => view.current.entityId == archived.entityId,
          ),
        );
        await category(repo, kind: 'income', name: '工资');
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            credentialProvider.overrideWithValue(EmptyCredentials()),
            initialLanguageProvider.overrideWithValue(LedgerLanguage.en),
          ],
          child: const LedgerApp(),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('New entry'));
      await settle(tester);
      expect(
        find.widgetWithText(TextFormField, 'Amount (CNY)'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Category (optional)',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      await tester.tap(find.byTooltip('Categories'));
      await settle(tester);
      await tester.tap(find.byTooltip('Edit category').first);
      await settle(tester);
      expect(
        find.textContaining('Existing transactions keep their direction'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      await tester.ensureVisible(find.text('Quick templates').first);
      await settle(tester);
      await tester.tap(find.text('Quick templates').first);
      await settle(tester);
      expect(
        find.text(
          'The category is archived. Edit the template and select another category.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Add template'));
      await settle(tester);
      expect(
        find.text('Selecting a category sets income or expense automatically'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await closeLedger(tester, repo);
    },
  );

  for (final locale in [const Locale('en'), const Locale('fr')]) {
    testWidgets(
      'English and unsupported-system fallback fit mobile large text: $locale',
      (tester) async {
        restoreSystemLocale(tester);
        systemLocale(tester, locale);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = memoryRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              repositoryProvider.overrideWithValue(repo),
              credentialProvider.overrideWithValue(EmptyCredentials()),
            ],
            child: const LedgerApp(),
          ),
        );
        await settle(tester);
        await tester.tap(find.byTooltip('Sync settings'));
        await settle(tester);
        expect(find.text('Language'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('open-sync-guide')),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        await tester.tap(find.byKey(const ValueKey('open-sync-guide')));
        await settle(tester);
        expect(find.text('Multi-device setup guide'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await closeLedger(tester, repo);
      },
    );
  }
}
