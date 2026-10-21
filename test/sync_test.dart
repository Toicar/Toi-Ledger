import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/data/ledger_repository.dart';
import 'package:my_ledger/domain/operation.dart';
import 'package:my_ledger/sync/sync_engine.dart';
import 'package:my_ledger/sync/webdav.dart';
import 'support.dart';

void main() {
  late LedgerRepository a, b;
  late MemoryRemote remote;
  late SyncEngine syncA, syncB;
  setUp(() async {
    a = memoryRepository();
    b = memoryRepository();
    await b.joinEmptyLedger(await a.ledgerId);
    remote = MemoryRemote();
    syncA = SyncEngine(a, remote, delay: (_) async {});
    syncB = SyncEngine(b, remote, delay: (_) async {});
  });
  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });
  test(
    'bidirectional incremental transfer is idempotent, including response loss',
    () async {
      final cat = await category(a);
      await entry(a, cat);
      remote.failAfterCommit = true;
      await syncA.synchronize();
      await syncB.synchronize();
      expect((await a.allOperations(pendingOnly: true)), isEmpty);
      expect((await b.allOperations()).length, 2);
      final oldReads = remote.reads, oldWrites = remote.writes;
      await syncA.synchronize();
      await syncB.synchronize();
      expect(remote.reads, oldReads);
      expect(remote.writes, oldWrites);
      final copied = (await b.snapshot())
          .singleWhere((e) => e.current.entityType == EntityType.entry)
          .current;
      await edit(b, copied, amount: 599);
      await syncB.synchronize();
      await syncA.synchronize();
      expect(
        LedgerRepository.monthly(await a.snapshot(), '2026-10').expense,
        599,
      );
    },
  );
  test('offline retries are bounded and durable outbox resumes', () async {
    await category(a);
    remote.failWrites = 10;
    await expectLater(syncA.synchronize(), throwsA(isA<DavException>()));
    expect(remote.writes, 3);
    expect((await a.allOperations(pendingOnly: true)).length, 1);
    remote.failWrites = 0;
    await syncA.synchronize();
    expect(await a.allOperations(pendingOnly: true), isEmpty);
  });
  test(
    'concurrent edit/delete retains both heads and resolves explicitly',
    () async {
      final cat = await category(a);
      final first = await entry(a, cat);
      await syncA.synchronize();
      await syncB.synchronize();
      await edit(a, first, amount: 800);
      await b.remove(EntityView([first]));
      await Future.wait([syncA.synchronize(), syncB.synchronize()]);
      await syncA.synchronize();
      await syncB.synchronize();
      final conflict = (await a.snapshot()).singleWhere(
        (e) => e.current.entityId == first.entityId,
      );
      expect(conflict.versions.length, 2);
      expect(conflict.versions.any((o) => o.deleted), true);
      final total = LedgerRepository.monthly(await a.snapshot(), '2026-10');
      expect(total.expense, 0);
      expect(total.conflicts, 1);
      await expectLater(a.remove(conflict), throwsA(isA<LedgerException>()));
      final keep = conflict.versions.firstWhere((o) => !o.deleted);
      await a.save(
        entityId: keep.entityId,
        type: keep.entityType,
        data: keep.data,
        expectedHeads: conflict.versions.map((v) => v.id).toList(),
        resolve: true,
      );
      await syncA.synchronize();
      await syncB.synchronize();
      expect((await b.snapshot()).any((v) => v.hasConflict), false);
      expect(
        LedgerRepository.monthly(await b.snapshot(), '2026-10').expense,
        800,
      );
      expect((await b.allOperations()).length, 5);
    },
  );
  test('malformed remote batch changes no local state', () async {
    final cat = await category(a);
    await entry(a, cat);
    await syncA.synchronize();
    remote.files[remote.files.keys.last] = '{"broken":true}';
    await expectLater(syncB.synchronize(), throwsA(isA<LedgerException>()));
    expect(await b.allOperations(), isEmpty);
  });
  test(
    'missing parents and wrong ledger are rejected without partial commit',
    () async {
      final cat = await category(a);
      final op = await entry(a, cat);
      final changed = await edit(a, op);
      remote.files[changed.id] = changed.encode();
      await expectLater(syncB.synchronize(), throwsA(isA<LedgerException>()));
      expect(await b.allOperations(), isEmpty);
      remote.files.clear();
      final other = memoryRepository();
      try {
        final alien = await category(other);
        remote.files[alien.id] = alien.encode();
        await expectLater(syncB.synchronize(), throwsA(isA<LedgerException>()));
      } finally {
        await other.db.close();
      }
    },
  );
  test(
    'remote history removal is restored, never interpreted as a deletion',
    () async {
      final cat = await category(a);
      await entry(a, cat);
      await syncA.synchronize();
      remote.files.clear();
      final report = await syncA.synchronize();
      expect(report.uploaded, 2);
      expect(remote.files.length, 2);
    },
  );
  test('same-engine concurrent sync shares a single run', () async {
    await category(a);
    await Future.wait([syncA.synchronize(), syncA.synchronize()]);
    expect(remote.prepares, 1);
    expect(remote.files.length, 1);
  });
  test(
    'an archived category does not prevent retaining a historical conflict version',
    () async {
      final cat = await category(a);
      final original = await entry(a, cat);
      await syncA.synchronize();
      await syncB.synchronize();
      await edit(a, original, amount: 111);
      await edit(b, original, amount: 222);
      await syncA.synchronize();
      await syncB.synchronize();
      await syncA.synchronize();
      final view = (await a.snapshot()).singleWhere(
        (v) => v.current.entityId == original.entityId,
      );
      expect(view.hasConflict, true);
      await a.remove(EntityView([cat]));
      final keep = view.versions.first;
      await a.save(
        entityId: keep.entityId,
        type: keep.entityType,
        data: keep.data,
        expectedHeads: view.versions.map((o) => o.id).toList(),
        resolve: true,
      );
      final resolved = (await a.snapshot()).singleWhere(
        (v) => v.current.entityId == original.entityId,
      );
      expect(resolved.hasConflict, false);
      expect(resolved.current.data, keep.data);
    },
  );
  test(
    'three offline devices converge under randomized sync and resolution order',
    () async {
      final c = memoryRepository();
      try {
        await c.joinEmptyLedger(await a.ledgerId);
        final syncC = SyncEngine(c, remote, delay: (_) async {});
        final repos = [a, b, c], engines = [syncA, syncB, syncC];
        final cat = await category(a);
        final original = await entry(a, cat);
        for (final engine in engines) {
          await engine.synchronize();
        }
        final random = Random(173);
        for (var round = 0; round < 12; round++) {
          for (final repo in repos) {
            final view = (await repo.snapshot()).singleWhere(
              (v) => v.current.entityId == original.entityId,
            );
            final candidate =
                view.versions[random.nextInt(view.versions.length)];
            await repo.save(
              entityId: original.entityId,
              type: candidate.entityType,
              data: {
                ...candidate.data,
                'amountMinor': 1 + random.nextInt(99999),
              },
              expectedHeads: view.versions.map((v) => v.id).toList(),
              resolve: true,
            );
          }
          final order = engines.toList()..shuffle(random);
          for (final engine in order) {
            await engine.synchronize();
          }
          for (final engine in engines) {
            await engine.synchronize();
          }
          final heads = <String>[];
          for (final repo in repos) {
            final view = (await repo.snapshot()).singleWhere(
              (v) => v.current.entityId == original.entityId,
            );
            expect(view.hasConflict, true);
            heads.add(view.versions.map((v) => v.canonical).join('\n'));
          }
          expect(
            heads.toSet().length,
            1,
            reason: 'round $round must converge without losing heads',
          );
        }
      } finally {
        await c.db.close();
      }
    },
  );
}
