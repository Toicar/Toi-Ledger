import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../app/app_version.dart';
import '../data/database.dart';
export '../app/app_version.dart';

final githubLatestRelease = Uri.https(
  'api.github.com',
  '/repos/Toicar/Toi-Ledger/releases/latest',
);
const _repositoryPath = '/Toicar/Toi-Ledger/releases/download/';

class UpdatePackage {
  const UpdatePackage(this.url, this.sha256, this.size);
  final Uri url;
  final String sha256;
  final int size;
}

class UpdateRelease {
  const UpdateRelease(this.version, this.package);
  final String version;
  final UpdatePackage package;
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

List<int> _versionParts(String value) {
  if (!RegExp(r'^\d{1,6}\.\d{1,6}\.\d{1,6}$').hasMatch(value)) {
    throw const FormatException('Invalid release version');
  }
  return value.split('.').map(int.parse).toList(growable: false);
}

bool isNewerVersion(String candidate, String current) {
  final a = _versionParts(candidate), b = _versionParts(current);
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

UpdateRelease parseGithubRelease(String body, String platform) {
  final data = jsonDecode(body);
  if (data is! Map<String, dynamic> ||
      data['draft'] != false ||
      data['prerelease'] != false ||
      data['tag_name'] is! String ||
      data['assets'] is! List) {
    throw const FormatException('Invalid GitHub release');
  }
  final tag = data['tag_name'] as String;
  if (!tag.startsWith('v')) throw const FormatException('Invalid release tag');
  final version = tag.substring(1);
  _versionParts(version);
  final suffix = switch (platform) {
    'android' => 'android-arm64.apk',
    'windows' => 'windows-x64.zip',
    _ => throw const FormatException('Unsupported update platform'),
  };
  final expectedName = 'Toi-Ledger-$version-$suffix';
  final matches = (data['assets'] as List)
      .whereType<Map<String, dynamic>>()
      .where((asset) => asset['name'] == expectedName)
      .toList();
  if (matches.length != 1) {
    throw const FormatException('Release package missing or duplicated');
  }
  final asset = matches.single;
  final digest = asset['digest'],
      size = asset['size'],
      address = asset['browser_download_url'];
  if (asset['state'] != 'uploaded' ||
      digest is! String ||
      !RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(digest) ||
      size is! int ||
      size < 1 ||
      size > 268435456 ||
      address is! String) {
    throw const FormatException('Invalid release package');
  }
  final url = Uri.parse(address);
  final expectedPath = '$_repositoryPath$tag/$expectedName';
  if (url.scheme != 'https' ||
      url.host != 'github.com' ||
      url.hasPort ||
      url.userInfo.isNotEmpty ||
      url.hasQuery ||
      url.hasFragment ||
      url.path != expectedPath) {
    throw const FormatException('Invalid GitHub package address');
  }
  return UpdateRelease(version, UpdatePackage(url, digest.substring(7), size));
}

class UpdatePreferences {
  UpdatePreferences(this.db);
  final LedgerDatabase db;
  Future<bool> readEnabled() async {
    final row = await (db.select(
      db.settings,
    )..where((s) => s.key.equals('updates.githubEnabled'))).getSingleOrNull();
    return row?.value != 'false';
  }

  Future<void> writeEnabled(bool value) => db
      .into(db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: 'updates.githubEnabled',
          value: value.toString(),
        ),
      );
}

class UpdateService {
  UpdateService({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  void close() => client.close();

  Future<http.StreamedResponse> _get(
    Uri uri, {
    bool allowGitHubRedirects = false,
  }) async {
    for (var redirects = 0; redirects <= 5; redirects++) {
      if (uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment ||
          uri.hasPort) {
        throw const FormatException('Invalid update address');
      }
      if (allowGitHubRedirects &&
          !const {
            'github.com',
            'release-assets.githubusercontent.com',
            'objects.githubusercontent.com',
          }.contains(uri.host)) {
        throw const FormatException('Untrusted update redirect');
      }
      final request = http.Request('GET', uri)..followRedirects = false;
      request.headers['User-Agent'] = 'Toi-Ledger';
      request.headers['Accept'] = allowGitHubRedirects
          ? 'application/octet-stream'
          : 'application/vnd.github+json';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) return response;
      if (!allowGitHubRedirects ||
          !const {301, 302, 303, 307, 308}.contains(response.statusCode) ||
          redirects == 5) {
        throw const HttpException('GitHub update request failed');
      }
      final location = response.headers['location'];
      if (location == null) {
        throw const FormatException('Missing redirect address');
      }
      await response.stream.drain<void>();
      uri = uri.resolve(location);
    }
    throw const HttpException('Too many redirects');
  }

  Future<UpdateRelease?> check(String platform) async {
    final response = await _get(githubLatestRelease);
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 20),
    )) {
      bytes.addAll(chunk);
      if (bytes.length > 262144) {
        throw const FormatException('GitHub release metadata too large');
      }
    }
    final release = parseGithubRelease(utf8.decode(bytes), platform);
    return isNewerVersion(release.version, currentVersionName) ? release : null;
  }

  Future<void> download(UpdatePackage package, File destination) async {
    final response = await _get(package.url, allowGitHubRedirects: true);
    final sink = destination.openWrite();
    var count = 0;
    final digestSink = _DigestSink();
    final digest = sha256.startChunkedConversion(digestSink);
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        count += chunk.length;
        if (count > package.size) {
          throw const FormatException('Update package too large');
        }
        digest.add(chunk);
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      digest.close();
      if (count != package.size ||
          digestSink.value.toString() != package.sha256) {
        throw const FormatException('Update package checksum mismatch');
      }
    } catch (_) {
      await sink.close();
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }
}
