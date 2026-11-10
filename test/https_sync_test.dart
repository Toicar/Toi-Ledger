import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/data/ledger_repository.dart';
import 'package:my_ledger/sync/sync_engine.dart';
import 'package:my_ledger/sync/webdav.dart';
import 'support.dart';

void main() {
  test(
    'two databases synchronize through a real local HTTPS DAV endpoint',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'myledger-tls-test-',
      );
      final cert = '${directory.path}/certificate.pem',
          key = '${directory.path}/private.key';
      final generated = await Process.run('openssl', [
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-nodes',
        '-keyout',
        key,
        '-out',
        cert,
        '-days',
        '1',
        '-subj',
        '/CN=127.0.0.1',
        '-addext',
        'subjectAltName=IP:127.0.0.1',
      ]);
      expect(
        generated.exitCode,
        0,
        reason: 'OpenSSL must generate a disposable test certificate',
      );
      final serverContext = SecurityContext()
        ..useCertificateChain(cert)
        ..usePrivateKey(key);
      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        serverContext,
      );
      final files = <String, String>{}, directories = <String>{};
      final serving = server.forEach((request) async {
        final response = request.response;
        response.headers.contentType = ContentType(
          'application',
          'xml',
          charset: 'utf-8',
        );
        if (request.headers.value('authorization') !=
            'Basic ${base64Encode(utf8.encode('test-user:test-password'))}') {
          response.statusCode = 401;
          await response.close();
          return;
        }
        final path = request.uri.path;
        switch (request.method) {
          case 'MKCOL':
            response.statusCode = directories.add(path) ? 201 : 405;
          case 'PROPFIND':
            expect(request.headers.value('depth'), '1');
            response.statusCode = 207;
            response.write(
              '<d:multistatus xmlns:d="DAV:">${files.keys.where((p) => p.startsWith(path)).map((p) => '<d:response><d:href>$p</d:href><d:propstat><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>').join()}</d:multistatus>',
            );
          case 'PUT':
            expect(request.headers.value('if-none-match'), '*');
            final body = await utf8.decoder.bind(request).join();
            if (files.containsKey(path)) {
              response.statusCode = 412;
            } else {
              files[path] = body;
              response.statusCode = 201;
            }
          case 'GET':
            response.statusCode = files.containsKey(path) ? 200 : 404;
            if (files.containsKey(path)) response.write(files[path]);
          case 'DELETE':
            files.remove(path);
            response.statusCode = 204;
          default:
            response.statusCode = 405;
        }
        await response.close();
      });
      final a = memoryRepository(), b = memoryRepository();
      WebDavStore? davA, davB;
      try {
        await b.joinEmptyLedger(await a.ledgerId);
        final config = DavConfig(
          endpoint: 'https://127.0.0.1:${server.port}/dav/',
          username: 'test-user',
          password: 'test-password',
          certificateOrigin: 'https://127.0.0.1:${server.port}',
          certificatePem: await File(cert).readAsString(),
        );
        davA = WebDavStore(config, await a.ledgerId);
        davB = WebDavStore(
          DavConfig.fromJson(config.toJson()),
          await b.ledgerId,
        );
        await davA.testConnection();
        final cat = await category(a);
        final op = await entry(a, cat);
        final engineA = SyncEngine(a, davA), engineB = SyncEngine(b, davB);
        await engineA.synchronize();
        await engineB.synchronize();
        expect(
          LedgerRepository.monthly(await b.snapshot(), '2026-10').expense,
          1234,
        );
        await edit(b, op, amount: 8888);
        await engineB.synchronize();
        await engineA.synchronize();
        expect(
          LedgerRepository.monthly(await a.snapshot(), '2026-10').expense,
          8888,
        );
        expect(files.length, 3);
        expect(files.keys.any((p) => p.contains('.probe-')), false);
      } finally {
        davA?.close();
        davB?.close();
        await server.close(force: true);
        await serving;
        await a.db.close();
        await b.db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
