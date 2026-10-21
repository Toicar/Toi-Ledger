import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_ledger/domain/operation.dart';
import 'package:my_ledger/sync/webdav.dart';
import 'support.dart';

void main() {
  final config = DavConfig(
    endpoint: 'https://dav.example.invalid/root/',
    username: 'synthetic-user',
    password: 'synthetic-password',
  );
  test('HTTPS is mandatory and URL credentials are rejected', () {
    for (final endpoint in [
      'http://dav.example.invalid/',
      'https://user:pass@dav.example.invalid/',
      'https://dav.example.invalid/?token=x',
    ]) {
      expect(
        () => DavConfig(endpoint: endpoint, username: 'x', password: 'x'),
        throwsA(isA<LedgerException>()),
      );
    }
  });
  test(
    'connection probe requires atomic create, verifies bytes and cleans up',
    () async {
      final files = <String, String>{};
      final calls = <String>[];
      final store = WebDavStore(
        config,
        uuid.v4(),
        client: MockClient((req) async {
          calls.add(req.method);
          expect(req.followRedirects, false);
          expect(req.headers['authorization'], startsWith('Basic '));
          switch (req.method) {
            case 'MKCOL':
              return http.Response('', 201);
            case 'PROPFIND':
              return http.Response('<d:multistatus xmlns:d="DAV:"/>', 207);
            case 'PUT':
              expect(req.headers['if-none-match'], '*');
              if (files.containsKey(req.url.path)) {
                return http.Response('', 412);
              }
              files[req.url.path] = req.body;
              return http.Response('', 201);
            case 'GET':
              return http.Response(files[req.url.path]!, 200);
            case 'DELETE':
              files.remove(req.url.path);
              return http.Response('', 204);
            default:
              throw StateError(req.method);
          }
        }),
      );
      await store.testConnection();
      expect(files, isEmpty);
      expect(calls.where((c) => c == 'PUT').length, 2);
      store.close();
    },
  );
  test(
    'directory rejects external hrefs, invalid statuses and nested paths',
    () async {
      final id = uuid.v4(), ledger = uuid.v4();
      for (final href in [
        'https://evil.example.invalid/$id.json',
        '/elsewhere/$id.json',
        '/root/myledger/v1/$ledger/ops/nested/$id.json',
      ]) {
        final store = WebDavStore(
          config,
          ledger,
          client: MockClient(
            (_) async => http.Response(
              '<d:multistatus xmlns:d="DAV:"><d:response><d:href>$href</d:href><d:propstat><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>',
              207,
            ),
          ),
        );
        await expectLater(store.listIds(), throwsA(isA<DavException>()));
        store.close();
      }
    },
  );
  test(
    'directory accepts DAV namespace and decodes valid operation IDs',
    () async {
      final id = uuid.v4(), ledger = uuid.v4();
      final store = WebDavStore(
        config,
        ledger,
        client: MockClient(
          (_) async => http.Response(
            '<multistatus xmlns="DAV:"><response><href>/root/myledger/v1/$ledger/ops/$id.json</href><propstat><status>HTTP/1.1 200 OK</status></propstat></response></multistatus>',
            207,
          ),
        ),
      );
      expect(await store.listIds(), {id});
      store.close();
    },
  );
  test(
    'redirects are never followed and credentials are absent from errors',
    () async {
      final store = WebDavStore(
        config,
        uuid.v4(),
        client: MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {'location': 'https://evil.example.invalid/'},
          ),
        ),
      );
      try {
        await store.listIds();
        fail('must reject');
      } catch (e) {
        expect(e, isA<DavException>());
        expect(e.toString(), isNot(contains(config.password)));
      }
      store.close();
    },
  );
  test('PUT collisions are compared, never overwritten', () async {
    final repo = memoryRepository();
    try {
      final op = await category(repo);
      final store = WebDavStore(
        config,
        op.ledgerId,
        client: MockClient(
          (req) async => req.method == 'PUT'
              ? http.Response('', 412)
              : http.Response.bytes(utf8.encode(op.encode()), 200),
        ),
      );
      await store.create(op);
      store.close();
    } finally {
      await repo.db.close();
    }
  });
}
