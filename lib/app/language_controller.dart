import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import 'providers.dart';

enum LedgerLanguage { system, zh, en }

final initialLanguageProvider = Provider<LedgerLanguage>(
  (ref) => LedgerLanguage.system,
);
final languageProvider =
    StateNotifierProvider<LanguageController, LedgerLanguage>(
      (ref) => LanguageController(
        LanguagePreferences(ref.watch(repositoryProvider).db),
        ref.watch(initialLanguageProvider),
      ),
    );

Locale resolveLedgerLocale(List<Locale>? locales) {
  for (final locale in locales ?? const <Locale>[]) {
    if (locale.languageCode == 'zh') return const Locale('zh', 'CN');
    if (locale.languageCode == 'en') return const Locale('en');
  }
  return const Locale('en');
}

class LanguagePreferences {
  LanguagePreferences(this.db);
  final LedgerDatabase db;
  static const key = 'ui.language';
  Future<LedgerLanguage> read() async {
    final row = await (db.select(
      db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return switch (row?.value) {
      'zh' => LedgerLanguage.zh,
      'en' => LedgerLanguage.en,
      _ => LedgerLanguage.system,
    };
  }

  Future<void> write(LedgerLanguage value) async {
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: key, value: value.name),
        );
  }
}

class LanguageController extends StateNotifier<LedgerLanguage> {
  LanguageController(this.preferences, super.state);
  final LanguagePreferences preferences;
  Future<void> _pending = Future.value();
  Future<void> setLanguage(LedgerLanguage value) {
    final operation = _pending.then((_) async {
      await preferences.write(value);
      if (mounted) state = value;
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}
