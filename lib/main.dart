import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'app/ledger_app.dart';
import 'app/providers.dart';
import 'data/database.dart';
import 'data/ledger_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final db = LedgerDatabase(
      NativeDatabase.createInBackground(
        File(path.join(directory.path, 'myledger.sqlite')),
      ),
    );
    final repository = LedgerRepository(db);
    await repository.ledgerId;
    await repository.deviceId;
    runApp(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repository)],
        child: const LedgerApp(),
      ),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('本地数据库打开失败，请检查磁盘空间或权限；请保留现有数据，勿卸载应用。')),
        ),
      ),
    );
  }
}
