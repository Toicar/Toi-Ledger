import 'package:flutter/material.dart';
import '../../app/ui_common.dart';
import '../../sync/service_setup.dart';

class ServiceImportDialog extends StatefulWidget {
  const ServiceImportDialog({super.key});
  @override
  State<ServiceImportDialog> createState() => _ServiceImportDialogState();
}

class _ServiceImportDialogState extends State<ServiceImportDialog> {
  final input = TextEditingController();
  ServiceSetup? preview;
  String? error;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('导入 WebDAV 服务配置'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '在自己的电脑运行 WebDAV 设置向导，再用记事本打开 service-setup.json，复制全文粘贴到这里。此文件只含公共服务配置。',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: input,
              maxLines: 7,
              maxLength: 24576,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: '公共服务配置 JSON',
                errorText: error,
                errorMaxLines: 4,
              ),
              onChanged: (_) => setState(() {
                preview = null;
                error = null;
              }),
            ),
            if (preview case final setup?) ...[
              const SizedBox(height: 12),
              Text('服务地址：${setup.endpoint}\n用户名：${setup.username}'),
              const SizedBox(height: 10),
              const Text('公共证书 SHA-256（按文件内容计算）'),
              SelectableText(setup.fingerprint),
              const SizedBox(height: 10),
              const Text(
                '请与电脑向导显示的指纹核对。确认后仅为此 HTTPS 地址信任该证书，不修改系统信任；密码仍需单独输入，账本 ID 保持原值。',
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      if (preview == null)
        FilledButton(
          onPressed: () {
            try {
              setState(() {
                preview = ServiceSetup.decode(input.text);
                error = null;
              });
            } catch (e) {
              setState(() => error = safeError(e));
            }
          },
          child: const Text('检查配置'),
        )
      else
        FilledButton(
          onPressed: () => Navigator.pop(context, preview),
          child: const Text('信任此服务并填入'),
        ),
    ],
  );
}
