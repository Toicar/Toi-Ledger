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
  testWidgets('automatic update checks can be disabled and re-enabled', (
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
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await tester.tap(find.byType(SwitchListTile));
    await settle(tester);
    expect(
      await tester.runAsync(() => UpdatePreferences(repo.db).readEnabled()),
      isFalse,
    );
    await tester.tap(find.byType(SwitchListTile));
    await settle(tester);
    expect(
      await tester.runAsync(() => UpdatePreferences(repo.db).readEnabled()),
      isTrue,
    );
    expect(await tester.runAsync(repo.allOperations), isEmpty);
    await closeLedger(tester, repo);
  });
}
