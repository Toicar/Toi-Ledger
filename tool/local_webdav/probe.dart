import 'dart:convert';
import 'dart:io';

import 'package:my_ledger/sync/webdav.dart';
import 'package:my_ledger/sync/webdav_client.dart';
import 'package:uuid/uuid.dart';

Future<void> main(List<String> arguments) async {
  WebDavStore? store;
  try {
    if (arguments.length != 1) throw const FormatException();
    final directory = Directory(arguments.single).absolute;
    final settings =
        jsonDecode(await File('${directory.path}/config.json').readAsString())
            as Map<String, dynamic>;
    final password = Platform.environment['MYLEDGER_LOCAL_DAV_PASSWORD'];
    if (password == null || password.length < 20) {
      throw const FormatException();
    }
    final origin = 'https://${settings['host']}:${settings['port']}';
    final config = DavConfig(
      endpoint: '$origin/dav/',
      username: settings['username'] as String,
      password: password,
    );
    final publicCa = await File(
      '${directory.path}/certificates/ca.pem',
    ).readAsBytes();
    store = WebDavStore(
      config,
      const Uuid().v4(),
      client: createWebDavClient(
        config.endpoint,
        localOrigin: origin,
        certificateBase64: base64Encode(publicCa),
      ),
    );
    await store.testConnection();
    stdout.writeln(
      'PASS: MyLedger HTTPS WebDAV connection and atomic-create probe',
    );
  } catch (_) {
    stderr.writeln(
      'MyLedger DAV probe failed; check service and private configuration.',
    );
    exitCode = 1;
  } finally {
    store?.close();
  }
}
