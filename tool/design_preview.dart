// Visual QA entry point. Every record and preference lives in memory.
// Production builds always target lib/main.dart.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_ledger/app/appearance_controller.dart';
import 'package:my_ledger/app/ledger_app.dart';
import 'package:my_ledger/app/providers.dart';
import 'package:my_ledger/data/credential_store.dart';
import 'package:my_ledger/data/database.dart';
import 'package:my_ledger/data/entry_templates.dart';
import 'package:my_ledger/data/ledger_repository.dart';
import 'package:my_ledger/domain/ledger_statistics.dart';
import 'package:my_ledger/domain/operation.dart';
import 'package:my_ledger/sync/webdav.dart';
import 'package:uuid/uuid.dart';

final _captureKey = GlobalKey();
int _captureNumber = 0;
Future<void> _capture() async {
  const directory = String.fromEnvironment('MYLEDGER_PREVIEW_CAPTURE_DIR');
  if (directory.isEmpty) return;
  await WidgetsBinding.instance.endOfFrame;
  final boundary = _captureKey.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) return;
  final image = await boundary.toImage(pixelRatio: 1.5);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Preview screenshot encoding failed');
    await Directory(directory).create(recursive: true);
    await File('$directory/preview-${++_captureNumber}.png').writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
}

class _NoCredentials implements CredentialStore {
  @override
  Future<DavConfig?> read() async => null;
  @override
  Future<void> write(DavConfig config) async {}
  @override
  Future<void> clear() async {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = LedgerRepository(LedgerDatabase(NativeDatabase.memory()));
  final categories = <String, Operation>{};
  for (final name in ['餐饮美食', '交通出行', '日常购物', '居家生活', '学习成长', '工资收入']) {
    categories[name] = await repository.save(
      type: EntityType.category,
      data: {'name': name, 'kind': name == '工资收入' ? 'income' : 'expense'},
    );
  }
  final now = DateTime.now();
  final examples = <(int, String, int, String)>[
    (1, '工资收入', 1800000, '十一月，新的开始'),
    (2, '居家生活', 280000, '房租 · 给生活一个安稳的角落'),
    (3, '学习成长', 8900, '读一本惦记了很久的书'),
    (4, '日常购物', 23900, '秋天的日常用品'),
    (5, '餐饮美食', 6800, '和朋友一起吃晚饭'),
    (6, '交通出行', 1800, '地铁出行'),
    (7, '餐饮美食', 3500, '周末的咖啡与面包'),
    (8, '日常购物', 12800, '买一束花，送给自己'),
    (9, '交通出行', 2600, '晚归的出租车'),
    (10, '餐饮美食', 2850, '一碗热面，普通的好日子'),
    (10, '餐饮美食', 2200, '午后的拿铁'),
  ];
  for (final (day, name, amount, note) in examples) {
    await repository.save(
      type: EntityType.entry,
      data: {
        'kind': categories[name]!.data['kind'],
        'amountMinor': amount,
        'categoryId': categories[name]!.entityId,
        'date': statisticsDate(DateTime(now.year, now.month, day)),
        'note': note,
      },
    );
  }
  await EntryTemplatePreferences(repository.db).write([
    EntryTemplate(
      id: const Uuid().v4(),
      name: '每天一杯咖啡',
      kind: 'expense',
      categoryId: categories['餐饮美食']!.entityId,
      amountMinor: 2200,
      note: '给忙碌的一天，留一点香气',
    ),
    EntryTemplate(
      id: const Uuid().v4(),
      name: '地铁通勤',
      kind: 'expense',
      categoryId: categories['交通出行']!.entityId,
      amountMinor: 600,
      note: '往返途中的小风景',
    ),
  ]);
  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        credentialProvider.overrideWithValue(_NoCredentials()),
        initialThemeModeProvider.overrideWithValue(ThemeMode.light),
      ],
      child: RepaintBoundary(
        key: _captureKey,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              SizedBox(
                height: 22,
                child: ColoredBox(
                  color: const Color(0xffeee4d4),
                  child: Center(
                    child: GestureDetector(
                      onTap: _capture,
                      child: const Text(
                        '设计验收 · 虚构内存样本 · 关闭即丢弃 · 点击保存验收图',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xff665b48),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Expanded(child: LedgerApp()),
            ],
          ),
        ),
      ),
    ),
  );
}
