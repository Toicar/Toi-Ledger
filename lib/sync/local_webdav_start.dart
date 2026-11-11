import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'webdav.dart';

/// Starts only a configured local service whose address matches this account.
Future<void> startLocalWebDavIfConfigured(
  DavConfig config, {
  bool? isWindows,
  String? stateDirectory,
  String? executableDirectory,
  Future<ProcessResult> Function(String, List<String>)? run,
}) async {
  if (!(isWindows ?? Platform.isWindows)) return;
  final appDirectory =
      executableDirectory ?? path.dirname(Platform.resolvedExecutable);
  final localAppData = Platform.environment['LOCALAPPDATA'];
  final defaultState = localAppData == null
      ? null
      : path.join(localAppData, 'MyLedger-WebDAV');
  final legacyState = path.join(path.dirname(appDirectory), '.local-webdav');
  final state =
      stateDirectory ??
      (defaultState != null &&
              await File(path.join(defaultState, 'config.json')).exists()
          ? defaultState
          : legacyState);
  final script = path.join(
    appDirectory,
    'webdav-setup',
    'Ensure-LocalWebDav.ps1',
  );
  try {
    final configFile = File(path.join(state, 'config.json'));
    if (!await configFile.exists() || !await File(script).exists()) return;
    final text = await configFile.readAsString();
    final data =
        jsonDecode(text.startsWith('\uFEFF') ? text.substring(1) : text)
            as Map<String, dynamic>;
    final host = data['host'];
    final port = data['port'];
    if (host is! String ||
        port is! int ||
        config.endpoint.scheme != 'https' ||
        config.endpoint.host != host ||
        config.endpoint.port != port ||
        config.endpoint.path != '/dav/') {
      return;
    }
    final systemRoot = Platform.environment['SystemRoot'];
    if (systemRoot == null) return;
    final powershell = path.join(
      systemRoot,
      'System32',
      'WindowsPowerShell',
      'v1.0',
      'powershell.exe',
    );
    final execute =
        run ??
        ((String command, List<String> arguments) =>
            Process.run(command, arguments));
    await execute(powershell, [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      script,
      '-StateDirectory',
      state,
    ]);
  } on FileSystemException {
    // Sync still works offline if the optional local service cannot start.
  } on FormatException {
    // An incomplete service setup must not prevent the app from opening.
  } on TypeError {
    // Treat malformed local setup as unavailable, without changing it.
  } on ProcessException {
    // Existing sync error handling will report the unreachable service.
  }
}
