import 'dart:io';
import 'dart:math';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/data/database.dart';
import 'package:my_ledger/data/ledger_repository.dart';
import 'package:my_ledger/domain/operation.dart';
import 'support.dart';

void main() {
  late LedgerRepository repo;
  setUp(() => repo = memoryRepository());
  tearDown(() => repo.db.close());
  test('CRUD, category validation, month totals and tombstones', () async {
    final cat = await category(repo);
    final income = await category(repo, kind: 'income');
    final first = await entry(repo, cat);
    await entry(repo, income, amount: 10000);
    await entry(repo, cat, amount: 500, date: '2026-09-30');
    final changed = await edit(repo, first, amount: 2500);
    var totals = LedgerRepository.monthly(await repo.snapshot(), '2026-10');
    expect(totals.income, 10000);
    expect(totals.expense, 2500);
    expect(totals.balance, 7500);
    await repo.remove(EntityView([changed]));
    totals = LedgerRepository.monthly(await repo.snapshot(), '2026-10');
    expect(totals.expense, 0);
    expect((await repo.allOperations()).length, 7);
    await repo.remove(EntityView([cat]));
    await expectLater(entry(repo, cat), throwsA(isA<LedgerException>()));
  });
  test('stale edits and changing ledger after writing are rejected', () async {
    final cat = await category(repo);
    final op = await entry(repo, cat);
    await edit(repo, op);
    await expectLater(
      edit(repo, op, amount: 99),
      throwsA(isA<LedgerException>()),
    );
    await expectLater(
      repo.joinEmptyLedger(uuid.v4()),
      throwsA(isA<LedgerException>()),
    );
  });
  test(
    'ingest is atomic and enforces parent entity, ledger and content identity',
    () async {
      final cat = await category(repo);
      final bad = Operation(
        id: uuid.v4(),
        ledgerId: await repo.ledgerId,
        deviceId: uuid.v4(),
        entityId: uuid.v4(),
        entityType: EntityType.category,
        parents: [cat.id],
        data: {'name': '错误实体', 'kind': 'expense'},
        deleted: false,
        createdAt: '2026-10-21T00:00:00.000Z',
      );
      final good = Operation(
        id: uuid.v4(),
        ledgerId: await repo.ledgerId,
        deviceId: uuid.v4(),
        entityId: uuid.v4(),
        entityType: EntityType.category,
        parents: [],
        data: {'name': '不会提交', 'kind': 'expense'},
        deleted: false,
        createdAt: '2026-10-21T00:00:00.000Z',
      );
      await expectLater(
        repo.ingest([good, bad]),
        throwsA(isA<LedgerException>()),
      );
      expect((await repo.allOperations()).length, 1);
      await repo.ingest([cat, cat]);
      expect((await repo.allOperations()).length, 1);
      final collision = Operation(
        id: cat.id,
        ledgerId: cat.ledgerId,
        deviceId: cat.deviceId,
        entityId: cat.entityId,
        entityType: cat.entityType,
        parents: [],
        data: {'name': '碰撞', 'kind': 'expense'},
        deleted: false,
        createdAt: cat.createdAt,
      );
      await expectLater(
        repo.ingest([collision]),
        throwsA(isA<LedgerException>()),
      );
    },
  );
  test('unordered log replay is deterministic across permutations', () async {
    final cat = await category(repo);
    final first = await entry(repo, cat);
    final second = await edit(repo, first);
    await edit(repo, second, amount: 999);
    final operations = await repo.allOperations();
    for (var seed = 0; seed < 12; seed++) {
      final other = memoryRepository();
      try {
        await other.joinEmptyLedger(await repo.ledgerId);
        await other.ingest(operations.toList()..shuffle(Random(seed)));
        final head = (await other.snapshot()).singleWhere(
          (v) => v.current.entityType == EntityType.entry,
        );
        expect(head.current.data['amountMinor'], 999);
        expect(head.hasConflict, false);
      } finally {
        await other.db.close();
      }
    }
  });
  test(
    'database reopening preserves identity, pending log and heads',
    () async {
      final dir = await Directory.systemTemp.createTemp('myledger-test-');
      final file = File('${dir.path}/test.sqlite');
      final first = LedgerRepository(LedgerDatabase(NativeDatabase(file)));
      final id = await first.ledgerId;
      final device = await first.deviceId;
      await category(first);
      await first.db.close();
      final reopened = LedgerRepository(LedgerDatabase(NativeDatabase(file)));
      try {
        expect(await reopened.ledgerId, id);
        expect(await reopened.deviceId, device);
        expect((await reopened.allOperations(pendingOnly: true)).length, 1);
        expect((await reopened.snapshot()).length, 1);
        final fk = await reopened.db
            .customSelect('PRAGMA foreign_keys')
            .getSingle();
        expect(fk.read<int>('foreign_keys'), 1);
      } finally {
        await reopened.db.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
