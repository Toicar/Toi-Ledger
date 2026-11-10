import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../domain/operation.dart';
import 'webdav.dart';

/// Public pairing document. Never accepts passwords, private keys or ledger IDs.
class ServiceSetup {
  ServiceSetup._(this.endpoint, this.username, this.certificatePem);
  final Uri endpoint;
  final String username, certificatePem;
  String get fingerprint =>
      sha256.convert(utf8.encode(certificatePem)).toString();

  static ServiceSetup decode(String text) {
    try {
      if (text.length > 24576) throw const FormatException();
      final value = jsonDecode(text.trim()) as Map<String, dynamic>;
      const keys = {'version', 'endpoint', 'username', 'caPem'};
      if (value.length != keys.length ||
          !value.keys.toSet().containsAll(keys) ||
          value['version'] != 1 ||
          value['endpoint'] is! String ||
          value['username'] is! String ||
          value['caPem'] is! String) {
        throw const FormatException();
      }
      final endpoint = Uri.parse(value['endpoint'] as String);
      final config = DavConfig(
        endpoint: endpoint.toString(),
        username: value['username'] as String,
        password: '',
        certificateOrigin: endpoint.origin,
        certificatePem: value['caPem'] as String,
      );
      return ServiceSetup._(
        config.endpoint,
        config.username,
        config.certificatePem!,
      );
    } catch (_) {
      throw const LedgerException(
        '服务配置无效，请粘贴向导生成的完整 service-setup.json；不要粘贴密码或私钥。',
      );
    }
  }

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'version': 1,
    'endpoint': endpoint.toString(),
    'username': username,
    'caPem': certificatePem,
  });
}
