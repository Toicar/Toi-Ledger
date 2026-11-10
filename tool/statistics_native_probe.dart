// Run only for native chart input validation; all entries live in memory.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_ledger/app/app_theme.dart';
import 'package:my_ledger/app/providers.dart';
import 'package:my_ledger/data/database.dart';
import 'package:my_ledger/data/ledger_repository.dart';
import 'package:my_ledger/domain/ledger_statistics.dart';
import 'package:my_ledger/domain/operation.dart';
import 'package:my_ledger/features/statistics/statistics_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = LedgerRepository(LedgerDatabase(NativeDatabase.memory()));
  final expenses = <Operation>[];
  for (final name in ['示例餐饮', '示例交通', '示例生活']) {
    expenses.add(
      await repository.save(
        type: EntityType.category,
        data: {'name': name, 'kind': 'expense'},
      ),
    );
  }
  final salary = await repository.save(
    type: EntityType.category,
    data: {'name': '示例收入', 'kind': 'income'},
  );
  final now = DateTime.now();
  for (var month = 1; month <= 12; month++) {
    for (var day = 1; day <= 26; day += 5) {
      await repository.save(
        type: EntityType.entry,
        data: {
          'kind': 'expense',
          'amountMinor': day * 200 + month * 35,
          'categoryId': expenses[(day ~/ 5) % expenses.length].entityId,
          'date': statisticsDate(DateTime(now.year, month, day)),
          'note': '仅供图表验收的内存样本',
        },
      );
    }
    for (final day in [8, 24]) {
      await repository.save(
        type: EntityType.entry,
        data: {
          'kind': 'income',
          'amountMinor': day == 8 ? 100000 + month * 500 : 10000,
          'categoryId': salary.entityId,
          'date': statisticsDate(DateTime(now.year, month, day)),
          'note': '仅供图表验收的内存样本',
        },
      );
    }
  }
  runApp(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        title: 'MyLedger 图表手势验收',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: Material(
          child: Column(
            children: [
              const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('图表验收 · 虚构内存样本 · 关闭即丢弃'),
                ),
              ),
              Expanded(child: StatisticsPage(initialMonth: now)),
            ],
          ),
        ),
      ),
    ),
  );
}
