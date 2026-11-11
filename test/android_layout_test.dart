import 'package:my_ledger/app/language_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/ledger_app.dart';
import 'package:my_ledger/app/providers.dart';
import 'support.dart';
import 'widget_test.dart' show EmptyCredentials, settle;

void main() {
  testWidgets('empty state can scroll fully above the record button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 796);
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
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
    await settle(tester);
    final message = tester.getRect(find.text('暂无记录，点击右下角记一笔'));
    final button = tester.getRect(find.byType(FloatingActionButton));
    expect(message.bottom, lessThanOrEqualTo(button.top - 8));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    final closing = repo.db.close();
    await tester.pumpAndSettle();
    await closing;
  });
}
