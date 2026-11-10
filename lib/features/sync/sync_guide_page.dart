import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/design_components.dart';
import '../../app/ui_common.dart';

/// Only non-secret, saved connection fields may enter the guide or clipboard.
String syncConnectionSummary({
  required String ledgerId,
  required String? endpoint,
  required String? username,
}) => [
  'MyLedger 多设备连接信息（不含密码）',
  if (endpoint != null) 'WebDAV 根目录：$endpoint',
  if (username != null) '用户名：$username',
  '账本 ID：$ledgerId',
  '请在另一台设备单独输入应用专用密码。',
].join('\n');

class SyncGuidePage extends StatefulWidget {
  const SyncGuidePage({
    super.key,
    required this.ledgerId,
    this.savedEndpoint,
    this.savedUsername,
    this.savedCertificatePem,
  });
  final String ledgerId;
  final String? savedEndpoint, savedUsername;
  final String? savedCertificatePem;

  @override
  State<SyncGuidePage> createState() => _SyncGuidePageState();
}

class _SyncGuidePageState extends State<SyncGuidePage> {
  bool joining = false, localNetwork = true;

  Future<void> copy(String value, String message) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (mounted) notify(context, message);
    } catch (_) {
      if (mounted) notify(context, '复制失败，请手动选择并复制连接信息');
    }
  }

  Widget step(int number, String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PaperPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text('$number', style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget paragraph(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(height: 1.65)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('多设备连接指引')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          key: const ValueKey('sync-guide-scroll'),
          padding: const EdgeInsets.all(20),
          children: [
            const PageHeading(
              eyebrow: 'ONE LEDGER, EVERY DEVICE',
              title: '三步，让记录相连。',
              description:
                  '手机与电脑使用同一份指引。先选这台设备的角色，再依次完成设置。导入服务配置需要所有设备更新至 0.4.1 或以上。',
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('首台设备')),
                ButtonSegment(value: true, label: Text('加入现有账本')),
              ],
              selected: {joining},
              onSelectionChanged: (value) =>
                  setState(() => joining = value.single),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 12),
            Text(
              joining ? '这台设备尚未记账，准备连接另一台设备上的账本。' : '这台设备保留主账本；如果已有记录，请从这台开始。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            step(1, joining ? '拿到另一台设备的连接信息' : '准备一个 WebDAV 同步空间', [
              if (joining)
                paragraph(
                  '在已有账本的设备打开“同步设置 → 多设备连接指引”，复制连接信息。你需要同一个 HTTPS 根目录、账本 ID，以及有该目录读写权限的用户名和应用专用密码。',
                ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('同一 Wi-Fi')),
                  ButtonSegment(value: false, label: Text('跨网络')),
                ],
                selected: {localNetwork},
                onSelectionChanged: (value) =>
                    setState(() => localNetwork = value.single),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 14),
              paragraph(
                localNetwork
                    ? '让电脑或 NAS 提供 HTTPS WebDAV 服务，并让手机与电脑连接同一局域网。同步期间服务主机须开机、不休眠，服务须运行；MyLedger 本身不会自动开启 WebDAV 服务。'
                    : '准备可从外网访问的 HTTPS WebDAV 服务，向服务提供方取得最终连接地址、账号和应用专用密码。局域网 IP 无法在换网络后直接访问。',
              ),
              if (localNetwork)
                ExpansionTile(
                  key: const ValueKey('webdav-setup-instructions'),
                  tilePadding: EdgeInsets.zero,
                  title: const Text('还没有 WebDAV？从零搭建'),
                  subtitle: const Text('Windows 设置向导 · 手机无需搭服务器'),
                  children: [
                    paragraph(
                      '① 在电脑解压完整 Windows 安装包，找到 webdav-setup 文件夹。先从 https://www.python.org/downloads/windows/ 安装 Python 3.12 或以上，安装后在终端运行 py --version，确认能显示版本。',
                    ),
                    TextButton.icon(
                      onPressed: () => copy(
                        'https://www.python.org/downloads/windows/',
                        'Python官方下载地址已复制',
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('复制 Python 下载地址'),
                    ),
                    paragraph(
                      '② 打开 webdav-setup，双击 Setup-WebDAV.cmd。首次会联网安装固定服务依赖。向导列出本机 IPv4，选择电脑连接 Wi-Fi 的地址；再填写手机“设置 → WLAN → 已连接网络详情”里的 IP。',
                    ),
                    paragraph(
                      '③ 在向导中隐藏输入两次专用密码（20～128位半角字符），自己妥善保留。向导生成 HTTPS 证书和私有数据目录，启动服务，并显示连接地址与证书指纹；不替换已有部署，不改变 MyLedger 账本。',
                    ),
                    paragraph(
                      '④ 若手机连不上，在该文件夹按住 Shift 点右键，选择“在终端中打开”，运行 powershell -NoProfile -File .\\Enable-LocalWebDavFirewall.ps1 -StateDirectory "\$env:LOCALAPPDATA\\MyLedger-WebDAV"。此命令需要管理员终端，只开放当前手机到该服务的端口，不要关闭整个防火墙。',
                    ),
                    paragraph(
                      '⑤ 用记事本打开向导显示的 service-setup.json，复制全部内容；在电脑和手机的“同步设置 → 导入 WebDAV 服务配置”粘贴、检查，核对向导显示的证书 SHA-256 后点击“信任此服务并填入”。公共配置不含密码；在两端单独输入刚设置的密码，再按第2步连接同一账本。',
                    ),
                    paragraph(
                      '⑥ 重启电脑后双击 Start-WebDAV.cmd，停止用 Stop-WebDAV.cmd。不需要一直打开终端，但电脑不能休眠。IP或证书变化时需更新配置；先保留旧目录内的数据和密钥，不要重装覆盖。具体恢复方式见文件夹 README.md。',
                    ),
                  ],
                ),
              paragraph(
                localNetwork
                    ? '地址使用服务主机的局域网 IP 或主机名与端口，不填手机 IP、localhost 或 127.0.0.1。路由器固定主机地址，并允许手机访问服务端口；访客网络或设备隔离会阻止互连。'
                    : '先分别用手机移动网络和电脑网络确认能访问服务。使用服务提供方给出的 WebDAV 目录地址，不填网页登录或分享链接。',
              ),
              paragraph(
                '根目录须已存在并允许读取、创建目录、写入及删除测试文件；“测试连接”还会检查防止覆盖日志的条件写入。地址必须使用 HTTPS 与受信任证书。使用本向导搭建时，通过“导入 WebDAV 服务配置”核对并信任专用公共证书；不要跳过证书验证。',
              ),
            ]),
            step(2, joining ? '在这台空设备填写相同配置' : '保留当前账本并保存配置', [
              paragraph(
                joining
                    ? '返回“同步设置”，填写另一台设备提供的 HTTPS 根目录、用户名与应用专用密码，再将“账本 ID”替换为对方复制的 ID。ID 必须完全一致，不能用这台新设备自动生成的 ID。'
                    : '返回“同步设置”，填写 HTTPS 根目录、用户名与应用专用密码。保留本机当前账本 ID，点击“验证并保存”，再回首页点击“立即同步”，先把已有记录上传。',
              ),
              paragraph(
                '同一账本的所有设备必须使用相同根目录和账本 ID。只填写 WebDAV 根目录，应用会自动创建其下的账本日志目录；不要手工追加 myledger/v1 或 ops。',
              ),
              paragraph(
                '“空设备”是从未创建过账目或分类的账本；删除全部账单后仍有历史记录，也不能直接加入。两台设备各自已有数据时，当前版本不支持自动合并，请先保留各自数据，不要清空或卸载来强行连接。',
              ),
              if (joining)
                paragraph('点击“验证并保存”。“测试连接”只验证服务，不保存配置，也不会把本机加入对方账本。'),
            ]),
            step(3, '完成一次双向同步', [
              paragraph(
                '先在保留主账本的设备回首页点击“立即同步”，看到“同步完成”；再在加入的设备保存配置、回首页点击“立即同步”，核对同一月份的账单与合计。',
              ),
              paragraph(
                '之后新增一笔真实记录，在该设备同步，再在另一台同步，确认能看到；反方向也检查一次。遇到“冲突”时，在首页选择需要保留的版本。',
              ),
              paragraph(
                '应用运行时每 60 秒及恢复前台时尝试同步，不是后台常驻服务。同 Wi-Fi 方案换网络后须回到该局域网才能同步；离线记账会保留，待重新连接。',
              ),
              paragraph('只同步账目与分类；快捷模板、主题色、材质、隐藏金额和统计门槛分别保存在各台设备。'),
            ]),
            PaperPanel(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('本机连接信息', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SelectableText(
                    syncConnectionSummary(
                      ledgerId: widget.ledgerId,
                      endpoint: widget.savedEndpoint,
                      username: widget.savedUsername,
                    ),
                  ),
                  if (widget.savedEndpoint == null) ...[
                    const SizedBox(height: 10),
                    const Text('本机尚未保存服务配置。请先返回填写并验证；这里不会复制未保存的表单内容。'),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('copy-safe-sync-info'),
                        onPressed: widget.savedEndpoint == null
                            ? null
                            : () => copy(
                                syncConnectionSummary(
                                  ledgerId: widget.ledgerId,
                                  endpoint: widget.savedEndpoint,
                                  username: widget.savedUsername,
                                ),
                                '连接信息已复制，不含密码',
                              ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('复制连接信息（不含密码）'),
                      ),
                      TextButton(
                        onPressed: () => copy(widget.ledgerId, '账本 ID 已复制'),
                        child: const Text('仅复制账本 ID'),
                      ),
                      if (widget.savedCertificatePem != null)
                        OutlinedButton(
                          onPressed: () => copy(
                            const JsonEncoder.withIndent('  ').convert({
                              'version': 1,
                              'endpoint': widget.savedEndpoint,
                              'username': widget.savedUsername,
                              'caPem': widget.savedCertificatePem,
                            }),
                            '公共服务配置已复制，不含密码',
                          ),
                          child: const Text('复制公共服务配置'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('连接信息包含用户名与账本 ID，仅提供给自己的设备。密码需在另一台设备单独输入。'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('连接遇到问题？', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final (title, detail) in const [
              (
                '身份验证失败或权限不足',
                '逐字核对服务用户名与应用专用密码，留意首尾空格及中英文字符；确认该账号能读写这个目录。网页登录密码可能与 WebDAV 专用密码不同。不要把密码发给他人或粘贴到错误反馈中。',
              ),
              (
                '请求超时或网络连接失败',
                '同 Wi-Fi：确认服务主机开机、服务运行、IP 与端口未变，手机可访问且防火墙允许；关闭访客网络或设备隔离。跨网络：确认外部 HTTPS 地址可达。检查地址和完整目录，避免填写网页登录地址。',
              ),
              (
                'HTTPS 证书验证失败',
                '核对服务地址与证书域名／IP、有效期和设备时间。自建 CA 必须被当前客户端信任；可重新导入新服务的公共配置并核对指纹，无需重新打包。已有安装包内置的专用 CA 仍仅适用于其指定服务，不能用 HTTP 替代。',
              ),
              (
                '只能空账本加入，或同步后账单不同',
                '有任何账目／分类历史的设备不能直接换账本。不要清库；保留数据后再处理迁移。若两端都显示同步完成却账单不同，核对根目录与账本 ID 完全一致、筛选月份一致，并确认所有设备已更新至 0.4.0 或以上。',
              ),
              (
                '目录或条件写入检查失败',
                '确认根目录已存在且有创建、读取、写入和删除权限，使用最终 HTTPS 地址避免重定向。服务必须支持 WebDAV 和 If-None-Match 条件创建；不要修改或删除远端的日志 JSON。',
              ),
            ])
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(title),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(detail, style: const TextStyle(height: 1.65)),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            const Text(
              '凭据保存在各设备的系统安全存储中。账目在 WebDAV 上是明文 JSON，HTTPS 保护传输，当前没有端到端加密。',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回填写配置'),
            ),
          ],
        ),
      ),
    ),
  );
}
