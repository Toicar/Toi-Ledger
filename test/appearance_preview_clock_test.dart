import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/providers.dart';
import 'package:my_ledger/features/appearance/appearance_page.dart';
import 'support.dart';
import 'widget_test.dart' show settle;
import 'redesign_test.dart' show closeLedger;

void main() {
  test('preview uses month, zero-padded day and 24-hour clock', () {
    expect(appearancePreviewAmount(DateTime(2026, 1, 1, 0)), '¥101.00');
    expect(appearancePreviewAmount(DateTime(2026, 9, 9, 9)), '¥909.09');
    expect(appearancePreviewAmount(DateTime(2026, 11, 11, 13)), '¥1,111.13');
    expect(appearancePreviewAmount(DateTime(2026, 12, 31, 23)), '¥1,231.23');
  });

  testWidgets('preview updates at the hour and after returning to foreground', (
    tester,
  ) async {
    final repo = memoryRepository();
    var now = DateTime(2026, 12, 31, 23, 59, 50);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: AppearancePage(clock: () => now)),
      ),
    );
    await settle(tester);
    expect(find.text('¥1,231.23'), findsOneWidget);
    now = DateTime(2027, 1, 1, 0);
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(find.text('¥101.00'), findsOneWidget);
    now = DateTime(2027, 1, 1, 14, 20);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('¥101.14'), findsOneWidget);
    expect((await tester.runAsync(repo.allOperations))!, isEmpty);
    await closeLedger(tester, repo);
  });
}
