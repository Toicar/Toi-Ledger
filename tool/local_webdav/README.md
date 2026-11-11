# 从零设置同 Wi-Fi WebDAV

本文件夹随 MyLedger Windows 完整包提供，也可单独解压 WebDAV 工具包。手机只需 MyLedger 0.4.1或以上，不需要Python。已经正常使用的旧部署无需重新设置，本向导不会迁移或修改它。

## 首次配置

1. 电脑从 [Python官网](https://www.python.org/downloads/windows/) 安装Python3.12或以上。安装后打开终端运行 `py --version` 确认版本；没有该命令时重新打开终端或检查Python安装。向导也支持常规PATH中的python.exe。
2. 手机与电脑连同一局域网。手机“设置 → WLAN → 已连接网络详情”记下IPv4；电脑地址由向导列出，不要填手机调试端口。访客网络／无线设备隔离会阻止互访。
3. 双击 `Setup-WebDAV.cmd`。首次联网安装固定服务依赖，只安装到专用虚拟环境，不改系统Python包。选择电脑Wi-Fi IPv4，填写手机IPv4；隐藏输入两次20～128位半角非空白专用密码。自己妥善保留密码，不发送到聊天。
4. 向导在 `%LOCALAPPDATA%\MyLedger-WebDAV` 保存服务数据，ACL只允许当前用户和SYSTEM。密码用当前Windows用户DPAPI加密，不改旧环境变量；HTTPS私钥留在此私有目录。启动成功后显示地址、用户名和公共证书SHA-256（公共PEM的UTF-8内容摘要）。
5. 如手机连接失败，先核对IP／服务与网络。需要防火墙规则时，在管理员PowerShell进入本工具目录运行：

```powershell
.\Enable-LocalWebDavFirewall.ps1 -StateDirectory "$env:LOCALAPPDATA\MyLedger-WebDAV"
```

这只开放指定手机到指定电脑的TCP8443，不关闭防火墙，不开放公网。请使用创建服务的同一Windows用户提升管理员权限。若组织要求另一管理员账户，由管理员按确认的电脑IP／手机IP和8443独立添加受限规则；不要读取或放宽私有目录权限来代替。

6. 用记事本打开向导给出的 `service-setup.json`。只把此JSON的全文提供给自己的手机；文件内没有密码、私钥或账本ID。两端MyLedger打开“同步设置 → 导入WebDAV服务配置”，粘贴全文、检查、对照电脑指纹后点击“信任此服务并填入”。不会安装系统根证书，新增信任仅限指定HTTPS origin，仍检查证书地址和有效期。
7. 两端单独输入第3步设置的密码。已有记录的设备保留原账本ID，验证保存并先“立即同步”；新空设备再填相同账本ID、验证保存和同步。需要0.4.1或以上才能导入服务配置。两台各自已有数据时不自动合并，也不要清空或卸载唯一副本。

## 日常使用与恢复

- Windows 桌面版在同步地址与本机服务配置匹配时，会在打开账本并同步前自动启动服务；服务已运行时复用现有进程。标准服务目录为 `%LOCALAPPDATA%\MyLedger-WebDAV`；旧版项目目录旁的 `.local-webdav` 也可识别。服务不会随系统开机启动，关闭应用也不会自动停止服务；电脑睡眠时无法同步。
- 如需手动控制，可双击 `Start-WebDAV.cmd` 启动、`Stop-WebDAV.cmd` 停止。没有公开网络中继。
- 默认只允许所填电脑和手机IP。建议在路由器 DHCP 设置中分别为电脑和手机保留当前地址（手机需对该网络使用固定的设备 MAC）；重连后核对地址。手机IP变化：停止服务，用记事本修改私有目录config.json的phone，再更新防火墙规则中的远端手机地址并启动。增加其他设备需显式扩展服务白名单，当前向导面向一台电脑与一部手机。
- 电脑IP变化：旧证书SAN不匹配，不能只改URL。先在路由器保留原地址。若无法恢复，停止并完整保留旧状态目录，给Setup-LocalWebDav.ps1传入一个新空StateDirectory重新设置，再离线复制旧data目录到新服务的data（不得覆盖同名不同内容的日志），重新导入公共配置、更新同一账本ID。不要删除旧目录；有数据时应先由熟悉部署的人核对备份。
- 证书有效期1年。到期或遗失密码时，先保留完整状态与账本，按上述新服务迁移流程恢复；重复运行设置向导不会替换现有证书／密码或清除数据。
- 安装中断：错误信息会指出失败步骤，保留状态目录，修复依赖或权限后恢复；向导会拒绝覆盖非空的部分部署。不要通过删除整个目录处理已经使用的服务。
- DPAPI文件绑定创建它的Windows用户。不能将password.dpapi复制给另一账户当作密码；手机仍需原始专用密码。
- 备份：停止服务与各端应用，再独立备份状态目录及应用数据库；证书私钥与备份只能存自己控制的介质。HTTPS保护传输，服务端JSON和本机数据库是明文，当前无端到端加密。

CMD启动器只对本次运行设置ExecutionPolicy Bypass以执行同文件夹内的可审阅本地PowerShell，不永久改变系统执行策略。若组织策略禁止脚本，请遵循管理员规则，不要绕过组织限制。

实现沿用项目中已覆盖原子条件写入的WsgiDAV／Cheroot服务。证书生成参考[cryptography X.509官方文档](https://cryptography.io/en/latest/x509/tutorial/)，虚拟环境流程参考[Python Packaging指南](https://packaging.python.org/en/latest/guides/installing-using-pip-and-virtual-environments/)。
