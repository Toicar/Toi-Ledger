import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/ui_common.dart';
import '../../domain/operation.dart';
import '../../app/design_components.dart';
import '../../sync/webdav.dart';
import 'sync_guide_page.dart';
import 'service_import_dialog.dart';
import '../../sync/service_setup.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final endpoint = TextEditingController(),
      username = TextEditingController(),
      password = TextEditingController(),
      ledger = TextEditingController();
  String currentId = '', message = '加载中…';
  String? savedEndpoint, savedUsername;
  String? certificatePem, certificateOrigin, savedCertificatePem;
  bool busy = true, showPassword = false;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final id = await ref.read(repositoryProvider).ledgerId;
      final config = await ref.read(credentialProvider).read();
      if (!mounted) return;
      currentId = id;
      ledger.text = id;
      if (config != null) {
        savedEndpoint = config.endpoint.toString();
        savedUsername = config.username;
        certificatePem = savedCertificatePem = config.certificatePem;
        certificateOrigin = config.certificateOrigin;
        endpoint.text = config.endpoint.toString();
        username.text = config.username;
        password.text = config.password;
      }
      setState(() {
        busy = false;
        message = '在另一台空设备中填入相同账本 ID 和 WebDAV 配置。';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          message = '安全凭据存储读取失败，请检查系统解锁状态';
        });
      }
    }
  }

  @override
  void dispose() {
    endpoint.dispose();
    username.dispose();
    password.dispose();
    ledger.dispose();
    super.dispose();
  }

  Future<void> test({required bool save}) async {
    setState(() {
      busy = true;
      message = '正在检查 HTTPS、读写权限和条件写入…';
    });
    WebDavStore? remote;
    try {
      final id = requireUuid(ledger.text.trim());
      final config = DavConfig(
        endpoint: endpoint.text.trim(),
        username: username.text,
        password: password.text,
        certificatePem: certificatePem,
        certificateOrigin: certificateOrigin,
      );
      remote = WebDavStore(config, id);
      await remote.testConnection();
      if (save) {
        if (id != currentId) {
          await ref.read(repositoryProvider).joinEmptyLedger(id);
        }
        await ref.read(credentialProvider).write(config);
        currentId = id;
        savedEndpoint = config.endpoint.toString();
        savedUsername = config.username;
        savedCertificatePem = config.certificatePem;
      }
      if (mounted) {
        setState(
          () => message = save ? '已验证并安全保存。返回首页后开始同步。' : '连接测试通过；尚未保存配置。',
        );
      }
    } catch (e) {
      if (mounted) setState(() => message = safeError(e));
    } finally {
      remote?.close();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('WebDAV 同步设置')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const PageHeading(
              eyebrow: 'YOUR LEDGER, WITH YOU',
              title: '让账本，随设备同行。',
              description: '连接自己的 WebDAV，在设备之间同步记录。',
            ),
            PaperPanel(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.devices_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('第一次连接手机与电脑？'),
                        const SizedBox(height: 6),
                        const Text(
                          '按照三步指引准备同步空间、连接设备并核对记录。离线时，也可以继续记账。',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const ValueKey('open-sync-guide'),
                          onPressed: busy
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    settings: const RouteSettings(
                                      name: '/settings/guide',
                                    ),
                                    builder: (_) => SyncGuidePage(
                                      ledgerId: currentId,
                                      savedEndpoint: savedEndpoint,
                                      savedUsername: savedUsername,
                                      savedCertificatePem: savedCertificatePem,
                                    ),
                                  ),
                                ),
                          icon: const Icon(Icons.route_outlined, size: 18),
                          label: const Text('多设备连接指引'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final setup = await showDialog<ServiceSetup>(
                        context: context,
                        builder: (_) => const ServiceImportDialog(),
                      );
                      if (setup == null || !mounted) return;
                      setState(() {
                        endpoint.text = setup.endpoint.toString();
                        username.text = setup.username;
                        certificatePem = setup.certificatePem;
                        certificateOrigin = setup.endpoint.origin;
                        message = '服务配置已填入，账本 ID 未改变。请输入应用专用密码，再验证并保存。';
                      });
                    },
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('导入 WebDAV 服务配置'),
            ),
            if (certificateOrigin != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  '公共证书仅用于 $certificateOrigin；配置验证并保存后生效。',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (certificateOrigin != null)
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        certificatePem = null;
                        certificateOrigin = null;
                      }),
                child: const Text('移除此公共证书'),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: endpoint,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'HTTPS WebDAV 根目录（必须已存在）',
                hintText: 'https://dav.example.invalid/dav/',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: username,
              enabled: !busy,
              decoration: const InputDecoration(labelText: '用户名'),
              autocorrect: false,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: password,
              enabled: !busy,
              obscureText: !showPassword,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: '应用专用密码',
                suffixIcon: IconButton(
                  tooltip: showPassword ? '隐藏密码' : '显示密码',
                  onPressed: busy
                      ? null
                      : () => setState(() => showPassword = !showPassword),
                  icon: Icon(
                    showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ledger,
              enabled: !busy,
              decoration: const InputDecoration(labelText: '账本 ID（只有空账本可以修改）'),
            ),
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: currentId));
                      if (context.mounted) notify(context, '账本 ID 已复制');
                    },
              icon: const Icon(Icons.copy),
              label: const Text('复制当前账本 ID'),
            ),
            const SizedBox(height: 16),
            Text(message),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => test(save: false),
                  child: const Text('测试连接'),
                ),
                FilledButton(
                  onPressed: busy ? null : () => test(save: true),
                  child: const Text('验证并保存'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          try {
                            await ref.read(credentialProvider).clear();
                            password.clear();
                            savedEndpoint = null;
                            savedUsername = null;
                            savedCertificatePem = certificatePem =
                                certificateOrigin = null;
                            showPassword = false;
                            if (mounted) {
                              setState(() => message = '已断开同步，本地数据保留');
                            }
                          } catch (_) {
                            if (mounted) setState(() => message = '凭据删除失败，请重试');
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  child: const Text('断开同步'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              '凭据保存在系统安全存储中。账目日志以明文 JSON 存放在 WebDAV，HTTPS 保护传输；第一阶段没有端到端加密。\n\n自动同步仅在应用运行时每 60 秒及恢复前台时执行，离线操作会留在本地，等待下次同步。不要删除或修改远端日志。',
            ),
          ],
        ),
      ),
    ),
  );
}
