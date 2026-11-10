import 'operation.dart';

enum StatisticsPeriod { week, month, year }

enum StatisticsBucketUnit { day, week, month }

/// Civil dates avoid daylight-saving gaps in calendar arithmetic.
int civilDaysBetween(DateTime start, DateTime end) => DateTime.utc(
  end.year,
  end.month,
  end.day,
).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
DateTime civilDay(DateTime date, int offset) =>
    DateTime(date.year, date.month, date.day + offset);
String statisticsDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class StatisticsRange {
  const StatisticsRange._(this.start, this.endExclusive, this.period);
  factory StatisticsRange.containing(DateTime date, StatisticsPeriod period) {
    final start = switch (period) {
      StatisticsPeriod.week => civilDay(date, 1 - date.weekday),
      StatisticsPeriod.month => DateTime(date.year, date.month),
      StatisticsPeriod.year => DateTime(date.year),
    };
    final end = switch (period) {
      StatisticsPeriod.week => civilDay(start, 7),
      StatisticsPeriod.month => DateTime(start.year, start.month + 1),
      StatisticsPeriod.year => DateTime(start.year + 1),
    };
    return StatisticsRange._(start, end, period);
  }
  final DateTime start, endExclusive;
  final StatisticsPeriod period;
  int get dayCount => civilDaysBetween(start, endExclusive);
  StatisticsRange get previous => shift(-1);
  StatisticsRange shift(int delta) =>
      StatisticsRange.containing(switch (period) {
        StatisticsPeriod.week => civilDay(start, delta * 7),
        StatisticsPeriod.month => DateTime(start.year, start.month + delta),
        StatisticsPeriod.year => DateTime(start.year + delta),
      }, period);
  String get label => switch (period) {
    StatisticsPeriod.week =>
      '${statisticsDate(start)} 至 ${statisticsDate(civilDay(endExclusive, -1))}',
    StatisticsPeriod.month => statisticsDate(start).substring(0, 7),
    StatisticsPeriod.year => '${start.year}年',
  };
  bool contains(DateTime date) =>
      civilDaysBetween(start, date) >= 0 &&
      civilDaysBetween(date, endExclusive) > 0;
}

class AmountComparison {
  const AmountComparison(this.currentMinor, this.previousMinor);
  final int currentMinor, previousMinor;
  int get differenceMinor => currentMinor - previousMinor;
  double? get percentageChange =>
      previousMinor == 0 ? null : differenceMinor / previousMinor.abs() * 100;
}

enum StatisticsGroupKind { category, other, uncategorizedEntry }

class CategoryExpense {
  CategoryExpense({
    required this.categoryId,
    required this.label,
    required this.amountMinor,
    required this.share,
    required List<Operation> entries,
    this.groupKind = StatisticsGroupKind.category,
  }) : entries = List.unmodifiable(entries);
  final String categoryId, label;
  final int amountMinor;
  final double share;
  final List<Operation> entries;
  final StatisticsGroupKind groupKind;
}

class DailyExpense {
  const DailyExpense(this.date, this.amountMinor);
  final DateTime date;
  final int amountMinor;
}

class DailyTotal {
  const DailyTotal(this.date, this.incomeMinor, this.expenseMinor);
  final DateTime date;
  final int incomeMinor, expenseMinor;
}

class TrendBucket {
  const TrendBucket(
    this.start,
    this.endExclusive,
    this.incomeMinor,
    this.expenseMinor,
  );
  final DateTime start, endExclusive;
  final int incomeMinor, expenseMinor;
  String get label => civilDaysBetween(start, endExclusive) == 1
      ? statisticsDate(start)
      : '${statisticsDate(start)} 至 ${statisticsDate(civilDay(endExclusive, -1))}';
}

class LedgerStatistics {
  LedgerStatistics._({
    required this.range,
    required this.totals,
    required this.previousTotals,
    required this.entryCount,
    required List<CategoryExpense> categoryExpenses,
    required List<CategoryExpense> categoryIncomes,
    required List<DailyTotal> dailyTotals,
  }) : categoryExpenses = List.unmodifiable(categoryExpenses),
       categoryIncomes = List.unmodifiable(categoryIncomes),
       dailyTotals = List.unmodifiable(dailyTotals);

  factory LedgerStatistics.forMonth(
    List<EntityView> views,
    DateTime selected, {
    int uncategorizedThresholdMinor = 50000,
  }) => LedgerStatistics.forPeriod(
    views,
    selected,
    StatisticsPeriod.month,
    uncategorizedThresholdMinor: uncategorizedThresholdMinor,
  );
  factory LedgerStatistics.forPeriod(
    List<EntityView> views,
    DateTime selected,
    StatisticsPeriod period, {
    int uncategorizedThresholdMinor = 50000,
  }) {
    if (uncategorizedThresholdMinor <= 0 ||
        uncategorizedThresholdMinor > maxAmountMinor) {
      throw const LedgerException('未分类大额门槛无效');
    }
    final range = StatisticsRange.containing(selected, period);
    final current = _periodEntries(views, range);
    final previous = _periodEntries(views, range.previous);
    final categories = {
      for (final view in views.where(
        (v) => v.current.entityType == EntityType.category,
      ))
        view.current.entityId: view,
    };
    final income = List<int>.filled(range.dayCount, 0),
        expense = List<int>.filled(range.dayCount, 0);
    for (final entry in current.entries) {
      final index = civilDaysBetween(
        range.start,
        DateTime.parse(entry.data['date'] as String),
      );
      final days = entry.data['kind'] == 'income' ? income : expense;
      days[index] += entry.data['amountMinor'] as int;
    }
    List<CategoryExpense> grouped(String kind, int total) {
      final groups = <String, List<Operation>>{};
      for (final entry in current.entries.where(
        (e) => e.data['kind'] == kind,
      )) {
        final category = entry.data['categoryId'] as String?;
        final key =
            category ??
            ((entry.data['amountMinor'] as int) >= uncategorizedThresholdMinor
                ? 'uncategorized:${entry.entityId}'
                : 'uncategorized:other');
        (groups[key] ??= []).add(entry);
      }
      return groups.entries.map((group) {
        final entries = group.value..sort(_latestFirst);
        final amount = entries.fold<int>(
          0,
          (sum, e) => sum + (e.data['amountMinor'] as int),
        );
        final category = categories[group.key];
        final groupKind = group.key == 'uncategorized:other'
            ? StatisticsGroupKind.other
            : group.key.startsWith('uncategorized:')
            ? StatisticsGroupKind.uncategorizedEntry
            : StatisticsGroupKind.category;
        final note = entries.singleOrNull?.data['note'] as String? ?? '';
        final shortNote = note.runes.length > 24
            ? '${String.fromCharCodes(note.runes.take(24))}…'
            : note;
        final label = groupKind == StatisticsGroupKind.other
            ? '其他'
            : groupKind == StatisticsGroupKind.uncategorizedEntry
            ? (note.trim().isEmpty
                  ? '未分类 · ${entries.first.data['date']}'
                  : '未分类 · $shortNote')
            : category == null
            ? '分类待同步'
            : category.hasConflict
            ? '分类有冲突'
            : '${category.current.data['name']}${category.current.deleted ? '（已归档）' : ''}';
        return CategoryExpense(
          categoryId: group.key,
          label: label,
          amountMinor: amount,
          share: total == 0 ? 0 : amount / total,
          entries: entries,
          groupKind: groupKind,
        );
      }).toList()..sort((a, b) {
        final order = b.amountMinor.compareTo(a.amountMinor);
        if (order != 0) return order;
        final labelOrder = a.label.compareTo(b.label);
        return labelOrder != 0
            ? labelOrder
            : a.categoryId.compareTo(b.categoryId);
      });
    }

    return LedgerStatistics._(
      range: range,
      totals: current.total,
      previousTotals: previous.total,
      entryCount: current.entries.length,
      categoryExpenses: grouped('expense', current.total.expense),
      categoryIncomes: grouped('income', current.total.income),
      dailyTotals: [
        for (var day = 0; day < range.dayCount; day++)
          DailyTotal(civilDay(range.start, day), income[day], expense[day]),
      ],
    );
  }
  final StatisticsRange range;
  final MonthlyTotal totals, previousTotals;
  final int entryCount;
  final List<CategoryExpense> categoryExpenses, categoryIncomes;
  final List<DailyTotal> dailyTotals;
  DateTime get month => range.start;
  DateTime get previousMonth => range.previous.start;
  List<DailyExpense> get dailyExpenses => List.unmodifiable([
    for (final day in dailyTotals) DailyExpense(day.date, day.expenseMinor),
  ]);
  AmountComparison get incomeComparison =>
      AmountComparison(totals.income, previousTotals.income);
  AmountComparison get expenseComparison =>
      AmountComparison(totals.expense, previousTotals.expense);
  AmountComparison get balanceComparison =>
      AmountComparison(totals.balance, previousTotals.balance);

  List<TrendBucket> trendBuckets(StatisticsBucketUnit unit) {
    final buckets = <TrendBucket>[];
    var start = range.start;
    while (start.isBefore(range.endExclusive)) {
      final naturalEnd = switch (unit) {
        StatisticsBucketUnit.day => civilDay(start, 1),
        StatisticsBucketUnit.week => civilDay(start, 8 - start.weekday),
        StatisticsBucketUnit.month => DateTime(start.year, start.month + 1),
      };
      final end = naturalEnd.isAfter(range.endExclusive)
          ? range.endExclusive
          : naturalEnd;
      var income = 0, expense = 0;
      for (
        var i = civilDaysBetween(range.start, start);
        i < civilDaysBetween(range.start, end);
        i++
      ) {
        income += dailyTotals[i].incomeMinor;
        expense += dailyTotals[i].expenseMinor;
      }
      buckets.add(TrendBucket(start, end, income, expense));
      start = end;
    }
    return List.unmodifiable(buckets);
  }

  static ({MonthlyTotal total, List<Operation> entries}) _periodEntries(
    List<EntityView> views,
    StatisticsRange range,
  ) {
    bool within(Operation e) =>
        range.contains(DateTime.parse(e.data['date'] as String));
    var income = 0, expense = 0, conflicts = 0;
    final entries = <Operation>[];
    for (final view in views.where(
      (v) => v.current.entityType == EntityType.entry,
    )) {
      if (view.hasConflict) {
        if (view.versions.any(within)) conflicts++;
        continue;
      }
      final entry = view.current;
      if (entry.deleted || !within(entry)) continue;
      entries.add(entry);
      if (entry.data['kind'] == 'income') {
        income += entry.data['amountMinor'] as int;
      } else {
        expense += entry.data['amountMinor'] as int;
      }
    }
    return (total: MonthlyTotal(income, expense, conflicts), entries: entries);
  }

  static int _latestFirst(Operation a, Operation b) {
    final order = (b.data['date'] as String).compareTo(
      a.data['date'] as String,
    );
    return order != 0 ? order : a.entityId.compareTo(b.entityId);
  }
}
