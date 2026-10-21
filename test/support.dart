import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';
import 'package:my_ledger/data/database.dart';
import 'package:my_ledger/data/ledger_repository.dart';
import 'package:my_ledger/domain/operation.dart';
import 'package:my_ledger/sync/webdav.dart';

const uuid = Uuid();
LedgerRepository memoryRepository() =>
    LedgerRepository(LedgerDatabase(NativeDatabase.memory()));
Future<Operation> category(
  LedgerRepository repo, {
  String kind = 'expense',
  String name = '测试分类',
}) => repo.save(type: EntityType.category, data: {'name': name, 'kind': kind});
Future<Operation> entry(
  LedgerRepository repo,
  Operation cat, {
  int amount = 1234,
  String date = '2026-10-21',
}) => repo.save(
  type: EntityType.entry,
  data: {
    'amountMinor': amount,
    'kind': cat.data['kind'],
    'categoryId': cat.entityId,
    'date': date,
    'note': '合成测试记录',
  },
);
Future<Operation> edit(
  LedgerRepository repo,
  Operation op, {
  int amount = 2345,
  bool deleted = false,
}) => repo.save(
  entityId: op.entityId,
  type: op.entityType,
  data: {...op.data, 'amountMinor': amount},
  deleted: deleted,
  expectedHeads: [op.id],
);

class MemoryRemote implements OperationStore {
  final files = <String, String>{};
  int reads = 0, writes = 0, prepares = 0;
  int failWrites = 0;
  bool failAfterCommit = false;
  @override
  Future<void> prepare() async {
    prepares++;
  }

  @override
  Future<Set<String>> listIds() async => files.keys.toSet();
  @override
  Future<String> read(String id) async {
    reads++;
    return files[id]!;
  }

  @override
  Future<void> create(Operation op) async {
    writes++;
    if (failWrites > 0) {
      failWrites--;
      throw const DavException('模拟断网', retryable: true);
    }
    if (files.containsKey(op.id) && files[op.id] != op.encode()) {
      throw const DavException('模拟同名冲突');
    }
    files[op.id] = op.encode();
    if (failAfterCommit) {
      failAfterCommit = false;
      throw const DavException('模拟响应丢失', retryable: true);
    }
  }
}
