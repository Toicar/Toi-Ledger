import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:my_ledger/sync/local_webdav_start.dart';
import 'package:my_ledger/sync/webdav.dart';

void main() {
  test('starts only the matching configured Windows service', () async {
    final root = await Directory.systemTemp.createTemp('ledger-start-test-');
    addTearDown(() => root.delete(recursive: true));
    final state = Directory(path.join(root.path, 'state'))..createSync();
    final scripts = Directory(path.join(root.path, 'app', 'webdav-setup'))
      ..createSync(recursive: true);
    File(
      path.join(scripts.path, 'Ensure-LocalWebDav.ps1'),
    ).writeAsStringSync('');
    File(
      path.join(state.path, 'config.json'),
    ).writeAsStringSync('{"host":"192.168.1.2","port":8443}');
    var starts = 0;
    Future<ProcessResult> run(String exe, List<String> args) async {
      starts++;
      expect(args, contains(state.path));
      return ProcessResult(1, 0, '', '');
    }

    DavConfig config(String endpoint) =>
        DavConfig(endpoint: endpoint, username: 'user', password: 'password');
    Future<void> attempt(String endpoint, {bool windows = true}) =>
        startLocalWebDavIfConfigured(
          config(endpoint),
          isWindows: windows,
          stateDirectory: state.path,
          executableDirectory: path.join(root.path, 'app'),
          systemRootOverride: root.path,
          run: run,
        );
    await attempt('https://192.168.1.2:8443/dav/');
    expect(starts, 1);
    await attempt('https://192.168.1.3:8443/dav/');
    await attempt('https://192.168.1.2:8444/dav/');
    await attempt('https://192.168.1.2:8443/other/');
    await attempt('https://192.168.1.2:8443/dav/', windows: false);
    expect(starts, 1);
    File(path.join(state.path, 'config.json')).writeAsStringSync('{bad json');
    await attempt('https://192.168.1.2:8443/dav/');
    expect(starts, 1);
  });
}
