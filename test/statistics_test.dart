import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/data/ledger_repository.dart';
import 'package:my_ledger/domain/ledger_statistics.dart';
import 'package:my_ledger/domain/operation.dart';
import 'support.dart';

Operation statisticsCategory({
  String? id,
  String name = '餐饮',
  bool deleted = false,
}) => Operation(
  id: uuid.v4(),
  ledgerId: statisticsLedger,
  deviceId: statisticsDevice,
  entityId: id ?? uuid.v4(),
  entityType: EntityType.category,
  parents: [],
  data: {'name': name, 'kind': 'expense'},
  deleted: deleted,
  createdAt: '2026-10-23T00:00:00.000Z',
);

final statisticsLedger = uuid.v4();
final statisticsDevice = uuid.v4();

Operation statisticsEntry(
  String categoryId, {
  String? id,
  int amount = 101,
  String date = '2026-10-01',
  String kind = 'expense',
  bool deleted = false,
  String note = '午餐',
}) => Operation(
  id: uuid.v4(),
  ledgerId: statisticsLedger,
  deviceId: statisticsDevice,
  entityId: id ?? uuid.v4(),
  entityType: EntityType.entry,
  parents: [],
  data: {
    'amountMinor': amount,
    'kind': kind,
    'categoryId': categoryId,
    'date': date,
    'note': note,
  },
  deleted: deleted,
  createdAt: '2026-10-23T00:00:00.000Z',
);

List<EntityView> heads(List<Operation> operations) =>
    operations.map((op) => EntityView([op])).toList();

void main() {
  test('natural ranges use civil week month and year boundaries', () {
    final week = StatisticsRange.containing(
      DateTime(2027, 1, 1),
      StatisticsPeriod.week,
    );
    expect(week.start, DateTime(2026, 12, 28));
    expect(week.endExclusive, DateTime(2027, 1, 4));
    expect(week.previous.start, DateTime(2026, 12, 21));
    expect(week.shift(1).start, DateTime(2027, 1, 4));
    final february = StatisticsRange.containing(
      DateTime(2024, 2, 29),
      StatisticsPeriod.month,
    );
    expect(february.dayCount, 29);
    expect(february.shift(1).dayCount, 31);
    final leapYear = StatisticsRange.containing(
      DateTime(2024, 12, 31),
      StatisticsPeriod.year,
    );
    expect(leapYear.dayCount, 366);
    expect(leapYear.previous.dayCount, 365);
    expect(leapYear.endExclusive, DateTime(2025, 1));
  });

  test(
    'weekly aggregation excludes conflicts and deletions and groups income',
    () {
      final archived = statisticsCategory(deleted: true);
      final conflicted = statisticsCategory(name: '工资');
      final other = statisticsCategory(id: conflicted.entityId, name: '薪酬');
      final missing = uuid.v4();
      final conflictId = uuid.v4();
      final result = LedgerStatistics.forPeriod(
        [
          ...heads([
            archived,
            statisticsEntry(
              archived.entityId,
              amount: 101,
              date: '2026-12-28',
              kind: 'income',
            ),
            statisticsEntry(
              missing,
              amount: 202,
              date: '2027-01-03',
              kind: 'income',
            ),
            statisticsEntry(
              conflicted.entityId,
              amount: 303,
              date: '2027-01-01',
              kind: 'income',
            ),
            statisticsEntry(missing, amount: 404, date: '2027-01-02'),
            statisticsEntry(missing, amount: 999, date: '2027-01-04'),
            statisticsEntry(
              missing,
              amount: 999,
              date: '2027-01-01',
              deleted: true,
            ),
            statisticsEntry(missing, amount: 505, date: '2026-12-27'),
          ]),
          EntityView([conflicted, other]),
          EntityView([
            statisticsEntry(missing, id: conflictId, date: '2026-12-27'),
            statisticsEntry(
              missing,
              id: conflictId,
              date: '2027-01-03',
              deleted: true,
            ),
          ]),
        ],
        DateTime(2027, 1, 1),
        StatisticsPeriod.week,
      );
      expect(result.totals.income, 606);
      expect(result.totals.expense, 404);
      expect(result.totals.conflicts, 1);
      expect(result.previousTotals.expense, 505);
      expect(result.previousTotals.conflicts, 1);
      expect(result.entryCount, 4);
      expect(
        result.categoryIncomes.map((c) => c.label),
        containsAll(['餐饮（已归档）', '分类待同步', '分类有冲突']),
      );
      expect(
        result.categoryIncomes.fold<int>(0, (sum, c) => sum + c.amountMinor),
        606,
      );
      expect(result.dailyTotals.first.incomeMinor, 101);
      expect(result.dailyTotals.last.incomeMinor, 202);
      expect(result.dailyTotals[5].expenseMinor, 404);
    },
  );

  test('year buckets follow actual months and clipped Monday weeks', () {
    final result = LedgerStatistics.forPeriod(
      heads([
        statisticsEntry(uuid.v4(), amount: 100, date: '2024-02-29'),
        statisticsEntry(uuid.v4(), amount: 200, date: '2024-03-01'),
        statisticsEntry(
          uuid.v4(),
          amount: 300,
          date: '2024-12-31',
          kind: 'income',
        ),
      ]),
      DateTime(2024, 6),
      StatisticsPeriod.year,
    );
    final months = result.trendBuckets(StatisticsBucketUnit.month);
    expect(months.length, 12);
    expect(months[1].start, DateTime(2024, 2));
    expect(months[1].endExclusive, DateTime(2024, 3));
    expect(months[1].expenseMinor, 100);
    expect(months[2].expenseMinor, 200);
    expect(months.last.incomeMinor, 300);
    final weeks = result.trendBuckets(StatisticsBucketUnit.week);
    expect(weeks.last.start, DateTime(2024, 12, 30));
    expect(weeks.last.endExclusive, DateTime(2025, 1));
    expect(weeks.last.incomeMinor, 300);
    expect(
      weeks.skip(1).every((w) => w.start.weekday == DateTime.monday),
      isTrue,
    );
    expect(
      months.fold<int>(0, (s, b) => s + b.expenseMinor),
      result.totals.expense,
    );
  });

  test('sums integer cents and compares income expense and balance', () {
    final category = statisticsCategory();
    final views = heads([
      category,
      statisticsEntry(category.entityId, amount: 101),
      statisticsEntry(category.entityId, amount: 202, date: '2026-10-02'),
      statisticsEntry(category.entityId, amount: 1000, kind: 'income'),
      statisticsEntry(category.entityId, amount: 100, date: '2026-09-01'),
      statisticsEntry(
        category.entityId,
        amount: 500,
        date: '2026-09-30',
        kind: 'income',
      ),
    ]);

    final result = LedgerStatistics.forMonth(views, DateTime(2026, 10, 23));

    expect(result.month, DateTime(2026, 10));
    expect(result.totals.income, 1000);
    expect(result.totals.expense, 303);
    expect(result.totals.balance, 697);
    expect(result.entryCount, 3);
    expect(result.previousTotals.income, 500);
    expect(result.incomeComparison.differenceMinor, 500);
    expect(result.incomeComparison.percentageChange, 100);
    expect(result.expenseComparison.differenceMinor, 203);
    expect(result.expenseComparison.percentageChange, closeTo(203, .0001));
    expect(result.balanceComparison.differenceMinor, 297);
    expect(
      result.totals.expense,
      LedgerRepository.monthly(views, '2026-10').expense,
    );
  });

  test(
    'excludes deleted and conflicting entries with the same rules as home',
    () {
      final category = statisticsCategory();
      final conflictId = uuid.v4();
      final views = [
        ...heads([
          category,
          statisticsEntry(category.entityId),
          statisticsEntry(category.entityId, deleted: true, amount: 999),
        ]),
        EntityView([
          statisticsEntry(
            category.entityId,
            id: conflictId,
            date: '2026-09-30',
          ),
          statisticsEntry(
            category.entityId,
            id: conflictId,
            date: '2026-10-01',
            deleted: true,
          ),
        ]),
      ];

      final result = LedgerStatistics.forMonth(views, DateTime(2026, 10));
      final homeTotal = LedgerRepository.monthly(views, '2026-10');

      expect(result.totals.expense, homeTotal.expense);
      expect(result.totals.conflicts, homeTotal.conflicts);
      expect(result.totals.conflicts, 1);
      expect(result.entryCount, 1);
      expect(result.categoryExpenses.single.entries.length, 1);
      expect(result.dailyExpenses.first.amountMinor, 101);
      expect(result.previousTotals.conflicts, 1);
    },
  );

  test(
    'groups expense shares by category ID and retains actual sorted entries',
    () {
      final food = statisticsCategory();
      final travel = statisticsCategory(name: '交通');
      final later = statisticsEntry(
        food.entityId,
        amount: 200,
        date: '2026-10-12',
      );
      final earlier = statisticsEntry(food.entityId, amount: 100);
      final result = LedgerStatistics.forMonth(
        heads([
          food,
          travel,
          earlier,
          later,
          statisticsEntry(travel.entityId, amount: 100),
          statisticsEntry(travel.entityId, amount: 99999, kind: 'income'),
        ]),
        DateTime(2026, 10),
      );

      expect(result.categoryExpenses.map((c) => c.label), ['餐饮', '交通']);
      expect(result.categoryExpenses.first.amountMinor, 300);
      expect(result.categoryExpenses.first.share, .75);
      expect(result.categoryExpenses.last.share, .25);
      expect(result.categoryExpenses.first.entries, [later, earlier]);
      expect(result.dailyExpenses[11].amountMinor, 200);
      expect(result.dailyExpenses[1].amountMinor, 0);
      expect(result.dailyExpenses.length, 31);
    },
  );

  test(
    'marks archived missing and conflicting categories without losing expenses',
    () {
      final archived = statisticsCategory(deleted: true);
      final conflict = statisticsCategory(name: '旧分类');
      final renamed = statisticsCategory(id: conflict.entityId, name: '新分类');
      final missingId = uuid.v4();
      final result = LedgerStatistics.forMonth([
        ...heads([
          archived,
          statisticsEntry(archived.entityId),
          statisticsEntry(missingId),
          statisticsEntry(conflict.entityId),
        ]),
        EntityView([conflict, renamed]),
      ], DateTime(2026, 10));

      expect(result.totals.expense, 303);
      expect(
        result.categoryExpenses.map((c) => c.label),
        containsAll(['餐饮（已归档）', '分类待同步', '分类有冲突']),
      );
      expect(result.categoryExpenses.map((c) => c.categoryId).toSet(), {
        archived.entityId,
        missingId,
        conflict.entityId,
      });
    },
  );

  test(
    'empty month has no categories and no percentage against a zero month',
    () {
      final result = LedgerStatistics.forMonth([], DateTime(2026, 2));
      expect(result.entryCount, 0);
      expect(result.totals.income, 0);
      expect(result.totals.expense, 0);
      expect(result.categoryExpenses, isEmpty);
      expect(result.dailyExpenses.length, 28);
      expect(result.dailyExpenses.every((day) => day.amountMinor == 0), isTrue);
      expect(result.incomeComparison.percentageChange, isNull);
      expect(result.expenseComparison.percentageChange, isNull);
      expect(result.balanceComparison.percentageChange, isNull);
    },
  );

  test('new spending against zero has an amount change but no percentage', () {
    final result = LedgerStatistics.forMonth(
      heads([statisticsEntry(uuid.v4(), amount: 12345)]),
      DateTime(2026, 10),
    );
    expect(result.expenseComparison.differenceMinor, 12345);
    expect(result.expenseComparison.percentageChange, isNull);
  });

  test('cross-year comparison uses December of the previous year', () {
    final result = LedgerStatistics.forMonth(
      heads([
        statisticsEntry(uuid.v4(), amount: 200, date: '2026-01-01'),
        statisticsEntry(uuid.v4(), amount: 400, date: '2025-12-31'),
      ]),
      DateTime(2026, 1),
    );
    expect(result.previousMonth, DateTime(2025, 12));
    expect(result.previousTotals.expense, 400);
    expect(result.expenseComparison.percentageChange, -50);
    expect(result.dailyExpenses.last.date, DateTime(2026, 1, 31));
  });

  test(
    'leap February includes its valid last day and excludes adjacent months',
    () {
      final result = LedgerStatistics.forMonth(
        heads([
          statisticsEntry(uuid.v4(), amount: 101, date: '2024-02-29'),
          statisticsEntry(uuid.v4(), amount: 999, date: '2024-03-01'),
        ]),
        DateTime(2024, 2),
      );
      expect(result.dailyExpenses.length, 29);
      expect(result.dailyExpenses.last.date, DateTime(2024, 2, 29));
      expect(result.dailyExpenses.last.amountMinor, 101);
      expect(result.totals.expense, 101);
    },
  );
}
