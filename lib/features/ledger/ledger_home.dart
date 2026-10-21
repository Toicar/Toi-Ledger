import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/ui_common.dart';
import '../../domain/operation.dart';
import '../../data/ledger_repository.dart';
import '../../sync/sync_engine.dart';
import '../../sync/webdav.dart';
import '../categories/categories_page.dart';
import '../conflicts/conflict_dialog.dart';
import '../sync/settings_page.dart';
import 'entry_editor.dart';

class LedgerHome extends ConsumerStatefulWidget {
  const LedgerHome({super.key});
  @override
  ConsumerState<LedgerHome> createState() => _LedgerHomeState();
}

class _LedgerHomeState extends ConsumerState<LedgerHome>
    with WidgetsBindingObserver {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String query = '', kind = 'all', status = '离线可用 · 尚未同步';
  bool syncing = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(sync(silent: true)),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(sync(silent: true)),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(sync(silent: true));
  }

  Future<void> sync({bool silent = false}) async {
    if (syncing || !mounted || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    setState(() => syncing = true);
    WebDavStore? remote;
    try {
      final config = await ref.read(credentialProvider).read();
      if (config == null) {
        if (!silent && mounted) notify(context, '请先在同步设置中配置 WebDAV');
        return;
      }
      final repo = ref.read(repositoryProvider);
      remote = WebDavStore(config, await repo.ledgerId);
      final result = await SyncEngine(repo, remote).synchronize();
      if (mounted) {
        setState(
          () => status =
              '同步完成 · 下载 ${result.downloaded} / 上传 ${result.uploaded} · 冲突 ${result.conflicts}',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => status = '同步未完成 · ${safeError(error)}');
        if (!silent) notify(context, status);
      }
    } finally {
      remote?.close();
      if (mounted) setState(() => syncing = false);
    }
  }

  Future<void> entry(List<EntityView> views, [EntityView? existing]) async {
    if (existing?.hasConflict ?? false) {
      await resolveConflict(context, ref, existing!);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => EntryEditor(views: views, existing: existing),
    );
    if (mounted) unawaited(sync(silent: true));
  }

  void shift(int delta) {
    final next = DateTime(month.year, month.month + delta);
    if (next.year >= 1900 && next.year <= 2200) setState(() => month = next);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(entitiesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyLedger'),
        actions: [
          IconButton(
            tooltip: '分类管理',
            icon: const Icon(Icons.category_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CategoriesPage()),
              );
              if (mounted) unawaited(sync(silent: true));
            },
          ),
          IconButton(
            tooltip: '同步设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: syncing
                ? null
                : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsPage(),
                      ),
                    );
                    if (mounted) unawaited(sync(silent: true));
                  },
          ),
          IconButton(
            tooltip: '立即同步',
            onPressed: syncing ? null : () => sync(),
            icon: syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(safeError(e))),
        data: (views) {
          final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
          final total = LedgerRepository.monthly(views, key);
          final categories = {
            for (final v in views.where(
              (v) => v.current.entityType == EntityType.category,
            ))
              v.current.entityId: v,
          };
          String label(Operation op) {
            final category = categories[op.data['categoryId']];
            if (category == null) return '分类待同步';
            if (category.hasConflict) return '分类有冲突';
            return '${category.current.data['name']}${category.current.deleted ? '（已归档）' : ''}';
          }

          final entries =
              views
                  .where(
                    (v) =>
                        v.current.entityType == EntityType.entry &&
                        (v.hasConflict || !v.current.deleted) &&
                        v.versions.any(
                          (o) => (o.data['date'] as String).startsWith('$key-'),
                        ) &&
                        (kind == 'all' || v.current.data['kind'] == kind) &&
                        ('${v.current.data['note']} ${label(v.current)}'
                            .toLowerCase()
                            .contains(query.toLowerCase())),
                  )
                  .toList()
                ..sort((a, b) {
                  final order = (b.current.data['date'] as String).compareTo(
                    a.current.data['date'] as String,
                  );
                  return order != 0
                      ? order
                      : a.current.entityId.compareTo(b.current.entityId);
                });
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: '上个月',
                          onPressed: () => shift(-1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        TextButton(
                          onPressed: () async {
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: month,
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2200, 12, 31),
                            );
                            if (selected != null && mounted) {
                              setState(
                                () => month = DateTime(
                                  selected.year,
                                  selected.month,
                                ),
                              );
                            }
                          },
                          child: Text(
                            key,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: '下个月',
                          onPressed: () => shift(1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          Text('收入 ¥${formatAmount(total.income)}'),
                          Text('支出 ¥${formatAmount(total.expense)}'),
                          Text('结余 ¥${formatAmount(total.balance)}'),
                          if (total.conflicts > 0)
                            Text(
                              '${total.conflicts} 笔冲突未计入合计',
                              style: const TextStyle(color: Colors.deepOrange),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      status,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  FutureBuilder<List<Operation>>(
                    future: ref
                        .read(repositoryProvider)
                        .allOperations(pendingOnly: true),
                    builder: (_, s) => Text(
                      '本地待上传：${s.data?.length ?? '…'} 条',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (views.any((v) => v.hasConflict))
                    TextButton.icon(
                      icon: const Icon(Icons.warning_amber),
                      label: Text(
                        '处理全部冲突（${views.where((v) => v.hasConflict).length}）',
                      ),
                      onPressed: () async {
                        final conflicts = views
                            .where((v) => v.hasConflict)
                            .toList();
                        for (final conflict in conflicts) {
                          if (!context.mounted) break;
                          await resolveConflict(context, ref, conflict);
                        }
                        if (mounted) unawaited(sync(silent: true));
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: '搜索备注或分类',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (s) => setState(() => query = s),
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: kind,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('全部')),
                            DropdownMenuItem(
                              value: 'expense',
                              child: Text('支出'),
                            ),
                            DropdownMenuItem(
                              value: 'income',
                              child: Text('收入'),
                            ),
                          ],
                          onChanged: (v) => setState(() => kind = v!),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: entries.isEmpty
                        ? const Center(child: Text('暂无记录，点击右下角记一笔'))
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: entries.length,
                            itemBuilder: (_, i) {
                              final v = entries[i], op = v.current;
                              return ListTile(
                                onTap: () => entry(views, v),
                                leading: Icon(
                                  v.hasConflict
                                      ? Icons.warning_amber
                                      : (op.data['kind'] == 'income'
                                            ? Icons.south_west
                                            : Icons.north_east),
                                ),
                                title: Text(
                                  v.hasConflict
                                      ? '待处理冲突 · ${v.versions.length} 个版本'
                                      : '${label(op)} · ¥${formatAmount(op.data['amountMinor'] as int)}',
                                ),
                                subtitle: Text(
                                  '${op.data['date']}  ${op.data['note']}',
                                ),
                                trailing: v.hasConflict
                                    ? null
                                    : IconButton(
                                        tooltip: '删除',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () async {
                                          if (await confirmDelete(context)) {
                                            try {
                                              await ref
                                                  .read(repositoryProvider)
                                                  .remove(v);
                                              if (mounted) {
                                                unawaited(sync(silent: true));
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                notify(context, safeError(e));
                                              }
                                            }
                                          }
                                        },
                                      ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.valueOrNull == null
            ? null
            : () => entry(state.valueOrNull!),
        label: const Text('记一笔'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
