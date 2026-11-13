import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_ledger/updates/update_service.dart';
import 'support.dart';

void main() {
  final bytes = utf8.encode('verified update bytes');
  final digest = sha256.convert(bytes).toString();
  String manifest({
    int build = currentBuildNumber + 1,
    String url = 'https://updates.example/app.zip',
    String? hash,
  }) => jsonEncode({
    'schema': 1,
    'version': '0.7.0',
    'build': build,
    'notes': {'zh': '更新', 'en': 'Update'},
    'platforms': {
      'windows': {'url': url, 'sha256': hash ?? digest, 'size': bytes.length},
    },
  });

  test('application build constant agrees with pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      contains('version: $currentVersionName+$currentBuildNumber'),
    );
  });

  test(
    'source must be explicit HTTPS without embedded credentials or query',
    () async {
      var requests = 0;
      final service = UpdateService(
        client: MockClient((request) async {
          requests++;
          return http.Response.bytes(utf8.encode(manifest()), 200);
        }),
      );
      addTearDown(service.close);
      expect(await service.check('', 'windows'), isNull);
      expect(requests, 0);
      for (final bad in [
        'http://updates.example/list.json',
        'https://u:p@updates.example/list.json',
        'https://updates.example/list.json?token=x',
      ]) {
        await expectLater(service.check(bad, 'windows'), throwsFormatException);
      }
      expect(requests, 0);
      expect(
        (await service.check(
          'https://updates.example/list.json',
          'windows',
        ))?.build,
        currentBuildNumber + 1,
      );
    },
  );

  test(
    'rejects malformed, cross-origin, old, and oversized metadata',
    () async {
      expect(() => parseUpdateManifest('{}', 'windows'), throwsFormatException);
      expect(
        () => parseUpdateManifest(manifest(hash: 'bad'), 'windows'),
        throwsFormatException,
      );
      expect(
        () => parseUpdateManifest(manifest(), 'android'),
        throwsFormatException,
      );
      final cross = UpdateService(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(manifest(url: 'https://elsewhere.example/app.zip')),
            200,
          ),
        ),
      );
      addTearDown(cross.close);
      await expectLater(
        cross.check('https://updates.example/list.json', 'windows'),
        throwsFormatException,
      );
      final old = UpdateService(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(manifest(build: currentBuildNumber)),
            200,
          ),
        ),
      );
      addTearDown(old.close);
      expect(
        await old.check('https://updates.example/list.json', 'windows'),
        isNull,
      );
      final huge = UpdateService(
        client: MockClient((_) async => http.Response('x' * 65537, 200)),
      );
      addTearDown(huge.close);
      await expectLater(
        huge.check('https://updates.example/list.json', 'windows'),
        throwsFormatException,
      );
    },
  );

  test(
    'download checks exact size and SHA-256 and removes damaged files',
    () async {
      final temp = await Directory.systemTemp.createTemp('ledger-update-test-');
      addTearDown(() => temp.delete(recursive: true));
      final file = File('${temp.path}/package.zip');
      final service = UpdateService(
        client: MockClient((_) async => http.Response.bytes(bytes, 200)),
      );
      addTearDown(service.close);
      await service.download(
        UpdatePackage(
          Uri.parse('https://updates.example/app.zip'),
          digest,
          bytes.length,
        ),
        file,
      );
      expect(await file.readAsBytes(), bytes);
      await expectLater(
        service.download(
          UpdatePackage(
            Uri.parse('https://updates.example/app.zip'),
            '0' * 64,
            bytes.length,
          ),
          file,
        ),
        throwsFormatException,
      );
      expect(await file.exists(), isFalse);
    },
  );

  test('update URL is optional and saved only to local settings', () async {
    final repo = memoryRepository();
    addTearDown(repo.db.close);
    final prefs = UpdatePreferences(repo.db);
    expect(await prefs.read(), '');
    await prefs.write('https://updates.example/list.json');
    expect(await prefs.read(), 'https://updates.example/list.json');
    await expectLater(
      prefs.write('http://insecure.example/'),
      throwsFormatException,
    );
    expect(await prefs.read(), 'https://updates.example/list.json');
    expect(await repo.allOperations(), isEmpty);
  });
}
