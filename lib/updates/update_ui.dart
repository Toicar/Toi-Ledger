import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../app/design_components.dart';
import '../app/providers.dart';
import '../l10n/app_strings.dart';
import 'update_service.dart';

const _channel = MethodChannel('io.toicar.my_ledger/updates');
bool _checking = false;

Future<void> checkForUpdates(
  BuildContext context,
  WidgetRef ref, {
  bool manual = false,
}) async {
  if (_checking || (!Platform.isWindows && !Platform.isAndroid)) return;
  _checking = true;
  final service = UpdateService();
  try {
    final enabled = await UpdatePreferences(
      ref.read(repositoryProvider).db,
    ).readEnabled();
    if (!manual && !enabled) return;
    final release = await service.check(
      Platform.isWindows ? 'windows' : 'android',
    );
    if (!context.mounted) return;
    if (release == null) {
      if (manual) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.updatesNone)));
      }
      return;
    }
    final strings = context.l10n;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.updatesAvailable(release.version)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.updatesGitHubRelease),
              const SizedBox(height: 16),
              Text(
                Platform.isWindows
                    ? strings.updatesWindowsRestart
                    : strings.updatesAndroidConfirm,
              ),
              const SizedBox(height: 8),
              Text(strings.updatesTrust),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.updatesLater),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.updatesInstall),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    await _downloadAndInstall(context, service, release);
  } catch (_) {
    if (manual && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.updatesFailure)));
    }
  } finally {
    service.close();
    _checking = false;
  }
}

Future<void> _downloadAndInstall(
  BuildContext context,
  UpdateService service,
  UpdateRelease release,
) async {
  final strings = context.l10n;
  var dialogOpen = true;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(strings.updatesDownloading)),
          ],
        ),
      ),
    ).then((_) => dialogOpen = false),
  );
  try {
    final cache = await getTemporaryDirectory();
    final directory = Directory(path.join(cache.path, 'updates'));
    await directory.create(recursive: true);
    final file = File(
      path.join(
        directory.path,
        Platform.isWindows ? 'update.zip' : 'update.apk',
      ),
    );
    await service.download(release.package, file);
    if (!context.mounted) return;
    if (dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      dialogOpen = false;
    }
    if (Platform.isAndroid) {
      final result = await _channel.invokeMethod<String>('installApk', {
        'path': file.path,
      });
      if (result == 'permission_required' && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.updatesPermission)));
      }
    } else {
      final installDir = path.dirname(Platform.resolvedExecutable);
      final script = path.join(installDir, 'updater', 'Install-Update.ps1');
      final systemRoot = Platform.environment['SystemRoot'];
      if (systemRoot == null || !await File(script).exists()) {
        throw const FileSystemException('Updater unavailable');
      }
      await Process.start(
        path.join(
          systemRoot,
          'System32',
          'WindowsPowerShell',
          'v1.0',
          'powershell.exe',
        ),
        [
          '-NoProfile',
          '-NonInteractive',
          '-WindowStyle',
          'Hidden',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          script,
          '-Archive',
          file.path,
          '-ExpectedSha256',
          release.package.sha256,
          '-InstallDirectory',
          installDir,
          '-AppPid',
          '$pid',
        ],
        mode: ProcessStartMode.detached,
      );
      await _channel.invokeMethod<void>('closeForUpdate');
    }
  } catch (_) {
    if (context.mounted) {
      if (dialogOpen) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.updatesInstallFailure)));
    }
  }
}

class UpdateSettingsCard extends ConsumerStatefulWidget {
  const UpdateSettingsCard({super.key});
  @override
  ConsumerState<UpdateSettingsCard> createState() => _UpdateSettingsCardState();
}

class _UpdateSettingsCardState extends ConsumerState<UpdateSettingsCard> {
  bool busy = true;
  bool enabled = true;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final value = await UpdatePreferences(
        ref.read(repositoryProvider).db,
      ).readEnabled();
      if (mounted) enabled = value;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.updatesSaveFailed)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save(bool value) async {
    setState(() => busy = true);
    try {
      await UpdatePreferences(
        ref.read(repositoryProvider).db,
      ).writeEnabled(value);
      if (mounted) {
        setState(() => enabled = value);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.updatesSaveFailed)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return PaperPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.updatesTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(strings.updatesCurrent(currentVersionName)),
          const SizedBox(height: 8),
          Text(strings.updatesDescription),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.updatesAutoCheck),
            value: enabled,
            onChanged: busy ? null : _save,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => checkForUpdates(context, ref, manual: true),
                child: Text(strings.updatesCheck),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
