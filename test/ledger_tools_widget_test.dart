import 'package:my_ledger/app/language_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/appearance_controller.dart';
import 'package:my_ledger/app/ledger_app.dart';
import 'package:my_ledger/app/presentation_controller.dart';
import 'package:my_ledger/app/providers.dart';
import 'support.dart';
import 'widget_test.dart' show EmptyCredentials, settle;

void main() {
  for (final style in LedgerStyle.values) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('$style $mode: privacy and tools fit small screen', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = memoryRepository();
        await tester.runAsync(() async {
          final cat = await category(repo);
          await entry(
            repo,
            cat,
            date: DateTime.now().toIso8601String().substring(0, 10),
          );
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              repositoryProvider.overrideWithValue(repo),
              initialLanguageProvider.overrideWithValue(LedgerLanguage.zh),
              credentialProvider.overrideWithValue(EmptyCredentials()),
              initialThemeModeProvider.overrideWithValue(mode),
              initialPresentationProvider.overrideWithValue(
                PresentationSettings(style: style),
              ),
            ],
            child: const LedgerApp(),
          ),
        );
        await settle(tester);
        expect(find.textContaining('12.34'), findsWidgets);
        await tester.tap(find.byTooltip('隐藏金额'));
        await settle(tester);
        expect(find.textContaining('12.34'), findsNothing);
        expect(find.byTooltip('显示金额'), findsOneWidget);
        await tester.ensureVisible(find.text('统计分析'));
        await tester.tap(find.text('统计分析'));
        await settle(tester);
        expect(find.textContaining('12.34'), findsNothing);
        expect(find.text('金额已隐藏'), findsWidgets);
        await tester.tap(find.byType(BackButton));
        await settle(tester);
        await tester.ensureVisible(find.text('快捷模板'));
        await tester.tap(find.text('快捷模板'));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        final closing = repo.db.close();
        await tester.pumpAndSettle();
        await closing;
      });
    }
  }
  testWidgets('material switch preserves independent brightness choice', (
    tester,
  ) async {
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
    await tester.ensureVisible(find.byKey(const ValueKey('material-glass')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('material-glass')));
    await settle(tester);
    await tester.ensureVisible(find.text('深色'));
    await settle(tester);
    await tester.tap(find.text('深色'));
    await settle(tester);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.ensureVisible(find.text('细腻磨砂'));
    await settle(tester);
    await tester.tap(find.text('细腻磨砂'));
    await settle(tester);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.pumpWidget(const SizedBox());
    final closing = repo.db.close();
    await tester.pumpAndSettle();
    await closing;
  });
}
