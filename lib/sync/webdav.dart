import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';
import '../domain/operation.dart';
import 'webdav_client.dart';

class DavException extends LedgerException {
  const DavException(super.message, {this.retryable = false});
  final bool retryable;
}

class DavConfig {
  DavConfig({
    required String endpoint,
    required this.username,
    required this.password,
    this.certificatePem,
    this.certificateOrigin,
  }) : endpoint = Uri.parse(endpoint.endsWith('/') ? endpoint : '$endpoint/') {
    if (this.endpoint.scheme != 'https' ||
        this.endpoint.host.isEmpty ||
        this.endpoint.userInfo.isNotEmpty ||
        this.endpoint.hasQuery ||
        this.endpoint.hasFragment ||
        username.contains(':') ||
        username.contains('\n') ||
        password.contains('\n')) {
      throw const LedgerException('WebDAV 必须使用 HTTPS，地址不能包含凭据、查询或片段');
    }
    if ((certificatePem == null) != (certificateOrigin == null)) {
      throw const LedgerException('服务证书与地址必须成对提供');
    }
    if (certificatePem != null) {
      try {
        final origin = Uri.parse(certificateOrigin!);
        if (origin.origin != this.endpoint.origin ||
            origin.scheme != 'https' ||
            origin.host.isEmpty ||
            origin.userInfo.isNotEmpty ||
            origin.hasQuery ||
            origin.hasFragment ||
            origin.port < 1 ||
            origin.port > 65535 ||
            (origin.path.isNotEmpty && origin.path != '/') ||
            certificatePem!.length > 16384 ||
            !RegExp(
              r'^-----BEGIN CERTIFICATE-----\s+[A-Za-z0-9+/=\s]+-----END CERTIFICATE-----\s*$',
            ).hasMatch(certificatePem!)) {
          throw const FormatException();
        }
        SecurityContext(
          withTrustedRoots: true,
        ).setTrustedCertificatesBytes(utf8.encode(certificatePem!));
      } catch (_) {
        throw const LedgerException('服务公共证书或限定地址无效');
      }
    }
  }
  final Uri endpoint;
  final String username, password;
  final String? certificatePem, certificateOrigin;
  Map<String, dynamic> toJson() => {
    'endpoint': endpoint.toString(),
    'username': username,
    'password': password,
    if (certificatePem != null) 'certificatePem': certificatePem,
    if (certificateOrigin != null) 'certificateOrigin': certificateOrigin,
  };
  static DavConfig fromJson(Map<String, dynamic> json) => DavConfig(
    endpoint: json['endpoint'] as String,
    username: json['username'] as String,
    password: json['password'] as String,
    certificatePem: json['certificatePem'] as String?,
    certificateOrigin: json['certificateOrigin'] as String?,
  );
}

abstract interface class OperationStore {
  Future<void> prepare();
  Future<Set<String>> listIds();
  Future<String> read(String id);
  Future<void> create(Operation operation);
}

class WebDavStore implements OperationStore {
  WebDavStore(this.config, String ledgerId, {http.Client? client})
    : client =
          client ??
          (config.certificatePem == null
              ? createWebDavClient(config.endpoint)
              : createWebDavClient(
                  config.endpoint,
                  localOrigin: config.certificateOrigin!,
                  certificateBase64: base64Encode(
                    utf8.encode(config.certificatePem!),
                  ),
                )),
      root = config.endpoint.resolve(
        'myledger/v1/${requireUuid(ledgerId)}/ops/',
      );
  final DavConfig config;
  final http.Client client;
  final Uri root;
  static const maxOperationBytes = 128 * 1024;
  void close() => client.close();

  Future<http.Response> _request(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    String? body,
    int maxBytes = maxOperationBytes,
  }) async {
    if (uri.origin != config.endpoint.origin ||
        !uri.path.startsWith(config.endpoint.path)) {
      throw const DavException('拒绝访问 WebDAV 目录以外的地址');
    }
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll({
        'Authorization':
            'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}',
        ...headers,
      });
    if (body != null) request.body = body;
    try {
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const DavException('服务器响应超出大小限制');
        }
        bytes.addAll(chunk);
      }
      if (response.statusCode >= 300 && response.statusCode < 400) {
        throw const DavException('WebDAV 不支持重定向，请填写最终 HTTPS 地址');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const DavException('WebDAV 身份验证失败或权限不足');
      }
      if (response.statusCode == 408 ||
          response.statusCode == 429 ||
          response.statusCode >= 500) {
        throw DavException(
          'WebDAV 暂时不可用（HTTP ${response.statusCode}）',
          retryable: true,
        );
      }
      return http.Response.bytes(
        bytes,
        response.statusCode,
        headers: response.headers,
      );
    } on DavException {
      rethrow;
    } on TimeoutException {
      throw const DavException('WebDAV 请求超时', retryable: true);
    } on SocketException {
      throw const DavException('网络不可用，本地记录已保留', retryable: true);
    } on http.ClientException {
      throw const DavException('WebDAV 网络连接失败', retryable: true);
    } on HandshakeException {
      throw const DavException('HTTPS 证书验证失败');
    }
  }

  String _text(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      throw const DavException('服务器响应不是有效 UTF-8');
    }
  }

  @override
  Future<void> prepare() async {
    var path = config.endpoint;
    final relative = root.path
        .substring(config.endpoint.path.length)
        .split('/')
        .where((s) => s.isNotEmpty);
    for (final segment in relative) {
      path = path.resolve('$segment/');
      final response = await _request('MKCOL', path);
      if (response.statusCode != 201 && response.statusCode != 405) {
        throw DavException('创建同步目录失败（HTTP ${response.statusCode}）');
      }
    }
  }

  @override
  Future<Set<String>> listIds() async {
    final response = await _request(
      'PROPFIND',
      root,
      headers: {'Depth': '1', 'Content-Type': 'application/xml; charset=utf-8'},
      body:
          '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>',
      maxBytes: 8 * 1024 * 1024,
    );
    if (response.statusCode != 207) {
      throw DavException('读取 WebDAV 目录失败（HTTP ${response.statusCode}）');
    }
    final source = _text(response);
    if (source.contains('<!DOCTYPE') || source.contains('<!ENTITY')) {
      throw const DavException('目录包含不支持的 XML 声明');
    }
    try {
      final document = XmlDocument.parse(source);
      if (document.rootElement.name.local != 'multistatus' ||
          document.rootElement.name.namespaceUri != 'DAV:') {
        throw const FormatException();
      }
      final ids = <String>{};
      for (final item in document.findAllElements(
        'response',
        namespace: 'DAV:',
      )) {
        final hrefs = item.findElements('href', namespace: 'DAV:').toList();
        if (hrefs.length != 1) throw const FormatException();
        final uri = root.resolve(hrefs.single.innerText);
        if (uri.origin != root.origin ||
            uri.hasQuery ||
            uri.hasFragment ||
            uri.userInfo.isNotEmpty) {
          throw const FormatException();
        }
        if (uri.path == root.path || '${uri.path}/' == root.path) continue;
        if (!uri.path.startsWith(root.path)) throw const FormatException();
        final name = Uri.decodeComponent(uri.path.substring(root.path.length));
        if (name.startsWith('.probe-') && !name.contains('/')) continue;
        if (!name.endsWith('.json') || name.contains('/')) {
          throw const FormatException();
        }
        final id = requireUuid(name.substring(0, name.length - 5));
        final status = item
            .findAllElements('status', namespace: 'DAV:')
            .map((n) => n.innerText)
            .toList();
        if (status.isEmpty ||
            status.any((s) => !RegExp(r'^HTTP/\S+ 200(?: |$)').hasMatch(s))) {
          throw const FormatException();
        }
        ids.add(id);
      }
      return ids;
    } catch (_) {
      throw const DavException('WebDAV 目录格式或文件名无效，已停止同步');
    }
  }

  @override
  Future<String> read(String id) async {
    final response = await _request(
      'GET',
      root.resolve('${requireUuid(id)}.json'),
    );
    if (response.statusCode == 404) {
      throw const DavException('远端日志暂不可见，请稍后重试', retryable: true);
    }
    if (response.statusCode != 200) {
      throw DavException('读取日志失败（HTTP ${response.statusCode}）');
    }
    return _text(response);
  }

  @override
  Future<void> create(Operation operation) async {
    final response = await _request(
      'PUT',
      root.resolve('${operation.id}.json'),
      headers: {
        'If-None-Match': '*',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: operation.encode(),
    );
    if (response.statusCode != 201 &&
        response.statusCode != 204 &&
        response.statusCode != 412) {
      throw DavException('上传日志失败（HTTP ${response.statusCode}）');
    }
    // Read back also covers an uncertain PUT outcome and a colliding ID.
    final actual = Operation.decode(await read(operation.id));
    if (actual.canonical != operation.canonical) {
      throw const DavException('远端同名日志内容不同，禁止覆盖');
    }
  }

  /// Probe only a unique temporary file; operation logs are never deleted.
  Future<void> testConnection() async {
    await prepare();
    await listIds();
    final uri = root.resolve('.probe-${const Uuid().v4()}.json');
    var created = false;
    try {
      final first = await _request(
        'PUT',
        uri,
        headers: {'If-None-Match': '*'},
        body: '{"probe":1}',
      );
      if (first.statusCode != 201) throw const DavException('服务器未通过创建文件测试');
      created = true;
      final second = await _request(
        'PUT',
        uri,
        headers: {'If-None-Match': '*'},
        body: '{"probe":2}',
      );
      if (second.statusCode != 412) {
        throw const DavException('服务器未遵守 If-None-Match，不能安全同步');
      }
      final readback = await _request('GET', uri);
      if (readback.statusCode != 200 || _text(readback) != '{"probe":1}') {
        throw const DavException('服务器读回校验失败');
      }
    } finally {
      if (created) {
        final cleanup = await _request('DELETE', uri);
        if (cleanup.statusCode != 200 &&
            cleanup.statusCode != 204 &&
            cleanup.statusCode != 404) {
          throw const DavException('测试文件清理失败，可手动删除 .probe 文件');
        }
      }
    }
  }
}
