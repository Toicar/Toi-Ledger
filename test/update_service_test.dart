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
  const releaseBase = 'https://github.com/Toicar/Toi-Ledger/releases/download/';
  String release({
    String version = '1.0.1',
    String? url,
    String? hash,
    bool draft = false,
    bool prerelease = false,
  }) {
    final name = 'Toi-Ledger-$version-windows-x64.zip';
    return jsonEncode({
      'tag_name': 'v$version',
      'draft': draft,
      'prerelease': prerelease,
      'assets': [
        {
          'name': name,
          'state': 'uploaded',
          'browser_download_url': url ?? '${releaseBase}v$version/$name',
          'digest': 'sha256:${hash ?? digest}',
          'size': bytes.length,
        },
      ],
    });
  }

  test('application build constant agrees with pubspec', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('version: $currentVersionName+$currentBuildNumber'),
    );
  });

  test('compares stable versions numerically', () {
    expect(isNewerVersion('1.10.0', '1.9.9'), isTrue);
    expect(isNewerVersion('2.0.0', '1.99.99'), isTrue);
    expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
    expect(isNewerVersion('0.99.99', '1.0.0'), isFalse);
    expect(() => isNewerVersion('1.0.1-beta', '1.0.0'), throwsFormatException);
  });

  test(
    'checks only the official public GitHub latest release endpoint',
    () async {
      final service = UpdateService(
        client: MockClient((request) async {
          expect(request.url, githubLatestRelease);
          expect(request.followRedirects, isFalse);
          expect(request.headers['User-Agent'], 'Toi-Ledger');
          return http.Response.bytes(utf8.encode(release()), 200);
        }),
      );
      addTearDown(service.close);
      expect((await service.check('windows'))?.version, '1.0.1');
      final same = UpdateService(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(release(version: currentVersionName)),
            200,
          ),
        ),
      );
      addTearDown(same.close);
      expect(await same.check('windows'), isNull);
    },
  );

  test('rejects drafts, bad checksums, wrong assets and untrusted URLs', () {
    expect(() => parseGithubRelease('{}', 'windows'), throwsFormatException);
    expect(
      () => parseGithubRelease(release(draft: true), 'windows'),
      throwsFormatException,
    );
    expect(
      () => parseGithubRelease(release(prerelease: true), 'windows'),
      throwsFormatException,
    );
    expect(
      () => parseGithubRelease(release(hash: 'bad'), 'windows'),
      throwsFormatException,
    );
    expect(
      () => parseGithubRelease(release(), 'android'),
      throwsFormatException,
    );
    expect(
      () => parseGithubRelease(
        release(url: 'https://example.com/app.zip'),
        'windows',
      ),
      throwsFormatException,
    );
    expect(
      () => parseGithubRelease(
        release(
          url:
              '${releaseBase}v1.0.1/Toi-Ledger-1.0.1-windows-x64.zip?token=secret',
        ),
        'windows',
      ),
      throwsFormatException,
    );
  });

  test(
    'follows only trusted HTTPS asset redirects and verifies downloads',
    () async {
      final temp = await Directory.systemTemp.createTemp('ledger-update-test-');
      addTearDown(() => temp.delete(recursive: true));
      final file = File('${temp.path}/package.zip');
      final package = parseGithubRelease(release(), 'windows').package;
      final service = UpdateService(
        client: MockClient((request) async {
          if (request.url.host == 'github.com') {
            return http.Response(
              '',
              302,
              headers: {
                'location':
                    'https://release-assets.githubusercontent.com/file?signature=example',
              },
            );
          }
          expect(request.url.host, 'release-assets.githubusercontent.com');
          return http.Response.bytes(bytes, 200);
        }),
      );
      addTearDown(service.close);
      await service.download(package, file);
      expect(await file.readAsBytes(), bytes);
      final bad = UpdateService(
        client: MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {'location': 'https://attacker.example/file'},
          ),
        ),
      );
      addTearDown(bad.close);
      await expectLater(bad.download(package, file), throwsFormatException);
      await expectLater(
        service.download(
          UpdatePackage(package.url, '0' * 64, bytes.length),
          file,
        ),
        throwsFormatException,
      );
      expect(await file.exists(), isFalse);
    },
  );

  test('automatic checks default on and can be disabled locally', () async {
    final repo = memoryRepository();
    addTearDown(repo.db.close);
    final prefs = UpdatePreferences(repo.db);
    expect(await prefs.readEnabled(), isTrue);
    await prefs.writeEnabled(false);
    expect(await prefs.readEnabled(), isFalse);
    await prefs.writeEnabled(true);
    expect(await prefs.readEnabled(), isTrue);
    expect(await repo.allOperations(), isEmpty);
  });
}
