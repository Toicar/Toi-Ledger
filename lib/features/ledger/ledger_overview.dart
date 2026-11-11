import '../../l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/app_theme.dart';
import '../../app/design_components.dart';
import '../../app/presentation_controller.dart';
import '../../app/ui_common.dart';
import '../../app/ledger_typography.dart';

class LedgerOverview extends ConsumerWidget {
  const LedgerOverview({
    super.key,
    required this.income,
    required this.expense,
    required this.balance,
    required this.conflicts,
  });
  final int income, expense, balance, conflicts;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hidden = ref.watch(presentationProvider).hideAmounts;
    final dark = theme.brightness == Brightness.dark;
    final compact =
        MediaQuery.sizeOf(context).width < 1000 ||
        MediaQuery.textScalerOf(context).scale(1) >= 1.4;
    final balanceCard = Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xffd8d4c5) : LedgerColors.ink,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: dark ? LedgerColors.ink : LedgerColors.paper),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.balanceThisMonth,
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                IconButton(
                  tooltip: hidden
                      ? context.l10n.showAmounts
                      : context.l10n.hideAmounts,
                  icon: Icon(
                    hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  color: dark ? LedgerColors.ink : const Color(0xffc9c8b9),
                  onPressed: () async {
                    try {
                      await ref
                          .read(presentationProvider.notifier)
                          .setHideAmounts(!hidden);
                    } catch (_) {
                      if (context.mounted) {
                        notify(
                          context,
                          context.l10n.couldNotSaveAmountVisibilityTry,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                hidden ? '••••' : ledgerMoney(balance),
                style: LedgerTypography.of(
                  context,
                ).number(size: 44, weight: FontWeight.w400),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.l10n.roomForLifeBetweenEarningAnd,
              style: TextStyle(
                fontSize: 11,
                color: dark ? const Color(0xff65665a) : const Color(0xffb8b8a9),
              ),
            ),
            if (conflicts > 0) ...[
              const SizedBox(height: 10),
              Text(
                context.l10n.conflictedEntriesExcludedFromTotals(conflicts),
                style: TextStyle(
                  fontSize: 12,
                  color: dark
                      ? const Color(0xff883b26)
                      : const Color(0xffffb29b),
                ),
              ),
            ],
            if (compact) ...[
              const SizedBox(height: 20),
              Divider(color: dark ? Colors.black12 : Colors.white24),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    for (final isIncome in [true, false])
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            hidden
                                ? '${isIncome ? context.l10n.income : context.l10n.expense} ••••'
                                : '${isIncome ? context.l10n.income : context.l10n.expense} ${ledgerMoney(isIncome ? income : expense)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
    Widget metric(bool isIncome) => PaperPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
                size: 17,
                color: isIncome
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  isIncome
                      ? context.l10n.incomeThisMonth
                      : context.l10n.expensesThisMonth,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              hidden ? '••••' : ledgerMoney(isIncome ? income : expense),
              style: LedgerTypography.of(
                context,
              ).number(size: 30, color: theme.colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isIncome
                ? context.l10n.everyEffortFindsItsEcho
                : context.l10n.spendOnWhatMatters,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
    if (compact) return balanceCard;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760 &&
            MediaQuery.textScalerOf(context).scale(1) < 1.4) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: balanceCard),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: metric(true)),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: metric(false)),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            balanceCard,
            const SizedBox(height: 12),
            if (constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(1) >= 1.4) ...[
              metric(true),
              const SizedBox(height: 12),
              metric(false),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: metric(true)),
                  const SizedBox(width: 12),
                  Expanded(child: metric(false)),
                ],
              ),
          ],
        );
      },
    );
  }
}

class LedgerEmptyState extends StatelessWidget {
  const LedgerEmptyState({
    super.key,
    this.filtered = false,
    this.onCreate,
    this.onReset,
    this.hasCategories = true,
  });
  final bool filtered, hasCategories;
  final VoidCallback? onCreate, onReset;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
    child: Column(
      children: [
        if (filtered)
          Icon(
            Icons.search_off_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )
        else
          const LedgerStillLife(size: 120),
        const SizedBox(height: 12),
        Text(
          filtered
              ? context.l10n.noMatchingEntryYet
              : context.l10n.keepALittleRecordOfLife,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          filtered
              ? context.l10n.tryAnotherKeywordOrSwitchThe
              : MediaQuery.sizeOf(context).width >= 1000
              ? context.l10n.noEntriesYetSelectNewEntry
              : context.l10n.noEntriesYetUseTheAdd,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (filtered && onReset != null) ...[
          const SizedBox(height: 14),
          TextButton(
            onPressed: onReset,
            child: Text(context.l10n.clearFilters),
          ),
        ],
        if (!filtered && onCreate != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 17),
            label: Text(context.l10n.startRecording),
          ),
        ],
      ],
    ),
  );
}
