import 'dart:math';
import '../data/ledger_repository.dart';
import '../domain/operation.dart';
import 'webdav.dart';

class SyncReport {
  const SyncReport(this.downloaded, this.uploaded, this.conflicts);
  final int downloaded, uploaded, conflicts;
}

class SyncEngine {
  SyncEngine(
    this.repository,
    this.remote, {
    this.maxAttempts = 3,
    Future<void> Function(Duration)? delay,
  }) : delay = delay ?? Future<void>.delayed;
  final LedgerRepository repository;
  final OperationStore remote;
  final int maxAttempts;
  final Future<void> Function(Duration) delay;
  Future<SyncReport>? _active;

  Future<T> _retry<T>(Future<T> Function() action) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await action();
      } on DavException catch (error) {
        if (!error.retryable || attempt + 1 >= maxAttempts) rethrow;
        await delay(
          Duration(milliseconds: 250 * (1 << attempt) + Random().nextInt(100)),
        );
      }
    }
  }

  Future<SyncReport> synchronize() =>
      _active ??= _run().whenComplete(() => _active = null);

  Future<(Set<String>, int)> _pull() async {
    final ids = await _retry(remote.listIds);
    final known = await repository.knownIds();
    final batch = <Operation>[];
    for (final id in ids.difference(known)) {
      final op = Operation.decode(await _retry(() => remote.read(id)));
      if (op.id != id) throw const LedgerException('日志文件名与内容 ID 不一致');
      batch.add(op);
    }
    await repository.ingest(batch);
    return (ids, batch.length);
  }

  Future<SyncReport> _run() async {
    await _retry(remote.prepare);
    final (remoteIds, firstCount) = await _pull();
    final all = await repository.allOperations();
    final outbox = (await repository.allOperations(
      pendingOnly: true,
    )).map((o) => o.id).toSet();
    var uploaded = 0;
    final remaining = {for (final op in all) op.id: op};
    final published = <String>{};
    while (remaining.isNotEmpty) {
      final ready = remaining.values
          .where((o) => o.parents.every(published.contains))
          .toList();
      if (ready.isEmpty) throw const LedgerException('本地日志依赖不完整');
      for (final op in ready) {
        // Restore missing remote history rather than interpret absence as deletion.
        if (!remoteIds.contains(op.id) || outbox.contains(op.id)) {
          await _retry(() => remote.create(op));
          await repository.markPublished(op.id);
          uploaded++;
        }
        published.add(op.id);
        remaining.remove(op.id);
      }
    }
    final (_, secondCount) = await _pull();
    final conflicts = (await repository.snapshot())
        .where((e) => e.hasConflict)
        .length;
    return SyncReport(firstCount + secondCount, uploaded, conflicts);
  }
}
