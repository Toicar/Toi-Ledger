import '../../l10n/app_strings.dart';
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
import 'language_card.dart';
import '../../updates/update_ui.dart';

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
        message = context.l10n.useTheSameLedgerIdAnd;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          message = context.l10n.couldNotReadSecureCredentialsCheck;
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
      message = context.l10n.checkingHttpsReadWriteAccessAnd;
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
          () => message = save
              ? context.l10n.verifiedAndSecurelySavedReturnHome
              : context.l10n.connectionTestPassedConfigurationHasNot,
        );
      }
    } catch (e) {
      if (mounted) setState(() => message = safeError(e, context));
    } finally {
      remote?.close();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.webdavSyncSettings)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const LanguageCard(),
            const SizedBox(height: 24),
            PageHeading(
              eyebrow: 'YOUR LEDGER, WITH YOU',
              title: context.l10n.yourLedgerWhereverYouAre,
              description: context.l10n.connectYourOwnWebdavServiceTo,
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
                        Text(context.l10n.connectingYourPhoneAndComputerFor),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.followThreeStepsToPrepareStorage,
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
                          label: Text(context.l10n.multiDeviceSetupGuide),
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
                        message = context.l10n.serviceDetailsFilledInLedgerId;
                      });
                    },
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: Text(context.l10n.importWebdavServiceConfig),
            ),
            if (certificateOrigin != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  context.l10n.publicCertificateAppliesOnlyToVerify(
                    certificateOrigin,
                  ),
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
                child: Text(context.l10n.removePublicCertificate),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: endpoint,
              enabled: !busy,
              decoration: InputDecoration(
                labelText: context.l10n.httpsWebdavRootMustExist,
                hintText: 'https://dav.example.invalid/dav/',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: username,
              enabled: !busy,
              decoration: InputDecoration(labelText: context.l10n.username),
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
                labelText: context.l10n.appSpecificPassword,
                suffixIcon: IconButton(
                  tooltip: showPassword
                      ? context.l10n.hidePassword
                      : context.l10n.showPassword,
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
              decoration: InputDecoration(
                labelText: context.l10n.ledgerIdEditableOnlyForAn,
              ),
            ),
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: currentId));
                      if (context.mounted) {
                        notify(context, context.l10n.ledgerIdCopied);
                      }
                    },
              icon: const Icon(Icons.copy),
              label: Text(context.l10n.copyCurrentLedgerId),
            ),
            const SizedBox(height: 16),
            Text(context.l10n.message(message)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => test(save: false),
                  child: Text(context.l10n.testConnection),
                ),
                FilledButton(
                  onPressed: busy ? null : () => test(save: true),
                  child: Text(context.l10n.verifyAndSave),
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
                              setState(
                                () => message = context
                                    .l10n
                                    .syncDisconnectedLocalDataIsRetained,
                              );
                            }
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => message = context
                                    .l10n
                                    .couldNotRemoveCredentialsTryAgain,
                              );
                            }
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  child: Text(context.l10n.disconnectSync),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(context.l10n.credentialsUseSystemSecureStorageWebdav),
            const SizedBox(height: 24),
            const UpdateSettingsCard(),
          ],
        ),
      ),
    ),
  );
}
