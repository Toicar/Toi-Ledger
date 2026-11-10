import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/appearance_controller.dart';
import 'package:my_ledger/app/providers.dart';
import 'package:my_ledger/data/database.dart';
import 'package:my_ledger/data/ledger_repository.dart';

void main() {
  late LedgerDatabase db;
  late ProviderContainer container;
  setUp(() {
    db = LedgerDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(LedgerRepository(db))],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('missing and unknown stored values fall back to system', () async {
    expect(await AppearancePreferences(db).read(), ThemeMode.system);
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: 'appearance.themeMode',
            value: 'unknown',
          ),
        );
    expect(await AppearancePreferences(db).read(), ThemeMode.system);
    expect(container.read(appearanceProvider), ThemeMode.system);
  });

  test('each mode persists without creating ledger operations', () async {
    for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
      await container.read(appearanceProvider.notifier).setMode(mode);
      expect(container.read(appearanceProvider), mode);
      expect(await AppearancePreferences(db).read(), mode);
    }
    expect(await db.select(db.operationRows).get(), isEmpty);
    expect(await db.select(db.headRows).get(), isEmpty);
    expect((await db.select(db.settings).get()).length, 1);
  });

  test('startup override restores initial mode', () {
    final restored = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(LedgerRepository(db)),
        initialThemeModeProvider.overrideWithValue(ThemeMode.dark),
      ],
    );
    addTearDown(restored.dispose);
    expect(restored.read(appearanceProvider), ThemeMode.dark);
  });

  test(
    'failed write throws and preserves prior selection and storage',
    () async {
      await container.read(appearanceProvider.notifier).setMode(ThemeMode.dark);
      await db.customStatement('PRAGMA query_only = ON');
      await expectLater(
        container.read(appearanceProvider.notifier).setMode(ThemeMode.light),
        throwsA(isA<Exception>()),
      );
      expect(container.read(appearanceProvider), ThemeMode.dark);
      expect(await AppearancePreferences(db).read(), ThemeMode.dark);
    },
  );

  test('disk reopen restores the saved preference', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger-appearance-',
    );
    final file = File('${directory.path}/ledger.sqlite');
    var disk = LedgerDatabase(NativeDatabase(file));
    try {
      await AppearancePreferences(disk).write(ThemeMode.light);
      await disk.close();
      disk = LedgerDatabase(NativeDatabase(file));
      expect(await AppearancePreferences(disk).read(), ThemeMode.light);
    } finally {
      await disk.close();
      await directory.delete(recursive: true);
    }
  });
}
