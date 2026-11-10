import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../domain/operation.dart';

http.Client createWebDavClient(
  Uri endpoint, {
  String localOrigin = const String.fromEnvironment(
    'MYLEDGER_LOCAL_DAV_ORIGIN',
  ),
  String certificateBase64 = const String.fromEnvironment(
    'MYLEDGER_LOCAL_DAV_CA_BASE64',
  ),
}) {
  if (localOrigin.isEmpty && certificateBase64.isEmpty) return http.Client();

  HttpClient? localClient;
  http.Client? publicClient;
  try {
    final origin = Uri.parse(localOrigin);
    // Accept only DNS/IPv4 or bracketed IPv6 before URI normalization.
    final originOnly = RegExp(
      r'https://(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?'
      r'(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)*\.?'
      r'|\[[0-9a-f:.]+\])(?::[0-9]+)?/?',
      caseSensitive: false,
    );
    if (certificateBase64.isEmpty ||
        originOnly.matchAsPrefix(localOrigin)?.end != localOrigin.length ||
        origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        localOrigin.contains('@') ||
        (origin.path.isNotEmpty && origin.path != '/') ||
        origin.hasQuery ||
        origin.hasFragment ||
        origin.port < 1 ||
        origin.port > 65535) {
      throw const FormatException();
    }
    final context = SecurityContext(withTrustedRoots: true)
      ..setTrustedCertificatesBytes(base64Decode(certificateBase64));
    if (!_sameOrigin(endpoint, origin)) return http.Client();

    localClient = HttpClient(context: context);
    publicClient = http.Client();
    return _OriginScopedClient(origin, IOClient(localClient), publicClient);
  } catch (_) {
    localClient?.close(force: true);
    publicClient?.close();
    throw const LedgerException('本地 WebDAV HTTPS 配置无效，请检查 origin 和 CA 证书');
  }
}

bool _sameOrigin(Uri a, Uri b) =>
    a.scheme == b.scheme && a.host == b.host && a.port == b.port;

class _OriginScopedClient extends http.BaseClient {
  _OriginScopedClient(this.origin, this.localClient, this.publicClient);
  final Uri origin;
  final http.Client localClient, publicClient;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!_sameOrigin(request.url, origin)) return publicClient.send(request);
    // Redirects must not carry this origin's additional CA trust elsewhere.
    request.followRedirects = false;
    return localClient.send(request);
  }

  @override
  void close() {
    localClient.close();
    publicClient.close();
  }
}
