import '../../l10n/app_strings.dart';
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
    title: Text(context.l10n.importWebdavServiceConfig),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.runTheWebdavSetupWizardOn),
            const SizedBox(height: 16),
            TextField(
              controller: input,
              maxLines: 7,
              maxLength: 24576,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: context.l10n.publicServiceConfigJson,
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
              Text(
                context.l10n.serviceUrlUsername(setup.endpoint, setup.username),
              ),
              const SizedBox(height: 10),
              Text(context.l10n.publicCertificateShaFileContents),
              SelectableText(setup.fingerprint),
              const SizedBox(height: 10),
              Text(context.l10n.compareThisFingerprintWithTheComputer),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
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
              setState(() => error = safeError(e, context));
            }
          },
          child: Text(context.l10n.reviewConfig),
        )
      else
        FilledButton(
          onPressed: () => Navigator.pop(context, preview),
          child: Text(context.l10n.trustServiceAndFillIn),
        ),
    ],
  );
}
