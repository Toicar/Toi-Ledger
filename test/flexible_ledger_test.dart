import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/data/entry_templates.dart';
import 'package:my_ledger/data/database.dart';
import 'package:my_ledger/domain/operation.dart';
import 'package:my_ledger/domain/ledger_statistics.dart';
import 'package:my_ledger/sync/sync_engine.dart';
import 'package:my_ledger/app/presentation_controller.dart';
import 'package:my_ledger/app/theme_accent.dart';
import 'package:my_ledger/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'support.dart';

void main() {
  test(
    'optional template presets retain v1 data and round-trip null values',
    () async {
      final repo = memoryRepository();
      addTearDown(repo.db.close);
      final old = EntryTemplate(
        id: uuid.v4(),
        name: '旧模板',
        kind: 'expense',
        categoryId: uuid.v4(),
        amountMinor: 1234,
        note: '原预设',
      );
      final flexible = EntryTemplate(
        id: uuid.v4(),
        name: '随手记',
        kind: 'expense',
        note: '一笔生活',
      );
      final prefs = EntryTemplatePreferences(repo.db);
      await repo.db
          .into(repo.db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(
              key: EntryTemplatePreferences.key,
              value: jsonEncode({
                'version': 1,
                'templates': [old.toJson()],
              }),
            ),
          );
      expect((await prefs.read()).single.toJson(), old.toJson());
      await prefs.write([old, flexible]);
      final saved = await prefs.read();
      expect(saved.first.toJson(), old.toJson());
      expect(saved.last.amountMinor, isNull);
      expect(saved.last.categoryId, isNull);
      expect(templateCategoryIssue(saved.last, []), isNull);
      expect(await repo.allOperations(), isEmpty);
    },
  );

  test(
    'unclassified v2 records synchronize, classify later and preserve v1 hashes',
    () async {
      final a = memoryRepository(), b = memoryRepository();
      addTearDown(() async {
        await a.db.close();
        await b.db.close();
      });
      await b.joinEmptyLedger(await a.ledgerId);
      final unclassified = await a.save(
        type: EntityType.entry,
        data: {
          'kind': 'expense',
          'amountMinor': 50000,
          'categoryId': null,
          'date': '2026-11-10',
          'note': '先记下来',
        },
      );
      expect(unclassified.protocolVersion, 2);
      expect(
        Operation.decode(unclassified.encode()).canonical,
        unclassified.canonical,
      );
      final categoryOp = await category(a);
      expect(categoryOp.protocolVersion, 1);
      expect(Operation.decode(categoryOp.encode()).digest, categoryOp.digest);
      final remote = MemoryRemote();
      await SyncEngine(a, remote).synchronize();
      await SyncEngine(b, remote).synchronize();
      final copied = (await b.snapshot()).singleWhere(
        (v) => v.current.entityId == unclassified.entityId,
      );
      expect(copied.current.data['categoryId'], isNull);
      await b.save(
        type: EntityType.entry,
        entityId: copied.current.entityId,
        expectedHeads: [copied.current.id],
        data: {...copied.current.data, 'categoryId': categoryOp.entityId},
      );
      await SyncEngine(b, remote).synchronize();
      await SyncEngine(a, remote).synchronize();
      expect(
        (await a.snapshot())
            .singleWhere((v) => v.current.entityId == unclassified.entityId)
            .current
            .data['categoryId'],
        categoryOp.entityId,
      );
      expect(
        (await a.allOperations())
            .firstWhere((o) => o.id == unclassified.id)
            .canonical,
        unclassified.canonical,
      );
      final envelope =
          jsonDecode(unclassified.encode()) as Map<String, dynamic>;
      envelope['operation']['data']['amountMinor'] = 1;
      expect(
        () => Operation.decode(jsonEncode(envelope)),
        throwsA(isA<LedgerException>()),
      );
    },
  );

  test(
    'large boundary bills stand alone, small bills form other, totals never duplicate',
    () async {
      final repo = memoryRepository();
      addTearDown(repo.db.close);
      final cat = await category(repo, name: '餐饮');
      await entry(repo, cat, amount: 2000, date: '2026-11-10');
      for (final (amount, note) in [
        (49999, '小额一'),
        (100, '小额二'),
        (50000, '边界账单'),
        (80000, '另一笔大额'),
      ]) {
        await repo.save(
          type: EntityType.entry,
          data: {
            'kind': 'expense',
            'amountMinor': amount,
            'categoryId': null,
            'date': '2026-11-10',
            'note': note,
          },
        );
      }
      final stats = LedgerStatistics.forMonth(
        await repo.snapshot(),
        DateTime(2026, 11),
      );
      expect(stats.categoryExpenses.length, 4);
      final other = stats.categoryExpenses.singleWhere(
        (g) => g.groupKind == StatisticsGroupKind.other,
      );
      expect(other.label, '其他');
      expect(other.entries.length, 2);
      expect(other.amountMinor, 50099);
      expect(
        stats.categoryExpenses
            .where((g) => g.groupKind == StatisticsGroupKind.uncategorizedEntry)
            .length,
        2,
      );
      expect(
        stats.categoryExpenses.fold<int>(0, (sum, g) => sum + g.amountMinor),
        stats.totals.expense,
      );
      final changed = LedgerStatistics.forMonth(
        await repo.snapshot(),
        DateTime(2026, 11),
        uncategorizedThresholdMinor: 100000,
      );
      expect(
        changed.categoryExpenses
            .singleWhere((g) => g.label == '其他')
            .entries
            .length,
        4,
      );
      expect(changed.totals.expense, stats.totals.expense);
      expect(
        changed.categoryExpenses.fold<double>(0, (sum, g) => sum + g.share),
        closeTo(1, .00001),
      );
    },
  );

  test(
    'deleted unclassified entries and conflicted versions stay excluded',
    () async {
      final repo = memoryRepository();
      addTearDown(repo.db.close);
      final first = await repo.save(
        type: EntityType.entry,
        data: {
          'kind': 'income',
          'amountMinor': 60000,
          'categoryId': null,
          'date': '2026-11-10',
          'note': '收入',
        },
      );
      await repo.remove(EntityView([first]));
      final stats = LedgerStatistics.forMonth(
        await repo.snapshot(),
        DateTime(2026, 11),
      );
      expect(stats.categoryIncomes, isEmpty);
      expect(stats.totals.income, 0);
      final conflict = EntityView([
        first,
        Operation(
          id: uuid.v4(),
          ledgerId: first.ledgerId,
          deviceId: uuid.v4(),
          entityId: first.entityId,
          entityType: EntityType.entry,
          parents: [],
          data: {...first.data, 'amountMinor': 70000},
          deleted: false,
          createdAt: first.createdAt,
        ),
      ]);
      final conflicted = LedgerStatistics.forMonth([
        conflict,
      ], DateTime(2026, 11));
      expect(conflicted.categoryIncomes, isEmpty);
      expect(conflicted.totals.conflicts, 1);
    },
  );

  test(
    'all accent button colors maintain contrast in both materials and brightnesses',
    () {
      for (final accent in LedgerAccent.values) {
        for (final style in LedgerStyle.values) {
          for (final brightness in Brightness.values) {
            final scheme = AppTheme.resolve(
              brightness,
              style,
              accent: accent,
            ).colorScheme;
            final a = scheme.primary.computeLuminance(),
                b = scheme.onPrimary.computeLuminance();
            final contrast = ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05);
            expect(
              contrast,
              greaterThanOrEqualTo(4.5),
              reason: '$accent $style $brightness',
            );
          }
        }
      }
    },
  );

  test(
    'palette, threshold, material and privacy survive independent updates',
    () async {
      final repo = memoryRepository();
      addTearDown(repo.db.close);
      final prefs = PresentationPreferences(repo.db);
      final controller = PresentationController(
        prefs,
        const PresentationSettings(),
      );
      addTearDown(controller.dispose);
      await Future.wait([
        controller.setAccent(LedgerAccent.bamboo),
        controller.setUncategorizedThreshold(100000),
        controller.setStyle(LedgerStyle.glass),
        controller.setHideAmounts(true),
      ]);
      final restored = await prefs.read();
      expect(restored.accent, LedgerAccent.bamboo);
      expect(restored.uncategorizedThresholdMinor, 100000);
      expect(restored.style, LedgerStyle.glass);
      expect(restored.hideAmounts, true);
      await expectLater(
        controller.setUncategorizedThreshold(0),
        throwsA(isA<LedgerException>()),
      );
      expect((await prefs.read()).uncategorizedThresholdMinor, 100000);
      expect(await repo.allOperations(), isEmpty);
    },
  );
}
