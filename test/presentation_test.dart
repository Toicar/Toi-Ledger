import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/presentation_controller.dart';
import 'package:my_ledger/app/providers.dart';
import 'package:my_ledger/data/database.dart';
import 'package:my_ledger/data/ledger_repository.dart';

void main() {
  test('presentation defaults and unknown values are safe', () async {
    final db = LedgerDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final prefs = PresentationPreferences(db);
    expect((await prefs.read()).style, LedgerStyle.satin);
    expect((await prefs.read()).hideAmounts, false);
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: 'appearance.style', value: 'unknown'),
        );
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: 'privacy.hideAmounts',
            value: 'unknown',
          ),
        );
    expect((await prefs.read()).style, LedgerStyle.satin);
    expect((await prefs.read()).hideAmounts, false);
  });
  test(
    'serialized updates retain both fields and create no ledger logs',
    () async {
      final db = LedgerDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(LedgerRepository(db))],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final controller = container.read(presentationProvider.notifier);
      await Future.wait([
        controller.setStyle(LedgerStyle.glass),
        controller.setHideAmounts(true),
      ]);
      expect(container.read(presentationProvider).style, LedgerStyle.glass);
      expect(container.read(presentationProvider).hideAmounts, true);
      expect((await PresentationPreferences(db).read()).hideAmounts, true);
      expect(await db.select(db.operationRows).get(), isEmpty);
      await db.customStatement('PRAGMA query_only = ON');
      await expectLater(
        controller.setHideAmounts(false),
        throwsA(isA<Exception>()),
      );
      expect(container.read(presentationProvider).hideAmounts, true);
      await db.customStatement('PRAGMA query_only = OFF');
      await controller.setStyle(LedgerStyle.satin);
      expect(container.read(presentationProvider).style, LedgerStyle.satin);
      expect(container.read(presentationProvider).hideAmounts, true);
    },
  );
  test('style and hidden amounts survive database reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger-presentation-',
    );
    final file = File('${directory.path}/test.sqlite');
    var db = LedgerDatabase(NativeDatabase(file));
    try {
      await PresentationPreferences(db).write(
        const PresentationSettings(style: LedgerStyle.glass, hideAmounts: true),
      );
      await db.close();
      db = LedgerDatabase(NativeDatabase(file));
      final restored = await PresentationPreferences(db).read();
      expect(restored.style, LedgerStyle.glass);
      expect(restored.hideAmounts, true);
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}
