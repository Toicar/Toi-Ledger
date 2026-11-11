import 'package:flutter/widgets.dart';
import '../domain/ledger_statistics.dart';
import 'app_strings.dart';

String groupLabel(BuildContext context, CategoryExpense group) {
  final strings = context.l10n;
  switch (group.groupKind) {
    case StatisticsGroupKind.other:
      return strings.other;
    case StatisticsGroupKind.uncategorizedEntry:
      // Only the app-owned prefix is translated; notes are always user data.
      return strings.uncategorized(group.label.substring('未分类 · '.length));
    case StatisticsGroupKind.category:
      if (group.categoryMissing) return strings.categoryAwaitingSync;
      if (group.categoryConflict) return strings.categoryConflict;
      return (group.categoryName ?? group.label) +
          (group.categoryArchived ? strings.archivedSuffix : '');
  }
}

String rangeLabel(BuildContext context, StatisticsRange range) =>
    switch (range.period) {
      StatisticsPeriod.month =>
        '${range.start.year}-${range.start.month.toString().padLeft(2, '0')}',
      StatisticsPeriod.year => context.l10n.label(range.start.year),
      StatisticsPeriod.week => context.l10n.to(
        statisticsDate(range.start),
        statisticsDate(civilDay(range.endExclusive, -1)),
      ),
    };
String bucketLabel(BuildContext context, TrendBucket bucket) =>
    civilDaysBetween(bucket.start, bucket.endExclusive) == 1
    ? statisticsDate(bucket.start)
    : context.l10n.to(
        statisticsDate(bucket.start),
        statisticsDate(civilDay(bucket.endExclusive, -1)),
      );
