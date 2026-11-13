import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/app_version.dart';
import 'package:my_ledger/app/ledger_workspace.dart';

void main() {
  testWidgets('desktop sidebar shows the shared application version', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: LedgerWorkspace(
          route: '/',
          onNavigate: (_) {},
          onCreate: () {},
          child: const SizedBox(),
        ),
      ),
    );
    expect(find.text('MYLEDGER  /  $currentVersionName'), findsOneWidget);
  });
}
