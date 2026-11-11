import '../../l10n/app_strings.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/design_components.dart';
import '../../app/ui_common.dart';

/// Only non-secret, saved connection fields may enter the guide or clipboard.
String syncConnectionSummary({
  BuildContext? context,
  required String ledgerId,
  required String? endpoint,
  required String? username,
}) {
  final strings = context == null
      ? const AppStrings(Locale('zh', 'CN'))
      : context.l10n;
  return [
    strings.myledgerConnectionDetailsNoPassword,
    if (endpoint != null) strings.webdavRoot(endpoint),
    if (username != null) strings.username2(username),
    strings.ledgerId(ledgerId),
    strings.enterTheAppSpecificPasswordSeparately,
  ].join('\n');
}

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
      if (mounted) notify(context, context.l10n.copyFailedSelectAndCopyThe);
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
    appBar: AppBar(title: Text(context.l10n.multiDeviceSetupGuide)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          key: const ValueKey('sync-guide-scroll'),
          padding: const EdgeInsets.all(20),
          children: [
            PageHeading(
              eyebrow: 'ONE LEDGER, EVERY DEVICE',
              title: context.l10n.threeStepsOneConnectedLedger,
              description: context.l10n.useThisGuideOnYourPhone,
            ),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(context.l10n.firstDevice),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(context.l10n.joinALedger),
                ),
              ],
              selected: {joining},
              onSelectionChanged: (value) =>
                  setState(() => joining = value.single),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 12),
            Text(
              joining
                  ? context.l10n.thisDeviceHasNoEntriesYet
                  : context.l10n.keepThePrimaryLedgerOnThis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            step(
              1,
              joining
                  ? context.l10n.getTheOtherDeviceSConnection
                  : context.l10n.prepareWebdavStorage,
              [
                if (joining)
                  paragraph(context.l10n.onTheExistingDeviceOpenSync),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(context.l10n.sameWiFi),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(context.l10n.acrossNetworks),
                    ),
                  ],
                  selected: {localNetwork},
                  onSelectionChanged: (value) =>
                      setState(() => localNetwork = value.single),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 14),
                paragraph(
                  localNetwork
                      ? context.l10n.hostHttpsWebdavOnAComputer
                      : context.l10n.prepareAnHttpsWebdavServiceReachable,
                ),
                if (localNetwork)
                  ExpansionTile(
                    key: const ValueKey('webdav-setup-instructions'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(context.l10n.noWebdavYetSetOneUp),
                    subtitle: Text(
                      context.l10n.windowsSetupWizardNoServerNeeded,
                    ),
                    children: [
                      paragraph(
                        context.l10n.extractTheCompleteWindowsArchiveAnd,
                      ),
                      TextButton.icon(
                        onPressed: () => copy(
                          'https://www.python.org/downloads/windows/',
                          context.l10n.officialPythonDownloadUrlCopied,
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(context.l10n.copyPythonDownloadUrl),
                      ),
                      paragraph(context.l10n.openWebdavSetupAndDoubleClick),
                      paragraph(
                        context.l10n.enterADedicatedCharacterAsciiPassword,
                      ),
                      paragraph(context.l10n.ifThePhoneCannotConnectOpen),
                      paragraph(
                        context.l10n.openServiceSetupJsonCopyEverything,
                      ),
                      paragraph(
                        context.l10n.afterRestartingTheComputerUseStart,
                      ),
                    ],
                  ),
                paragraph(
                  localNetwork
                      ? context.l10n.useTheServiceHostSLan
                      : context.l10n.checkAccessFromBothThePhone,
                ),
                paragraph(context.l10n.theRootMustExistAndAllow),
              ],
            ),
            step(
              2,
              joining
                  ? context.l10n.fillTheSameDetailsOnThis
                  : context.l10n.keepThisLedgerAndSaveThe,
              [
                paragraph(
                  joining
                      ? context.l10n.returnToSyncSettingsEnterThe
                      : context.l10n.returnToSyncSettingsAndEnter,
                ),
                paragraph(context.l10n.everyDeviceSharingALedgerMust),
                paragraph(context.l10n.anEmptyDeviceHasNeverCreated),
                if (joining)
                  paragraph(context.l10n.chooseVerifyAndSaveTestConnection),
              ],
            ),
            step(3, context.l10n.completeATwoWaySync, [
              paragraph(context.l10n.firstSyncThePrimaryLedgerDevice),
              paragraph(context.l10n.addARealEntrySyncIt),
              paragraph(context.l10n.syncIsAttemptedAboutEverySeconds),
              paragraph(
                context.l10n.onlyTransactionsAndCategoriesSyncTemplates,
              ),
            ]),
            PaperPanel(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.thisDeviceSConnectionDetails,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    syncConnectionSummary(
                      context: context,
                      ledgerId: widget.ledgerId,
                      endpoint: widget.savedEndpoint,
                      username: widget.savedUsername,
                    ),
                  ),
                  if (widget.savedEndpoint == null) ...[
                    const SizedBox(height: 10),
                    Text(context.l10n.noServiceConfigurationHasBeenSaved),
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
                                  context: context,
                                  ledgerId: widget.ledgerId,
                                  endpoint: widget.savedEndpoint,
                                  username: widget.savedUsername,
                                ),
                                context
                                    .l10n
                                    .connectionDetailsCopiedWithoutPassword,
                              ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(context.l10n.copyDetailsNoPassword),
                      ),
                      TextButton(
                        onPressed: () =>
                            copy(widget.ledgerId, context.l10n.ledgerIdCopied),
                        child: Text(context.l10n.copyLedgerIdOnly),
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
                            context
                                .l10n
                                .publicServiceConfigCopiedWithoutPassword,
                          ),
                          child: Text(context.l10n.copyPublicServiceConfig),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(context.l10n.theseDetailsIncludeAUsernameAnd),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.havingTroubleConnecting,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (final (title, detail) in [
              (
                context.l10n.authenticationFailedOrAccessDenied,
                context.l10n.checkTheServiceUsernameAndApp,
              ),
              (
                context.l10n.requestTimedOutOrConnectionFailed,
                context.l10n.onTheSameWiFiCheck,
              ),
              (
                context.l10n.httpsCertificateValidationFailed,
                context.l10n.checkTheUrlAgainstTheCertificate,
              ),
              (
                context.l10n.onlyEmptyLedgersCanJoinOr,
                context.l10n.aDeviceWithTransactionOrCategory,
              ),
              (
                context.l10n.directoryOrConditionalWriteCheckFailed,
                context.l10n.ensureTheRootExistsAndAllows,
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
            Text(context.l10n.credentialsUseEachDeviceSSecure),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.backToConfiguration),
            ),
          ],
        ),
      ),
    ),
  );
}
