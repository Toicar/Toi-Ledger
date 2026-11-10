import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import 'providers.dart';

final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

final appearanceProvider =
    StateNotifierProvider<AppearanceController, ThemeMode>(
      (ref) => AppearanceController(
        AppearancePreferences(ref.watch(repositoryProvider).db),
        ref.watch(initialThemeModeProvider),
      ),
    );

class AppearancePreferences {
  AppearancePreferences(this.db);

  final LedgerDatabase db;
  static const _key = 'appearance.themeMode';

  Future<ThemeMode> read() async {
    final row = await (db.select(
      db.settings,
    )..where((setting) => setting.key.equals(_key))).getSingleOrNull();
    return switch (row?.value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> write(ThemeMode mode) => db.transaction(() async {
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: _key, value: mode.name),
        );
  });
}

class AppearanceController extends StateNotifier<ThemeMode> {
  AppearanceController(this._preferences, super.state);

  final AppearancePreferences _preferences;

  Future<void> setMode(ThemeMode mode) async {
    await _preferences.write(mode);
    if (mounted) state = mode;
  }
}
