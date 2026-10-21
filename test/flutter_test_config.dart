import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:sqlite3/open.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Each test database has its own executor; two-device tests are intentional.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  if (Platform.isLinux) {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  }
  await testMain();
}
