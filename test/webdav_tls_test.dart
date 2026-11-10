import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:my_ledger/domain/operation.dart';
import 'package:my_ledger/sync/webdav_client.dart';
import 'package:my_ledger/sync/webdav.dart';
import 'package:my_ledger/sync/service_setup.dart';
import 'package:crypto/crypto.dart';

void main() {
  late _TlsFixture tls;
  setUpAll(() async => tls = await _TlsFixture.create());
  tearDownAll(() async => tls.close());

  test(
    'public service import validates fields, fingerprint and credential roundtrip',
    () async {
      final pem = utf8.decode(base64Decode(tls.certificateBase64));
      final setup = ServiceSetup.decode(
        jsonEncode({
          'version': 1,
          'endpoint': '${tls.endpoint.origin}/dav/',
          'username': 'test-user',
          'caPem': pem,
        }),
      );
      expect(setup.fingerprint, sha256.convert(utf8.encode(pem)).toString());
      expect(ServiceSetup.decode(setup.encode()).certificatePem, pem);
      final config = DavConfig(
        endpoint: setup.endpoint.toString(),
        username: setup.username,
        password: 'synthetic-password',
        certificatePem: pem,
        certificateOrigin: setup.endpoint.origin,
      );
      final restored = DavConfig.fromJson(config.toJson());
      final store = WebDavStore(
        restored,
        '11111111-1111-4111-8111-111111111111',
      );
      addTearDown(store.close);
      expect((await store.client.get(tls.endpoint)).statusCode, 200);
      expect(restored.password, 'synthetic-password');
      final unrelated = IOClient(HttpClient());
      addTearDown(unrelated.close);
      await expectLater(
        unrelated.get(tls.endpoint),
        throwsA(isA<HandshakeException>()),
      );
    },
  );

  test(
    'public service import rejects secrets, incomplete certificates and origins',
    () {
      final valid = {
        'version': 1,
        'endpoint': '${tls.endpoint.origin}/dav/',
        'username': 'test-user',
        'caPem': utf8.decode(base64Decode(tls.certificateBase64)),
      };
      for (final value in [
        {...valid, 'password': 'must-not-import'},
        {...valid, 'ledgerId': 'must-not-change'},
        {
          ...valid,
          'caPem':
              '-----BEGIN PRIVATE KEY-----\nsecret\n-----END PRIVATE KEY-----',
        },
        {
          ...valid,
          'caPem':
              '-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----',
        },
        {...valid, 'endpoint': 'http://127.0.0.1/'},
        {...valid, 'endpoint': '${tls.endpoint.origin}/?password=x'},
      ]) {
        expect(
          () => ServiceSetup.decode(jsonEncode(value)),
          throwsA(isA<LedgerException>()),
        );
      }
      final pem = valid['caPem'] as String;
      expect(
        () => DavConfig(
          endpoint: tls.endpoint.toString(),
          username: '',
          password: '',
          certificatePem: pem,
        ),
        throwsA(isA<LedgerException>()),
      );
      expect(
        () => DavConfig(
          endpoint: tls.endpoint.toString(),
          username: '',
          password: '',
          certificatePem: pem,
          certificateOrigin: tls.otherEndpoint.origin,
        ),
        throwsA(isA<LedgerException>()),
      );
    },
  );

  http.Client configured(Uri endpoint, {String? origin, String? certificate}) {
    final client = createWebDavClient(
      endpoint,
      localOrigin: origin ?? tls.endpoint.origin,
      certificateBase64: certificate ?? tls.certificateBase64,
    );
    addTearDown(client.close);
    return client;
  }

  Future<void> rejectsTls(http.Client client, Uri endpoint) => expectLater(
    client.get(endpoint).timeout(const Duration(seconds: 5)),
    throwsA(isA<HandshakeException>()),
  );

  test(
    'absent local configuration rejects an untrusted self-signed CA',
    () async {
      final client = createWebDavClient(
        tls.endpoint,
        localOrigin: '',
        certificateBase64: '',
      );
      addTearDown(client.close);
      await rejectsTls(client, tls.endpoint);
    },
  );

  test(
    'exact HTTPS origin accepts the configured CA for endpoint paths',
    () async {
      final endpoint = tls.endpoint.resolve('/dav/ledger/');
      final response = await configured(endpoint).get(endpoint);
      expect(response.statusCode, 200);
      expect(response.body, 'verified TLS');
    },
  );

  test('configured origin accepts a single trailing slash', () async {
    final client = configured(tls.endpoint, origin: '${tls.endpoint.origin}/');
    expect((await client.get(tls.endpoint)).statusCode, 200);
  });

  test('implicit and explicit HTTPS port 443 are the same origin', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final endpoint = Uri.parse('https://127.0.0.1/dav/');
      final client = configured(endpoint, origin: 'https://127.0.0.1:443');
      expect((await client.get(endpoint)).statusCode, 200);
    }, _LoopbackHttpOverrides(tls.endpoint.port));
  });

  test('different endpoint port uses public trust', () async {
    await rejectsTls(configured(tls.otherEndpoint), tls.otherEndpoint);
  });

  test('different endpoint hostname uses public trust', () async {
    final client = configured(tls.endpoint.replace(host: 'localhost'));
    await rejectsTls(client, tls.endpoint);
  });

  test('different endpoint scheme uses public trust', () async {
    final client = configured(tls.endpoint.replace(scheme: 'http'));
    await rejectsTls(client, tls.endpoint);
  });

  test(
    'a configured client never extends local trust to another origin',
    () async {
      final client = configured(tls.endpoint);
      expect((await client.get(tls.endpoint)).statusCode, 200);
      await rejectsTls(client, tls.otherEndpoint);
    },
  );

  test('a wrong configured CA rejects the server certificate', () async {
    await rejectsTls(
      configured(tls.endpoint, certificate: tls.wrongCertificateBase64),
      tls.endpoint,
    );
  });

  test('trusted CA does not bypass hostname verification', () async {
    await rejectsTls(
      configured(tls.wrongHostEndpoint, origin: tls.wrongHostEndpoint.origin),
      tls.wrongHostEndpoint,
    );
  });

  test('trusted CA does not bypass certificate expiry', () async {
    await rejectsTls(
      configured(tls.expiredEndpoint, origin: tls.expiredEndpoint.origin),
      tls.expiredEndpoint,
    );
  });

  test('local trust never follows redirects to another origin', () async {
    final response = await configured(
      tls.endpoint,
    ).get(tls.endpoint.resolve('/redirect'));
    expect(response.statusCode, 302);
    expect(response.headers['location'], tls.otherEndpoint.toString());
  });

  test(
    'adding a local CA leaves SecurityContext.defaultContext unchanged',
    () async {
      final defaultContext = SecurityContext.defaultContext;
      final client = configured(tls.endpoint);
      expect((await client.get(tls.endpoint)).statusCode, 200);
      expect(SecurityContext.defaultContext, same(defaultContext));
      final publicClient = IOClient(HttpClient(context: defaultContext));
      addTearDown(publicClient.close);
      await rejectsTls(publicClient, tls.endpoint);
    },
  );

  test('closing a configured client closes both origin routes', () async {
    final client = configured(tls.endpoint);
    expect((await client.get(tls.endpoint)).statusCode, 200);
    client.close();
    await expectLater(
      client.get(tls.endpoint),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(
      client.get(tls.otherEndpoint),
      throwsA(isA<http.ClientException>()),
    );
  });

  void rejectsConfiguration(String origin, String certificate) {
    http.Client? client;
    try {
      expect(
        () => client = createWebDavClient(
          tls.endpoint,
          localOrigin: origin,
          certificateBase64: certificate,
        ),
        throwsA(
          isA<LedgerException>().having(
            (error) => [origin, certificate]
                .where((value) => value.isNotEmpty)
                .every((value) => !error.toString().contains(value)),
            'safe message',
            isTrue,
          ),
        ),
      );
    } finally {
      client?.close();
    }
  }

  test('origin without a CA is rejected safely', () {
    rejectsConfiguration(tls.endpoint.origin, '');
  });
  test('CA without an origin is rejected safely', () {
    rejectsConfiguration('', tls.certificateBase64);
  });
  test('malformed base64 is rejected safely', () {
    rejectsConfiguration(tls.endpoint.origin, '%invalid-public-ca%');
  });
  test('base64 that is not a certificate is rejected safely', () {
    rejectsConfiguration(
      tls.endpoint.origin,
      base64Encode(utf8.encode('invalid-public-certificate')),
    );
  });
  test('malformed CA is also rejected for a different endpoint origin', () {
    rejectsConfiguration(tls.otherEndpoint.origin, '%invalid-public-ca%');
  });
  for (final origin in [
    'https://ledger.local',
    'https://LEDGER.local:443/',
    'HTTPS://ledger-01.local',
    'https://xn--bcher-kva.example/',
    'https://ledger.local.',
    'https://127.0.0.1',
    'https://127.0.0.1:8443/',
    'https://[::1]',
    'https://[2001:db8::1]:8443/',
    'https://[::ffff:192.0.2.1]:8443/',
  ]) {
    test('valid configured origin is accepted: $origin', () {
      expect(configured(Uri.parse(origin), origin: origin), isA<http.Client>());
    });
  }
  for (final origin in [
    'http://127.0.0.1',
    'https://',
    '//127.0.0.1',
    'https://[invalid',
    'https://user:password@127.0.0.1',
    'https://@127.0.0.1',
    'https://127.0.0.1/dav/',
    'https://127.0.0.1//',
    'https://127.0.0.1/.',
    'https://127.0.0.1/dav/../',
    'https://127.0.0.1?query=marker',
    'https://127.0.0.1?',
    'https://127.0.0.1#fragment-marker',
    'https://127.0.0.1#',
    'https://127.0.0.1:0',
    'https://127.0.0.1:65536',
    'https://127.0.0.1\\',
    'https://127.0.0.1:',
    'https://127.0.0.1:/',
    'https://[::1]:',
    'https://127.0.0.1 ',
    'https://ledger .local',
    'https://127.0.0.1\n',
    'https://127.\n0.0.1',
    'https://127.0.0.1\t',
    'https://127.0.0.1\r\n',
    'https://ledger%',
    'https://ledger|local',
    'https://ledger^local',
    'https://-ledger.local',
    'https://ledger-.local',
    'https://ledger..local',
  ]) {
    test(
      'invalid configured origin is rejected safely: ${jsonEncode(origin)}',
      () {
        rejectsConfiguration(origin, tls.certificateBase64);
      },
    );
  }
}

class _LoopbackHttpOverrides extends HttpOverrides {
  _LoopbackHttpOverrides(this.port);
  final int port;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..findProxy = ((uri) => 'DIRECT')
        ..connectionFactory = (uri, proxyHost, proxyPort) =>
            SecureSocket.startConnect(
              InternetAddress.loopbackIPv4,
              port,
              context: context,
            );
}

class _TlsFixture {
  _TlsFixture(this.directory);
  final Directory directory;
  final servers = <HttpServer>[];
  late final String certificateBase64, wrongCertificateBase64;
  late final Uri endpoint, otherEndpoint, wrongHostEndpoint, expiredEndpoint;

  static Future<_TlsFixture> create() async {
    final fixture = _TlsFixture(
      await Directory.systemTemp.createTemp('myledger-origin-tls-test-'),
    );
    try {
      await fixture.generateCa('ca');
      await fixture.generateCa('wrong-ca');
      fixture.certificateBase64 = base64Encode(
        await File(fixture.path('ca.pem')).readAsBytes(),
      );
      fixture.wrongCertificateBase64 = base64Encode(
        await File(fixture.path('wrong-ca.pem')).readAsBytes(),
      );
      await fixture.generateServer('server', 'IP:127.0.0.1');
      await fixture.generateServer('wrong-host', 'DNS:wrong.example.invalid');
      await fixture.generateServer('expired', 'IP:127.0.0.1', days: '-1');
      fixture.otherEndpoint = await fixture.serve('server');
      fixture.endpoint = await fixture.serve('server');
      fixture.wrongHostEndpoint = await fixture.serve('wrong-host');
      fixture.expiredEndpoint = await fixture.serve('expired');
      return fixture;
    } catch (_) {
      await fixture.close();
      rethrow;
    }
  }

  String path(String name) => '${directory.path}/$name';

  Future<void> openssl(List<String> arguments) async {
    final result = await Process.run('openssl', arguments);
    if (result.exitCode != 0) {
      throw StateError(
        'OpenSSL must generate disposable TLS test certificates',
      );
    }
  }

  Future<void> generateCa(String name) => openssl([
    'req',
    '-x509',
    '-newkey',
    'rsa:2048',
    '-nodes',
    '-keyout',
    path('$name.key'),
    '-out',
    path('$name.pem'),
    '-days',
    '1',
    '-subj',
    '/CN=MyLedger-Test-$name',
    '-addext',
    'basicConstraints=critical,CA:TRUE',
    '-addext',
    'keyUsage=critical,keyCertSign,cRLSign',
  ]);

  Future<void> generateServer(
    String name,
    String san, {
    String days = '1',
  }) async {
    await openssl([
      'req',
      '-new',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      path('$name.key'),
      '-out',
      path('$name.csr'),
      '-subj',
      '/CN=MyLedger-Test-Server',
    ]);
    await File(path('$name.ext')).writeAsString(
      'basicConstraints=critical,CA:FALSE\n'
      'keyUsage=critical,digitalSignature,keyEncipherment\n'
      'extendedKeyUsage=serverAuth\n'
      'subjectAltName=$san\n',
    );
    await openssl([
      'x509',
      '-req',
      '-in',
      path('$name.csr'),
      '-CA',
      path('ca.pem'),
      '-CAkey',
      path('ca.key'),
      '-CAcreateserial',
      '-out',
      path('$name.pem'),
      '-days',
      days,
      '-extfile',
      path('$name.ext'),
    ]);
  }

  Future<Uri> serve(String name) async {
    final context = SecurityContext()
      ..useCertificateChain(path('$name.pem'))
      ..usePrivateKey(path('$name.key'));
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    servers.add(server);
    server.listen((request) {
      if (request.uri.path == '/redirect') {
        request.response.statusCode = 302;
        request.response.headers.set('location', otherEndpoint.toString());
      } else {
        request.response.write('verified TLS');
      }
      unawaited(request.response.close());
    });
    return Uri.parse('https://127.0.0.1:${server.port}/');
  }

  Future<void> close() async {
    for (final server in servers) {
      await server.close(force: true);
    }
    await directory.delete(recursive: true);
  }
}
