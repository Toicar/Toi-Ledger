import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../domain/operation.dart';
import 'database.dart';

class LedgerRepository {
  LedgerRepository(this.db);
  final LedgerDatabase db;
  static const _uuid = Uuid();

  Future<String> _identity(String key) => db.transaction(() async {
    final row = await (db.select(
      db.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row != null) return row.value;
    final value = _uuid.v4();
    await db
        .into(db.settings)
        .insert(SettingsCompanion.insert(key: key, value: value));
    return value;
  });
  Future<String> get ledgerId => _identity('ledgerId');
  Future<String> get deviceId => _identity('deviceId');

  Future<void> joinEmptyLedger(String id) => db.transaction(() async {
    requireUuid(id);
    if ((await db.select(db.operationRows).get()).isNotEmpty) {
      throw const LedgerException('只有空账本可以加入其他账本，请勿清空现有数据');
    }
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: 'ledgerId', value: id),
        );
  });

  Future<Operation?> operation(String id) async {
    final row = await (db.select(
      db.operationRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : Operation.decode(row.body);
  }

  Future<List<Operation>> allOperations({bool pendingOnly = false}) async {
    final query = db.select(db.operationRows);
    if (pendingOnly) query.where((t) => t.pending.equals(true));
    return (await query.get()).map((r) => Operation.decode(r.body)).toList();
  }

  Future<Set<String>> knownIds() async =>
      (await db.select(db.operationRows).get()).map((r) => r.id).toSet();
  Future<void> markPublished(String id) async {
    await (db.update(db.operationRows)..where((t) => t.id.equals(id))).write(
      const OperationRowsCompanion(pending: Value(false)),
    );
  }

  JoinedSelectStatement<HasResultSet, dynamic> _headQuery() =>
      db.select(db.headRows).join([
        innerJoin(
          db.operationRows,
          db.operationRows.id.equalsExp(db.headRows.opId),
        ),
      ]);
  List<EntityView> _views(List<TypedResult> rows) {
    final grouped = <String, List<Operation>>{};
    for (final row in rows) {
      final op = Operation.decode(row.readTable(db.operationRows).body);
      (grouped[op.entityId] ??= []).add(op);
    }
    return grouped.values.map(EntityView.new).toList();
  }

  Future<List<EntityView>> snapshot() async => _views(await _headQuery().get());
  Stream<List<EntityView>> watch() => _headQuery().watch().map(_views);
  Future<List<Operation>> _heads(String id) async => (await snapshot())
      .where((v) => v.current.entityId == id)
      .expand((v) => v.versions)
      .toList();

  /// A batch is atomic, including its operation log and materialized heads.
  Future<void> ingest(List<Operation> incoming) => db.transaction(() async {
    final ledger = await ledgerId;
    final known = {for (final op in await allOperations()) op.id: op};
    final pending = <String, Operation>{};
    for (final op in incoming) {
      if (op.ledgerId != ledger) throw const LedgerException('日志属于其他账本');
      final previous = known[op.id] ?? pending[op.id];
      if (previous != null && previous.canonical != op.canonical) {
        throw const LedgerException('相同操作 ID 对应不同内容，已停止同步');
      }
      if (!known.containsKey(op.id)) pending[op.id] = op;
    }
    while (pending.isNotEmpty) {
      final ready = pending.values
          .where((o) => o.parents.every(known.containsKey))
          .toList();
      if (ready.isEmpty) throw const LedgerException('日志缺少父版本或包含循环，请稍后重试');
      for (final op in ready) {
        for (final parentId in op.parents) {
          final parent = known[parentId]!;
          if (parent.entityId != op.entityId ||
              parent.entityType != op.entityType ||
              (parent.data['kind'] != op.data['kind'] &&
                  !(op.entityType == EntityType.category &&
                      op.protocolVersion == 3))) {
            throw const LedgerException('父版本的实体或收支类型不一致');
          }
        }
        if (known.values
            .where((p) => p.entityId == op.entityId)
            .any(
              (p) =>
                  p.entityType != op.entityType ||
                  (p.data['kind'] != op.data['kind'] &&
                      (op.entityType == EntityType.entry ||
                          op.parents.isEmpty)),
            )) {
          throw const LedgerException('实体类型或收支类型不可变');
        }
        await _insert(op, pending: false);
        known[op.id] = op;
        pending.remove(op.id);
      }
    }
  });

  Future<void> _insert(Operation op, {required bool pending}) async {
    await db
        .into(db.operationRows)
        .insert(
          OperationRowsCompanion.insert(
            id: op.id,
            entityId: op.entityId,
            entityType: op.entityType.name,
            body: op.encode(),
            pending: pending,
          ),
        );
    if (op.parents.isNotEmpty) {
      await (db.delete(
        db.headRows,
      )..where((t) => t.opId.isIn(op.parents))).go();
    }
    await db
        .into(db.headRows)
        .insert(HeadRowsCompanion.insert(opId: op.id, entityId: op.entityId));
  }

  Future<Operation> save({
    String? entityId,
    required EntityType type,
    required Map<String, dynamic> data,
    bool deleted = false,
    List<String>? expectedHeads,
    bool resolve = false,
  }) => db.transaction(() async {
    final id = entityId ?? _uuid.v4();
    final heads = await _heads(id);
    if (heads.isNotEmpty && expectedHeads == null) {
      throw const LedgerException('编辑需要原始版本，请刷新后重试');
    }
    final actual = heads.map((o) => o.id).toSet();
    if (expectedHeads != null &&
        (actual.length != expectedHeads.length ||
            !actual.containsAll(expectedHeads))) {
      throw const LedgerException('账目已发生变化，请刷新后重试');
    }
    if (heads.length > 1 && !resolve) throw const LedgerException('请先处理冲突');
    if (heads.any(
      (h) =>
          h.entityType != type ||
          (type == EntityType.entry && h.data['kind'] != data['kind']),
    )) {
      throw const LedgerException('已有记录的收支类型不可修改');
    }
    final preservesExistingVersion =
        resolve &&
        heads.any(
          (head) =>
              head.deleted == deleted &&
              canonicalJson(head.data) == canonicalJson(data),
        );
    if (type == EntityType.entry &&
        !deleted &&
        !preservesExistingVersion &&
        data['categoryId'] != null) {
      final categories = await _heads(requireUuid(data['categoryId']));
      // Reclassifying a category does not rewrite historical bill directions.
      final keepsHistoricalCategory = heads.any(
        (head) =>
            head.data['categoryId'] == data['categoryId'] &&
            head.data['kind'] == data['kind'],
      );
      if (categories.length != 1 ||
          categories.single.deleted ||
          categories.single.entityType != EntityType.category ||
          (categories.single.data['kind'] != data['kind'] &&
              !keepsHistoricalCategory)) {
        throw const LedgerException('请选择有效且无冲突的同类型分类');
      }
    }
    final op = Operation(
      id: _uuid.v4(),
      ledgerId: await ledgerId,
      deviceId: await deviceId,
      entityId: id,
      entityType: type,
      parents: actual.toList(),
      data: data,
      deleted: deleted,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      protocolVersion:
          type == EntityType.category &&
              heads.any((head) => head.data['kind'] != data['kind'])
          ? 3
          : null,
    );
    await _insert(op, pending: true);
    return op;
  });
  Future<void> remove(EntityView entity) async {
    await save(
      entityId: entity.current.entityId,
      type: entity.current.entityType,
      data: entity.current.data,
      deleted: true,
      expectedHeads: entity.versions.map((o) => o.id).toList(),
    );
  }

  static MonthlyTotal monthly(List<EntityView> views, String month) {
    var income = 0, expense = 0, conflicts = 0;
    for (final view in views.where(
      (v) => v.current.entityType == EntityType.entry,
    )) {
      if (view.hasConflict) {
        if (view.versions.any(
          (v) => (v.data['date'] as String).startsWith('$month-'),
        )) {
          conflicts++;
        }
        continue;
      }
      final op = view.current;
      if (op.deleted || !(op.data['date'] as String).startsWith('$month-')) {
        continue;
      }
      if (op.data['kind'] == 'income') {
        income += op.data['amountMinor'] as int;
      } else {
        expense += op.data['amountMinor'] as int;
      }
    }
    return MonthlyTotal(income, expense, conflicts);
  }
}
