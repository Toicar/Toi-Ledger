import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/providers.dart';
import 'package:my_ledger/updates/update_service.dart';
import 'package:my_ledger/updates/update_ui.dart';
import 'support.dart';
import 'widget_test.dart' show settle;
import 'redesign_test.dart' show closeLedger;

void main() {
  testWidgets('update source can be saved and cleared without ledger changes', (
    tester,
  ) async {
    final repo = memoryRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: UpdateSettingsCard()),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('软件更新'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'https://updates.example/manifest.json',
    );
    await tester.tap(find.text('保存更新地址'));
    await settle(tester);
    expect(
      await tester.runAsync(() => UpdatePreferences(repo.db).read()),
      'https://updates.example/manifest.json',
    );
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('保存更新地址'));
    await settle(tester);
    expect(await tester.runAsync(() => UpdatePreferences(repo.db).read()), '');
    expect(await tester.runAsync(repo.allOperations), isEmpty);
    await closeLedger(tester, repo);
  });
}
