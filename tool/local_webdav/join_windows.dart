import 'dart:io';

import 'package:drift/native.dart';
import 'package:my_ledger/data/database.dart';
import 'package:my_ledger/data/ledger_repository.dart';

Future<void> main(List<String> arguments) async {
  LedgerDatabase? database;
  try {
    final existingEmpty =
        arguments.length == 3 && arguments[2] == '--existing-empty';
    if (arguments.length != 2 && !existingEmpty) {
      throw const FormatException();
    }
    final file = File(arguments[0]);
    final exists = await file.exists();
    if (exists && !existingEmpty) {
      throw const FileSystemException('Destination database already exists');
    }
    if (!exists && existingEmpty) {
      throw const FileSystemException('Existing database is missing');
    }
    await file.parent.create(recursive: true);
    database = LedgerDatabase(NativeDatabase(file));
    final repository = LedgerRepository(database);
    await repository.joinEmptyLedger(arguments[1]);
    await repository.deviceId;
    stdout.writeln(
      existingEmpty
          ? 'Joined the existing empty Windows ledger; other settings retained.'
          : 'Created an empty Windows ledger joined to the selected ledger.',
    );
  } catch (_) {
    stderr.writeln(
      'Ledger join failed; preserve the existing database and backups.',
    );
    exitCode = 1;
  } finally {
    await database?.close();
  }
}
