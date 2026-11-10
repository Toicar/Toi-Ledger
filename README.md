# Toi-Ledger

简洁、注重生活感的个人记账应用，支持 Android 与 Windows，本地优先，可通过 WebDAV 同步账本。

## 界面预览

> 截图与演示待补充。

## 主要功能

- 收入与支出记录、分类编辑、快捷模板。
- 收支趋势、分类统计与账单明细。
- 主题色、明暗模式、纸纹与玻璃材质。
- 离线记账、WebDAV 多设备同步与配置指引。

## 下载与使用

当前版本：**0.4.2**。

前往 [Releases](https://github.com/Toicar/Toi-Ledger/releases) 下载 Android APK 或 Windows 完整包。

> 多设备同步时请统一升级至 0.4.2，再修改分类的收入／支出类型。

详细使用说明待补充。WebDAV 搭建步骤见 [设置工具说明](tool/local_webdav/README.md)。

## 本地开发

使用 Flutter **3.35.7** / Dart **3.9.2**。

```sh
flutter pub get
flutter run
```

Windows 构建需 Visual Studio C++ 桌面开发环境；Android 构建需 JDK 17 和 Android SDK。

## 项目结构

```text
lib/       应用界面、数据与同步逻辑
test/      自动化测试
assets/    图标与设计资源
tool/      开发与 WebDAV 设置工具
docs/      协议与开发文档
```

## 后续补充

- 界面截图与功能介绍
- 安装、同步与常见问题
- 开发与贡献说明
