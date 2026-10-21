# MyLedger

面向个人的 Android + Windows 离线记账软件，使用 Flutter / Dart、Riverpod、SQLite / Drift、HTTPS WebDAV 操作日志同步。

当前为第一阶段测试候选代码。云端 Linux 已运行格式、静态分析和自动化测试；构建、真机与提供商兼容状态必须以 [测试结果](docs/TEST_RESULTS.md) 为准。没有接入真实财务数据或真实 WebDAV 密钥。

## 功能

- 收入/支出：新增、编辑、删除、备注/分类搜索、类型筛选、月份查询与收支结余。
- 收支分类：新增、改名、归档；保留历史账目引用。
- WebDAV 设置、读写/原子条件创建连接测试、安全保存凭据。
- 离线记账、待上传日志、双向增量传输、有限重试、幂等处理、并发冲突检测与手动选择版本。
- 首次启动、恢复前台、每 60 秒及首页保存后同步；不是 Android 后台常驻服务。

当前只支持单个人民币账本，不包含转账、预算、账户余额、云账号、多币种、账单导入、通知监听。导入和通知识别保留了适配接口。

## 开发环境

- 固定 Flutter **3.35.7**（Dart **3.9.2**），Git。
- Android：JDK 17，Android SDK 36，Build Tools 35.0.0，NDK 27.0.12077973，Android 7/API24+。
- Windows：Windows 10/11 x64，Visual Studio 2022 的“使用 C++ 的桌面开发”工作负载、Windows SDK。Windows 二进制不能在 Linux 上直接编译。
- Linux 自动化测试：系统 SQLite 运行库 `libsqlite3.so.0`，OpenSSL（仅用于生成临时测试证书）。

建议在 CI/云电脑设置 `CI=true`，避免 Flutter 首次启动时探测云实例元数据；本次云端测试采用此模式。

```sh
flutter pub get --enforce-lockfile
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test --coverage --reporter expanded
```

`lib/data/database.g.dart` 和 `pubspec.lock` 随源代码提交。修改数据库后重新生成并检查差异；升级已安装应用必须显式添加迁移及迁移测试，不要删除数据库。

## 编译与安装

Android 测试包：

```sh
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

也可以将 APK 复制到 Android 设备手动安装（需允许对应来源安装应用）。调试包可用于功能测试，不是正式签名发行包。更换构建机器的调试密钥可能导致无法覆盖安装，不要直接卸载唯一数据副本。长期使用前配置稳定签名和备份恢复。

Windows（必须在 Windows 上执行）：

```powershell
flutter build windows --release
```

运行 `build/windows/x64/runner/Release/my_ledger.exe`，分发时必须复制整个 Release 目录，包括 DLL、data 等文件。目标机可能需要 Microsoft Visual C++ 2015–2022 x64 运行库。当前未制作安装器或代码签名。

开发运行：连接 Android 测试设备后 `flutter run -d <device-id>`，Windows 使用 `flutter run -d windows`。

## 使用与同步

首次使用先在“分类管理”添加收入/支出分类，再点击“记一笔”。编辑时点击记录，删除时有确认提示。金额最多两位小数，按整数分保存。现有记录类型不可改，分类可以归档。

两台设备使用相同 HTTPS WebDAV 根目录和账本 ID。第二台设备必须在添加任何记录前加入首台账本。设置保存前会进行真实连接测试。凭据在应用设置中输入，不写入 Git，也不通过 CI 配置。

遇到冲突时，所有版本会保留，用户需要选择处理；未处理的冲突账目不计入月度统计，并在首页明确标记。详细步骤见 [WebDAV 配置](docs/WEBDAV.md)，协议细节见 [同步协议](docs/SYNC_PROTOCOL.md)。

## 数据与模块

| 目录 | 职责 |
|---|---|
| lib/domain | 日志协议、精确金额、日期/字段校验、统计结果 |
| lib/data | Drift 数据库、事务仓储、系统凭据存储 |
| lib/sync | HTTPS WebDAV 传输、增量同步引擎、重试 |
| lib/features | 账目、分类、冲突处理、同步设置界面 |
| lib/app | Riverpod 依赖注入、主题、本地化、公共 UI |
| lib/extensions | 账单导入/通知候选适配接口 |
| test | 数据库、业务、协议、HTTPS、界面自动化测试 |
| .github/workflows | 验证、Android APK 与 Windows 构建 |

SQLite 位于系统应用支持目录下的 `myledger.sqlite`。凭据独立于数据库保存在系统安全存储。同步只交换不可变 JSON 操作，绝不替换数据库文件。日志和 head 投影在同一事务中更新，删除使用墓碑。时间不决定覆盖优先级。

本地 SQLite 与远端 JSON 尚未端到端加密；HTTPS 仅保护传输，远端应设为私有目录。同步不能代替完整备份。不要将数据库、日志、密钥或个人账目提交到 Git。

## 验证与开发流程

GitHub Actions 包含：格式检查 → Drift 生成差异检查 → 静态分析 → 自动化测试 → Android 调试 APK / Windows Release 目录产物。只有实际执行成功才算构建通过，配置工作流不代表已经运行。

开发使用 `feature/phase-1` 分支。GitHub 私有仓库未找到，尚未创建或推送，按用户要求等待建仓授权。完成远端准备后创建 PR，检查全部通过后再合并 main。将来用户要求转移到本地时，保留 Git 历史与分支。

- [测试结果与已知问题](docs/TEST_RESULTS.md)
- [验收标准](docs/ACCEPTANCE.md)
- [后续开发计划](docs/ROADMAP.md)
