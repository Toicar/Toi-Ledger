import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../data/database.dart';

// Kept in sync with pubspec.yaml by test/update_service_test.dart.
const currentBuildNumber = 14;
const currentVersionName = '0.6.0';

class UpdatePackage {
  const UpdatePackage(this.url, this.sha256, this.size);
  final Uri url;
  final String sha256;
  final int size;
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

class UpdateRelease {
  const UpdateRelease(this.build, this.version, this.notes, this.package);
  final int build;
  final String version;
  final Map<String, String> notes;
  final UpdatePackage package;
}

Uri updateHttpsUri(String value) {
  final uri = Uri.parse(value);
  if (uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.hasQuery) {
    throw const FormatException('Invalid update URL');
  }
  return uri;
}

UpdateRelease parseUpdateManifest(String body, String platform) {
  final value = jsonDecode(body);
  if (value is! Map<String, dynamic> ||
      value['schema'] != 1 ||
      value['build'] is! int ||
      (value['build'] as int) < 1 ||
      value['version'] is! String ||
      !RegExp(
        r'^\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.\-]+)?$',
      ).hasMatch(value['version'] as String)) {
    throw const FormatException('Invalid update manifest');
  }
  final platforms = value['platforms'];
  final package = platforms is Map<String, dynamic>
      ? platforms[platform]
      : null;
  if (package is! Map<String, dynamic> ||
      package['url'] is! String ||
      package['sha256'] is! String ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(package['sha256'] as String) ||
      package['size'] is! int ||
      (package['size'] as int) < 1 ||
      (package['size'] as int) > 268435456) {
    throw const FormatException('Invalid update package');
  }
  final rawNotes = value['notes'];
  if (rawNotes is! Map<String, dynamic> ||
      rawNotes['zh'] is! String ||
      rawNotes['en'] is! String ||
      (rawNotes['zh'] as String).length > 4000 ||
      (rawNotes['en'] as String).length > 4000) {
    throw const FormatException('Invalid release notes');
  }
  return UpdateRelease(
    value['build'] as int,
    value['version'] as String,
    {'zh': rawNotes['zh'] as String, 'en': rawNotes['en'] as String},
    UpdatePackage(
      updateHttpsUri(package['url'] as String),
      package['sha256'] as String,
      package['size'] as int,
    ),
  );
}

class UpdatePreferences {
  UpdatePreferences(this.db);
  final LedgerDatabase db;
  Future<String> read() async {
    final row = await (db.select(
      db.settings,
    )..where((s) => s.key.equals('updates.manifestUrl'))).getSingleOrNull();
    return row?.value ?? '';
  }

  Future<void> write(String value) async {
    if (value.isNotEmpty) updateHttpsUri(value);
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: 'updates.manifestUrl', value: value),
        );
  }
}

class UpdateService {
  UpdateService({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  void close() => client.close();

  Future<http.StreamedResponse> _request(Uri uri) async {
    final request = http.Request('GET', uri)..followRedirects = false;
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw const HttpException('Update server request failed');
    }
    return response;
  }

  Future<UpdateRelease?> check(String source, String platform) async {
    if (source.isEmpty) return null;
    final response = await _request(updateHttpsUri(source));
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 20),
    )) {
      bytes.addAll(chunk);
      if (bytes.length > 65536) {
        throw const FormatException('Update manifest too large');
      }
    }
    final release = parseUpdateManifest(utf8.decode(bytes), platform);
    if (release.package.url.origin != updateHttpsUri(source).origin) {
      throw const FormatException(
        'Update package must use the configured origin',
      );
    }
    return release.build > currentBuildNumber ? release : null;
  }

  Future<void> download(UpdatePackage package, File destination) async {
    final response = await _request(package.url);
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
