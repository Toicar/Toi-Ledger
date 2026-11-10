import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import 'providers.dart';
import 'theme_accent.dart';
import '../domain/operation.dart';

enum LedgerStyle { satin, glass }

class PresentationSettings {
  const PresentationSettings({
    this.style = LedgerStyle.satin,
    this.hideAmounts = false,
    this.accent = LedgerAccent.clay,
    this.uncategorizedThresholdMinor = 50000,
  });
  final LedgerStyle style;
  final bool hideAmounts;
  final LedgerAccent accent;
  final int uncategorizedThresholdMinor;

  PresentationSettings copyWith({
    LedgerStyle? style,
    bool? hideAmounts,
    LedgerAccent? accent,
    int? uncategorizedThresholdMinor,
  }) => PresentationSettings(
    style: style ?? this.style,
    hideAmounts: hideAmounts ?? this.hideAmounts,
    accent: accent ?? this.accent,
    uncategorizedThresholdMinor:
        uncategorizedThresholdMinor ?? this.uncategorizedThresholdMinor,
  );
}

final initialPresentationProvider = Provider<PresentationSettings>(
  (ref) => const PresentationSettings(),
);
final presentationProvider =
    StateNotifierProvider<PresentationController, PresentationSettings>(
      (ref) => PresentationController(
        PresentationPreferences(ref.watch(repositoryProvider).db),
        ref.watch(initialPresentationProvider),
      ),
    );

class PresentationPreferences {
  PresentationPreferences(this.db);
  final LedgerDatabase db;
  Future<PresentationSettings> read() async {
    final rows =
        await (db.select(db.settings)..where(
              (s) => s.key.isIn([
                'appearance.style',
                'privacy.hideAmounts',
                'appearance.accent',
                'statistics.uncategorizedThresholdMinor',
              ]),
            ))
            .get();
    final values = {for (final row in rows) row.key: row.value};
    final threshold = int.tryParse(
      values['statistics.uncategorizedThresholdMinor'] ?? '',
    );
    return PresentationSettings(
      style: values['appearance.style'] == 'glass'
          ? LedgerStyle.glass
          : LedgerStyle.satin,
      hideAmounts: values['privacy.hideAmounts'] == 'true',
      accent:
          LedgerAccent.values
              .where((a) => a.name == values['appearance.accent'])
              .firstOrNull ??
          LedgerAccent.clay,
      uncategorizedThresholdMinor:
          threshold != null && threshold > 0 && threshold <= maxAmountMinor
          ? threshold
          : 50000,
    );
  }

  Future<void> write(PresentationSettings value) => db.transaction(() async {
    for (final row in [
      SettingsCompanion.insert(
        key: 'appearance.style',
        value: value.style.name,
      ),
      SettingsCompanion.insert(
        key: 'privacy.hideAmounts',
        value: value.hideAmounts.toString(),
      ),
      SettingsCompanion.insert(
        key: 'appearance.accent',
        value: value.accent.name,
      ),
      SettingsCompanion.insert(
        key: 'statistics.uncategorizedThresholdMinor',
        value: value.uncategorizedThresholdMinor.toString(),
      ),
    ]) {
      await db.into(db.settings).insertOnConflictUpdate(row);
    }
  });
}

class PresentationController extends StateNotifier<PresentationSettings> {
  PresentationController(this.preferences, super.state);
  final PresentationPreferences preferences;
  Future<void> _queue = Future.value();
  Future<void> _save(
    PresentationSettings Function(PresentationSettings) update,
  ) {
    final next = _queue.then((_) async {
      if (!mounted) return;
      final value = update(state);
      await preferences.write(value);
      if (mounted) state = value;
    });
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<void> setStyle(LedgerStyle style) =>
      _save((old) => old.copyWith(style: style));
  Future<void> setHideAmounts(bool hidden) =>
      _save((old) => old.copyWith(hideAmounts: hidden));
  Future<void> setAccent(LedgerAccent accent) =>
      _save((old) => old.copyWith(accent: accent));
  Future<void> setUncategorizedThreshold(int minor) {
    if (minor <= 0 || minor > maxAmountMinor) {
      return Future.error(const LedgerException('大额门槛须为有效的正数金额'));
    }
    return _save((old) => old.copyWith(uncategorizedThresholdMinor: minor));
  }
}
