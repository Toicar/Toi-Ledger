import '../../l10n/statistics_labels.dart';
import '../../l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/presentation_controller.dart';
import '../../app/providers.dart';
import '../../app/ui_common.dart';
import '../../domain/ledger_statistics.dart';
import '../../domain/operation.dart';
import '../../app/design_components.dart';
import '../../app/ledger_typography.dart';
import 'category_chart.dart';
import 'statistics_controls.dart';
import 'trend_chart.dart';
import 'category_statistics_page.dart';
import 'uncategorized_rule.dart';

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key, this.initialMonth});
  final DateTime? initialMonth;
  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  late DateTime anchor;
  StatisticsPeriod period = StatisticsPeriod.month;
  StatisticsMeasure measure = StatisticsMeasure.expense;
  StatisticsRange get range => StatisticsRange.containing(anchor, period);
  String get periodName => switch (period) {
    StatisticsPeriod.week => context.l10n.week,
    StatisticsPeriod.month => context.l10n.month,
    StatisticsPeriod.year => context.l10n.year,
  };
  @override
  void initState() {
    super.initState();
    final today = DateTime.now(),
        initial = widget.initialMonth ?? DateTime.now();
    anchor = initial.year == today.year && initial.month == today.month
        ? DateTime(today.year, today.month, today.day)
        : DateTime(initial.year.clamp(1900, 2200), initial.month, initial.day);
  }

  bool canShift(int delta) {
    final target = range.shift(delta);
    return target.endExclusive.isAfter(DateTime(1900)) &&
        target.start.isBefore(DateTime(2201));
  }

  void shift(int delta) {
    if (canShift(delta)) setState(() => anchor = range.shift(delta).start);
  }

  Future<void> toggleAmounts() async {
    try {
      await ref
          .read(presentationProvider.notifier)
          .setHideAmounts(!ref.read(presentationProvider).hideAmounts);
    } catch (error) {
      if (mounted) notify(context, safeError(error, context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hidden = ref.watch(presentationProvider).hideAmounts;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.statistics,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            Text(
              'MyLedger',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: hidden
                ? context.l10n.showAmounts
                : context.l10n.hideAmounts,
            onPressed: toggleAmounts,
            icon: Icon(
              hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ref
          .watch(entitiesProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(safeError(error, context))),
            data: (views) {
              final statistics = LedgerStatistics.forPeriod(
                views,
                anchor,
                period,
                uncategorizedThresholdMinor: ref
                    .watch(presentationProvider)
                    .uncategorizedThresholdMinor,
              );
              final categoryIncome = measure == StatisticsMeasure.income;
              final measureControl = StatisticsSegments<StatisticsMeasure>(
                values: const [
                  StatisticsMeasure.expense,
                  StatisticsMeasure.income,
                  StatisticsMeasure.both,
                ],
                selected: measure,
                label: (value) => switch (value) {
                  StatisticsMeasure.expense => context.l10n.expense,
                  StatisticsMeasure.income => context.l10n.income,
                  StatisticsMeasure.both => context.l10n.compare,
                },
                itemKey: (value) => ValueKey('measure-${value.name}'),
                onChanged: (value) => setState(() => measure = value),
              );
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (MediaQuery.sizeOf(context).width >= 700)
                            PageHeading(
                              eyebrow: 'THE BIGGER PICTURE',
                              title: context.l10n.letTheNumbersTellYourStory,
                              description: context.l10n.findYourRhythmInTheRise,
                            ),
                          LayoutBuilder(
                            builder: (context, constraints) => Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                StatisticsSegments<StatisticsPeriod>(
                                  values: StatisticsPeriod.values,
                                  selected: period,
                                  label: (value) => switch (value) {
                                    StatisticsPeriod.week => context.l10n.week,
                                    StatisticsPeriod.month =>
                                      context.l10n.month,
                                    StatisticsPeriod.year => context.l10n.year,
                                  },
                                  onChanged: (value) =>
                                      setState(() => period = value),
                                ),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: period == StatisticsPeriod.week
                                        ? constraints.maxWidth
                                        : 180,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: context.l10n.previous(
                                          periodName,
                                        ),
                                        onPressed: canShift(-1)
                                            ? () => shift(-1)
                                            : null,
                                        style: IconButton.styleFrom(
                                          minimumSize: const Size(36, 40),
                                          padding: EdgeInsets.zero,
                                        ),
                                        icon: const Icon(
                                          Icons.chevron_left,
                                          size: 18,
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          period == StatisticsPeriod.month
                                              ? context.l10n.label4(
                                                  range.start.year,
                                                  range.start.month,
                                                )
                                              : rangeLabel(context, range),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: context.l10n.next(periodName),
                                        onPressed: canShift(1)
                                            ? () => shift(1)
                                            : null,
                                        style: IconButton.styleFrom(
                                          minimumSize: const Size(36, 40),
                                          padding: EdgeInsets.zero,
                                        ),
                                        icon: const Icon(
                                          Icons.chevron_right,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (hidden)
                            _Section(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.visibility_off_outlined),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.l10n.amountsHidden,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    context.l10n.entriesIncludedThis(
                                      periodName,
                                      statistics.entryCount,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            _Summary(
                              key: const ValueKey('period-summary'),
                              statistics: statistics,
                              periodName: periodName,
                            ),
                            const SizedBox(height: 16),
                            if (statistics.entryCount == 0)
                              _Section(
                                child: Text(
                                  context.l10n.noEntriesThis(periodName),
                                ),
                              )
                            else ...[
                              _Section(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    StatisticsTrendChart(
                                      statistics: statistics,
                                      measure: measure,
                                      controls: measureControl,
                                    ),
                                    const SizedBox(height: 12),
                                    _TrendComparison(
                                      statistics: statistics,
                                      periodName: periodName,
                                      income: categoryIncome,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _Section(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Align(
                                      alignment: Alignment.centerRight,
                                      child: UncategorizedRuleButton(),
                                    ),
                                    CategoryChartPanel(
                                      categories: categoryIncome
                                          ? statistics.categoryIncomes
                                          : statistics.categoryExpenses,
                                      income: categoryIncome,
                                      onSelected: (category) =>
                                          Navigator.of(context).push<void>(
                                            MaterialPageRoute(
                                              settings: const RouteSettings(
                                                name: '/statistics/details',
                                              ),
                                              builder: (_) =>
                                                  CategoryStatisticsPage(
                                                    groupId:
                                                        category.categoryId,
                                                    label: category.label,
                                                    range: statistics.range,
                                                    income: categoryIncome,
                                                  ),
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            _Section(
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                key: const ValueKey('month-comparison'),
                                title: Text(
                                  context.l10n.comparedWithLast(periodName),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                children: [
                                  Text(
                                    context.l10n.previous2(
                                      periodName,
                                      rangeLabel(
                                        context,
                                        statistics.range.previous,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _ComparisonRow(
                                    context.l10n.income,
                                    statistics.incomeComparison,
                                    periodName,
                                  ),
                                  _ComparisonRow(
                                    context.l10n.expense,
                                    statistics.expenseComparison,
                                    periodName,
                                  ),
                                  _ComparisonRow(
                                    context.l10n.balance,
                                    statistics.balanceComparison,
                                    periodName,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (statistics.totals.conflicts > 0) ...[
                            const SizedBox(height: 16),
                            Text(
                              context.l10n.conflictedEntriesExcludedThis(
                                periodName,
                                statistics.totals.conflicts,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.padding = 16});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Card(
    semanticContainer: false,
    elevation: 0,
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({
    super.key,
    required this.statistics,
    required this.periodName,
  });
  final LedgerStatistics statistics;
  final String periodName;
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.incomeAndExpensesThis(periodName),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final style = LedgerTypography.of(
          context,
        ).number(size: MediaQuery.sizeOf(context).width >= 700 ? 25 : 19);
        final scaler = MediaQuery.textScalerOf(context);
        final moneyWidth = [statistics.totals.income, statistics.totals.expense]
            .map((amount) {
              final painter = TextPainter(
                text: TextSpan(text: statisticsMoney(amount), style: style),
                textDirection: TextDirection.ltr,
                textScaler: scaler,
              )..layout();
              return painter.width;
            })
            .reduce((a, b) => a > b ? a : b);
        final stacked = moneyWidth > (constraints.maxWidth - 10) / 2 - 24;
        Widget metric(String label, int amount) => _Section(
          padding: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(statisticsMoney(amount), style: style),
              const SizedBox(height: 4),
              Text(
                context.l10n.thisPeriod,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stacked) ...[
              metric(context.l10n.income, statistics.totals.income),
              const SizedBox(height: 8),
              metric(context.l10n.expense, statistics.totals.expense),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: metric(
                      context.l10n.income,
                      statistics.totals.income,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: metric(
                      context.l10n.expense,
                      statistics.totals.expense,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            _Section(
              padding: 12,
              child: LayoutBuilder(
                builder: (context, balanceConstraints) {
                  final amount = Text(
                    statisticsMoney(statistics.totals.balance),
                    style: style,
                  );
                  final label = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.balance,
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.incomeExpenses,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [label, const SizedBox(height: 6), amount],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: label),
                      const SizedBox(width: 8),
                      amount,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.entriesIncluded(statistics.entryCount),
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _TrendComparison extends StatelessWidget {
  const _TrendComparison({
    required this.statistics,
    required this.periodName,
    required this.income,
  });
  final LedgerStatistics statistics;
  final String periodName;
  final bool income;
  @override
  Widget build(BuildContext context) {
    final comparison = income
        ? statistics.incomeComparison
        : statistics.expenseComparison;
    final percent = comparison.percentageChange;
    final change = percent == null
        ? context.l10n.previousPeriodWasZero
        : '${percent > 0 ? '+' : ''}${percent.toStringAsFixed(1)}%';
    final maximum = comparison.currentMinor > comparison.previousMinor
        ? comparison.currentMinor
        : comparison.previousMinor;
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        SizedBox(
          width: 26,
          height: 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 10,
                height: maximum == 0
                    ? 1
                    : 20 * comparison.previousMinor / maximum,
                color: color.withValues(alpha: .35),
              ),
              const SizedBox(width: 3),
              Container(
                width: 10,
                height: maximum == 0
                    ? 1
                    : 20 * comparison.currentMinor / maximum,
                color: color,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.l10n.vsLast(
              periodName,
              income ? context.l10n.income : context.l10n.expense,
              change,
            ),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow(this.label, this.comparison, this.periodName);
  final String label, periodName;
  final AmountComparison comparison;
  @override
  Widget build(BuildContext context) {
    final difference = comparison.differenceMinor;
    final direction = difference > 0
        ? context.l10n.increase
        : difference < 0
        ? context.l10n.decrease
        : context.l10n.unchanged;
    final percentage = comparison.percentageChange;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label $direction${difference == 0 ? '' : ' ¥${formatAmount(difference.abs())}'}',
          ),
          Text(
            percentage == null
                ? context.l10n.previousWasZeroPercentageIsNot(periodName)
                : context.l10n.periodChange(
                    percentage > 0 ? '+' : '',
                    percentage.toStringAsFixed(1),
                  ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
