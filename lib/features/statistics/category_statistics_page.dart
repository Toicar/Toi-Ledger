import '../../l10n/statistics_labels.dart';
import '../../l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/presentation_controller.dart';
import '../../app/design_components.dart';
import '../../app/ledger_typography.dart';
import '../../app/ui_common.dart';
import '../../domain/ledger_statistics.dart';
import '../../domain/operation.dart';
import '../ledger/entry_editor.dart';
import 'statistics_controls.dart';
import 'trend_chart.dart';

class CategoryStatisticsPage extends ConsumerStatefulWidget {
  const CategoryStatisticsPage({
    super.key,
    required this.groupId,
    required this.label,
    required this.range,
    required this.income,
  });
  final String groupId, label;
  final StatisticsRange range;
  final bool income;
  @override
  ConsumerState<CategoryStatisticsPage> createState() =>
      _CategoryStatisticsPageState();
}

class _CategoryStatisticsPageState
    extends ConsumerState<CategoryStatisticsPage> {
  final search = TextEditingController();
  String query = '';
  bool largestFirst = false;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(presentationProvider);
    final hidden = settings.hideAmounts;
    final theme = Theme.of(context);
    String money(int amount) => hidden ? '••••' : statisticsMoney(amount);
    return Scaffold(
      key: const ValueKey('category-statistics-page'),
      appBar: AppBar(
        title: Text(context.l10n.categoryBreakdown),
        actions: [
          IconButton(
            tooltip: hidden
                ? context.l10n.showAmounts
                : context.l10n.hideAmounts,
            icon: Icon(
              hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () async {
              try {
                await ref
                    .read(presentationProvider.notifier)
                    .setHideAmounts(!hidden);
              } catch (error) {
                if (context.mounted) notify(context, safeError(error, context));
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.close),
          ),
        ],
      ),
      body: ref
          .watch(entitiesProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(safeError(error, context))),
            data: (views) {
              final all = LedgerStatistics.forPeriod(
                views,
                widget.range.start,
                widget.range.period,
                uncategorizedThresholdMinor:
                    settings.uncategorizedThresholdMinor,
              );
              final groups = widget.income
                  ? all.categoryIncomes
                  : all.categoryExpenses;
              final group = groups
                  .where((g) => g.categoryId == widget.groupId)
                  .firstOrNull;
              final entries = group?.entries ?? const <Operation>[];
              final ids = entries.map((entry) => entry.entityId).toSet();
              final filtered = entries
                  .where(
                    (entry) => ('${entry.data['note']} ${entry.data['date']}')
                        .toLowerCase()
                        .contains(query.toLowerCase()),
                  )
                  .toList();
              if (largestFirst) {
                filtered.sort((a, b) {
                  final amount = (b.data['amountMinor'] as int).compareTo(
                    a.data['amountMinor'] as int,
                  );
                  final date = (b.data['date'] as String).compareTo(
                    a.data['date'] as String,
                  );
                  return amount != 0
                      ? amount
                      : date != 0
                      ? date
                      : a.entityId.compareTo(b.entityId);
                });
              }
              final amount = group?.amountMinor ?? 0;
              final maximum = entries.fold<int>(
                0,
                (value, e) => (e.data['amountMinor'] as int) > value
                    ? e.data['amountMinor'] as int
                    : value,
              );
              final trend = LedgerStatistics.forPeriod(
                views
                    .where(
                      (v) =>
                          v.current.entityType == EntityType.category ||
                          ids.contains(v.current.entityId),
                    )
                    .toList(),
                widget.range.start,
                widget.range.period,
                uncategorizedThresholdMinor:
                    settings.uncategorizedThresholdMinor,
              );
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filtered.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PageHeading(
                              eyebrow: 'A CLOSER LOOK',
                              title: group != null
                                  ? groupLabel(context, group)
                                  : widget.groupId == 'uncategorized:other'
                                  ? context.l10n.other
                                  : widget.label,
                              description:
                                  '${rangeLabel(context, widget.range)} · ${widget.income ? context.l10n.income : context.l10n.expense}',
                            ),
                            LayoutBuilder(
                              builder: (context, constraints) => Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final metric in <(String, String)>[
                                    (context.l10n.periodTotal, money(amount)),
                                    (
                                      context.l10n.transactions2,
                                      context.l10n.entries(entries.length),
                                    ),
                                    (
                                      context.l10n.averageEntry,
                                      money(
                                        entries.isEmpty
                                            ? 0
                                            : (amount + entries.length ~/ 2) ~/
                                                  entries.length,
                                      ),
                                    ),
                                    (context.l10n.largestEntry, money(maximum)),
                                  ])
                                    SizedBox(
                                      width: constraints.maxWidth < 600
                                          ? (constraints.maxWidth - 12) / 2
                                          : (constraints.maxWidth - 36) / 4,
                                      child: PaperPanel(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              metric.$1,
                                              style: theme.textTheme.bodySmall,
                                            ),
                                            const SizedBox(height: 7),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                metric.$2,
                                                style: LedgerTypography.of(
                                                  context,
                                                ).number(size: 23),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (hidden)
                              Text(context.l10n.amountsHidden)
                            else if (entries.isNotEmpty)
                              PaperPanel(
                                padding: const EdgeInsets.all(16),
                                child: StatisticsTrendChart(
                                  statistics: trend,
                                  measure: widget.income
                                      ? StatisticsMeasure.income
                                      : StatisticsMeasure.expense,
                                ),
                              ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: search,
                              decoration: InputDecoration(
                                labelText: context.l10n.searchNotesOrDates,
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (value) =>
                                  setState(() => query = value),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  query.isEmpty
                                      ? context.l10n.entries2(
                                          entries.length,
                                          widget.income
                                              ? context.l10n.income
                                              : context.l10n.expense,
                                        )
                                      : context.l10n.ofEntriesMatch(
                                          filtered.length,
                                          entries.length,
                                        ),
                                ),
                                TextButton.icon(
                                  key: const ValueKey('detail-sort'),
                                  onPressed: () => setState(
                                    () => largestFirst = !largestFirst,
                                  ),
                                  icon: const Icon(Icons.sort, size: 18),
                                  label: Text(
                                    largestFirst
                                        ? context.l10n.amountHighToLow
                                        : context.l10n.dateNewestFirst,
                                  ),
                                ),
                              ],
                            ),
                            if (filtered.isEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                  context.l10n.noMatchingEntriesInThisPeriod,
                                ),
                              ),
                          ],
                        );
                      }
                      final entry = filtered[index - 1];
                      final note = entry.data['note'] as String;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (_) => EntryEditor(
                              views: views,
                              existing: views.firstWhere(
                                (v) => v.current.entityId == entry.entityId,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.data['date'] as String,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                    const Icon(Icons.edit_outlined, size: 15),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  money(entry.data['amountMinor'] as int),
                                  style: LedgerTypography.of(
                                    context,
                                  ).number(size: 22),
                                ),
                                const SizedBox(height: 5),
                                Text(note.isEmpty ? context.l10n.noNote : note),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
    );
  }
}
