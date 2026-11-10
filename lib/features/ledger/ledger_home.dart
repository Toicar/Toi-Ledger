import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/design_components.dart';
import '../../app/ledger_typography.dart';
import '../../app/providers.dart';
import '../../app/ui_common.dart';
import '../../app/presentation_controller.dart';
import '../../domain/ledger_statistics.dart';
import '../../domain/operation.dart';
import '../../data/ledger_repository.dart';
import '../../sync/sync_engine.dart';
import '../../sync/webdav.dart';
import '../conflicts/conflict_dialog.dart';
import '../statistics/statistics_page.dart';
import 'entry_editor.dart';
import 'ledger_overview.dart';

class LedgerHome extends ConsumerStatefulWidget {
  const LedgerHome({super.key});
  @override
  ConsumerState<LedgerHome> createState() => _LedgerHomeState();
}

class _LedgerHomeState extends ConsumerState<LedgerHome>
    with WidgetsBindingObserver {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  final search = TextEditingController();
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
    search.dispose();
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

  Future<void> page(String route) async {
    await Navigator.of(context).pushNamed(route);
    if (mounted) unawaited(sync(silent: true));
  }

  Future<void> statistics() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/statistics'),
        builder: (_) => StatisticsPage(initialMonth: month),
      ),
    );
  }

  void shift(int delta) {
    final next = DateTime(month.year, month.month + delta);
    if (next.year >= 1900 && next.year <= 2200) setState(() => month = next);
  }

  Future<void> remove(EntityView view) async {
    if (!await confirmDelete(context)) return;
    try {
      await ref.read(repositoryProvider).remove(view);
      if (mounted) unawaited(sync(silent: true));
    } catch (e) {
      if (mounted) notify(context, safeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(syncRequestProvider, (_, next) => unawaited(sync(silent: true)));
    final state = ref.watch(entitiesProvider);
    final hidden = ref.watch(presentationProvider).hideAmounts;
    final scheme = Theme.of(context).colorScheme;
    final desktop = MediaQuery.sizeOf(context).width >= 1000;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          final views = state.asData?.value;
          if (views != null) entry(views);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: desktop
                ? Text(
                    '个人空间  /  我的账本',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LedgerMark(size: 25),
                        const SizedBox(width: 7),
                        Text(
                          'MyLedger',
                          style: TextStyle(
                            fontFamily: LedgerTypography.of(
                              context,
                            ).englishTitleFamily,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
            titleSpacing: desktop ? 32 : 12,
            actions: [
              if (!desktop) ...[
                IconButton(
                  tooltip: '外观',
                  icon: const Icon(Icons.palette_outlined),
                  onPressed: () => page('/appearance'),
                ),
                IconButton(
                  tooltip: '分类管理',
                  icon: const Icon(Icons.grid_view_rounded),
                  onPressed: () => page('/categories'),
                ),
                IconButton(
                  tooltip: '同步设置',
                  icon: const Icon(Icons.cloud_outlined),
                  onPressed: () => page('/settings'),
                ),
              ],
              IconButton(
                tooltip: '立即同步',
                onPressed: syncing ? null : () => sync(),
                icon: syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    : const Icon(Icons.sync_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(safeError(error)),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(entitiesProvider),
                    child: const Text('重新加载'),
                  ),
                ],
              ),
            ),
            data: (views) {
              final key =
                  '${month.year}-${month.month.toString().padLeft(2, '0')}';
              final total = LedgerRepository.monthly(views, key);
              final stats = LedgerStatistics.forMonth(
                views,
                month,
                uncategorizedThresholdMinor: ref
                    .watch(presentationProvider)
                    .uncategorizedThresholdMinor,
              );
              final categories = {
                for (final v in views.where(
                  (v) => v.current.entityType == EntityType.category,
                ))
                  v.current.entityId: v,
              };
              String label(Operation op) {
                if (op.data['categoryId'] == null) return '未分类';
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
                              (o) => (o.data['date'] as String).startsWith(
                                '$key-',
                              ),
                            ) &&
                            (kind == 'all' || v.current.data['kind'] == kind) &&
                            ('${v.current.data['note']} ${label(v.current)}'
                                .toLowerCase()
                                .contains(query.trim().toLowerCase())),
                      )
                      .toList()
                    ..sort((a, b) {
                      final order = (b.current.data['date'] as String)
                          .compareTo(a.current.data['date'] as String);
                      return order != 0
                          ? order
                          : a.current.entityId.compareTo(b.current.entityId);
                    });
              final groups = <String, List<EntityView>>{};
              for (final entry in entries) {
                (groups[entry.current.data['date'] as String] ??= []).add(
                  entry,
                );
              }
              final groupDates = groups.keys.toList();
              final hasCategories = categories.values.any(
                (v) => !v.current.deleted && !v.hasConflict,
              );
              final conflicts = views.where((v) => v.hasConflict).toList();
              return LayoutBuilder(
                builder: (context, constraints) {
                  final wide =
                      constraints.maxWidth >= 940 &&
                      MediaQuery.textScalerOf(context).scale(1) < 1.4;
                  final inset = desktop ? 32.0 : 16.0;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1450),
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(inset, 20, inset, 0),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: PageHeading(
                                          eyebrow: 'A LITTLE EVERY DAY',
                                          title: '每一笔，都是生活。',
                                          description: '把收支理清，让日子从容。',
                                        ),
                                      ),
                                      if (wide)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 24),
                                          child: LedgerStillLife(size: 120),
                                        ),
                                    ],
                                  ),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 16,
                                    runSpacing: 12,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: '上个月',
                                            onPressed:
                                                month.year == 1900 &&
                                                    month.month == 1
                                                ? null
                                                : () => shift(-1),
                                            icon: const Icon(
                                              Icons.chevron_left,
                                              size: 20,
                                            ),
                                          ),
                                          Flexible(
                                            child: TextButton(
                                              onPressed: () async {
                                                final selected =
                                                    await showDatePicker(
                                                      context: context,
                                                      initialDate: month,
                                                      firstDate: DateTime(1900),
                                                      lastDate: DateTime(
                                                        2200,
                                                        12,
                                                        31,
                                                      ),
                                                    );
                                                if (selected != null &&
                                                    mounted) {
                                                  setState(
                                                    () => month = DateTime(
                                                      selected.year,
                                                      selected.month,
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Text(
                                                '${month.year} 年 ${month.month} 月',
                                                style: TextStyle(
                                                  color: scheme.onSurface,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: '下个月',
                                            onPressed:
                                                month.year == 2200 &&
                                                    month.month == 12
                                                ? null
                                                : () => shift(1),
                                            icon: const Icon(
                                              Icons.chevron_right,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: statistics,
                                            icon: const Icon(
                                              Icons.bar_chart_rounded,
                                              size: 17,
                                            ),
                                            label: const Text('统计分析'),
                                          ),
                                          if (!desktop)
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  page('/templates'),
                                              icon: const Icon(
                                                Icons.bolt_outlined,
                                                size: 17,
                                              ),
                                              label: const Text('快捷模板'),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  LedgerOverview(
                                    income: total.income,
                                    expense: total.expense,
                                    balance: total.balance,
                                    conflicts: total.conflicts,
                                  ),
                                  const SizedBox(height: 18),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            status.startsWith('同步未完成')
                                                ? Icons.cloud_off_outlined
                                                : Icons
                                                      .check_circle_outline_rounded,
                                            size: 13,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      FutureBuilder<List<Operation>>(
                                        future: ref
                                            .read(repositoryProvider)
                                            .allOperations(pendingOnly: true),
                                        builder: (_, snapshot) => Text(
                                          '本地待上传：${snapshot.data?.length ?? '…'} 条',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (conflicts.isNotEmpty)
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.warning_amber_rounded,
                                      ),
                                      label: Text(
                                        '处理全部冲突（${conflicts.length}）',
                                      ),
                                      onPressed: () async {
                                        for (final conflict in conflicts) {
                                          if (!context.mounted) break;
                                          await resolveConflict(
                                            context,
                                            ref,
                                            conflict,
                                          );
                                        }
                                        if (mounted) {
                                          unawaited(sync(silent: true));
                                        }
                                      },
                                    ),
                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(inset, 0, inset, 110),
                            sliver: SliverToBoxAdapter(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '收支明细',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              '${entries.length} 笔',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: search,
                                                decoration: InputDecoration(
                                                  labelText: '搜索备注或分类',
                                                  prefixIcon: const Icon(
                                                    Icons.search_rounded,
                                                    size: 20,
                                                  ),
                                                  suffixIcon: query.isEmpty
                                                      ? null
                                                      : IconButton(
                                                          tooltip: '清除搜索',
                                                          onPressed: () {
                                                            search.clear();
                                                            setState(
                                                              () => query = '',
                                                            );
                                                          },
                                                          icon: const Icon(
                                                            Icons.close,
                                                            size: 16,
                                                          ),
                                                        ),
                                                ),
                                                onChanged: (value) => setState(
                                                  () => query = value,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: scheme.outlineVariant,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                color: scheme.surface,
                                              ),
                                              child:
                                                  DropdownButtonHideUnderline(
                                                    child:
                                                        DropdownButton<String>(
                                                          value: kind,
                                                          items: const [
                                                            DropdownMenuItem(
                                                              value: 'all',
                                                              child: Text('全部'),
                                                            ),
                                                            DropdownMenuItem(
                                                              value: 'expense',
                                                              child: Text('支出'),
                                                            ),
                                                            DropdownMenuItem(
                                                              value: 'income',
                                                              child: Text('收入'),
                                                            ),
                                                          ],
                                                          onChanged: (value) {
                                                            if (value != null) {
                                                              setState(
                                                                () => kind =
                                                                    value,
                                                              );
                                                            }
                                                          },
                                                        ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        if (entries.isEmpty)
                                          Card(
                                            child: LedgerEmptyState(
                                              filtered:
                                                  query.isNotEmpty ||
                                                  kind != 'all',
                                              hasCategories: hasCategories,
                                              onCreate: () => entry(views),
                                              onReset: () {
                                                search.clear();
                                                setState(() {
                                                  query = '';
                                                  kind = 'all';
                                                });
                                              },
                                            ),
                                          )
                                        else ...[
                                          // Render slivers separately below on narrow screens in future
                                          // pagination; records currently derive from the local snapshot.
                                          for (final date in groupDates) ...[
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    2,
                                                    12,
                                                    2,
                                                    12,
                                                  ),
                                              child: Text(
                                                _dateLabel(date),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                            Card(
                                              child: Column(
                                                children: [
                                                  for (
                                                    var i = 0;
                                                    i < groups[date]!.length;
                                                    i++
                                                  ) ...[
                                                    if (i > 0)
                                                      const Divider(
                                                        indent: 20,
                                                        endIndent: 20,
                                                      ),
                                                    _EntryRow(
                                                      view: groups[date]![i],
                                                      category: label(
                                                        groups[date]![i]
                                                            .current,
                                                      ),
                                                      hidden: hidden,
                                                      onEdit: () => entry(
                                                        views,
                                                        groups[date]![i],
                                                      ),
                                                      onDelete: () => remove(
                                                        groups[date]![i],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (wide) ...[
                                    const SizedBox(width: 24),
                                    SizedBox(
                                      width: 272,
                                      child: _MonthNotes(
                                        statistics: stats,
                                        hidden: hidden,
                                        onStatistics: statistics,
                                        onTemplates: () => page('/templates'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: desktop
              ? null
              : FloatingActionButton.extended(
                  onPressed: state.asData == null
                      ? null
                      : () => entry(state.requireValue),
                  label: const Text('记一笔'),
                  icon: const Icon(Icons.add, size: 20),
                ),
        ),
      ),
    );
  }
}

String _dateLabel(String date) {
  final parsed = DateTime.parse(date), now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final prefix = parsed == today
      ? '今天 · '
      : parsed == DateTime(now.year, now.month, now.day - 1)
      ? '昨天 · '
      : '';
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  return '$prefix${parsed.month} 月 ${parsed.day} 日  星期${weekdays[parsed.weekday - 1]}';
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.view,
    required this.category,
    required this.hidden,
    required this.onEdit,
    required this.onDelete,
  });
  final EntityView view;
  final String category;
  final bool hidden;
  final VoidCallback onEdit, onDelete;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final op = view.current;
    final income = op.data['kind'] == 'income';
    final note = op.data['note'] as String;
    final color = income ? scheme.secondary : scheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3;
            final amount = Text(
              hidden
                  ? '••••'
                  : '${income ? '+' : '−'} ${ledgerMoney(op.data['amountMinor'] as int)}',
              style: LedgerTypography.of(context).number(
                size: 19,
                color: income ? scheme.secondary : scheme.onSurface,
              ),
              maxLines: compact ? null : 1,
            );
            final title = view.hasConflict
                ? '待处理冲突 · ${view.versions.length} 个版本'
                : category;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!compact) ...[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      view.hasConflict
                          ? Icons.warning_amber_rounded
                          : categoryIcon(category, income: income),
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (compact) ...[const SizedBox(height: 7), amount],
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: amount,
                    ),
                  ),
                ],
                if (!view.hasConflict)
                  IconButton(
                    tooltip: '删除',
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 17,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MonthNotes extends StatelessWidget {
  const _MonthNotes({
    required this.statistics,
    required this.hidden,
    required this.onStatistics,
    required this.onTemplates,
  });
  final LedgerStatistics statistics;
  final bool hidden;
  final VoidCallback onStatistics, onTemplates;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('账本手记', style: theme.textTheme.titleLarge),
        const SizedBox(height: 18),
        PaperPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('支出去向', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('看见每一笔的分量', style: theme.textTheme.bodySmall),
              const SizedBox(height: 24),
              if (hidden)
                const Text('金额已隐藏')
              else if (statistics.categoryExpenses.isEmpty) ...[
                const LedgerStillLife(size: 100),
                const SizedBox(height: 10),
                Text('第一笔支出之后，\n这里会慢慢有了故事。', style: theme.textTheme.bodySmall),
              ] else
                for (final category in statistics.categoryExpenses.take(4)) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(category.share * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: category.share,
                      minHeight: 5,
                      color: scheme.primary.withValues(alpha: .8),
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onStatistics,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                label: const Text('查看完整报告', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PaperPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.bolt_outlined, color: scheme.primary, size: 22),
              const SizedBox(height: 14),
              Text('让日常，再简单一点。', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '早餐、通勤、每月房租。\n常用收支，存成快捷模板。',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onTemplates,
                child: const Text('管理快捷模板', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
