import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../sync/webdav.dart';

abstract interface class CredentialStore {
  Future<DavConfig?> read();
  Future<void> write(DavConfig config);
  Future<void> clear();
}

class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
    : storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );
  final FlutterSecureStorage storage;
  static const _key = 'myledger.webdav.v1';
  @override
  Future<DavConfig?> read() async {
    final value = await storage.read(key: _key);
    return value == null
        ? null
        : DavConfig.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  @override
  Future<void> write(DavConfig config) =>
      storage.write(key: _key, value: jsonEncode(config.toJson()));
  @override
  Future<void> clear() => storage.delete(key: _key);
}
