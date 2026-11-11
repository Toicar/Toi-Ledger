import '../../l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/presentation_controller.dart';
import '../../app/ui_common.dart';
import '../../domain/operation.dart';

class UncategorizedRuleButton extends ConsumerWidget {
  const UncategorizedRuleButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(presentationProvider);
    return TextButton.icon(
      key: const ValueKey('uncategorized-rule'),
      icon: const Icon(Icons.tune_rounded, size: 17),
      label: Text(
        settings.hideAmounts
            ? context.l10n.uncategorizedDisplayRule
            : context.l10n.largeUncategorized(
                formatAmount(settings.uncategorizedThresholdMinor),
              ),
      ),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => const _RuleEditor(),
      ),
    );
  }
}

class _RuleEditor extends ConsumerStatefulWidget {
  const _RuleEditor();
  @override
  ConsumerState<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends ConsumerState<_RuleEditor> {
  final form = GlobalKey<FormState>();
  late final amount = TextEditingController(
    text: formatAmount(
      ref.read(presentationProvider).uncategorizedThresholdMinor,
    ),
  );
  bool saving = false;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await ref
          .read(presentationProvider.notifier)
          .setUncategorizedThreshold(parseAmount(amount.text));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        notify(context, safeError(error, context));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.uncategorizedDisplayRule),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.eachUncategorizedTransactionMeetingTheThreshold,
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('uncategorized-threshold-input'),
                controller: amount,
                enabled: !saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.largeEntryThresholdCny,
                ),
                validator: (value) {
                  try {
                    parseAmount(value ?? '');
                    return null;
                  } catch (error) {
                    return safeError(error, context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? context.l10n.saving : context.l10n.saveRule),
      ),
    ],
  );
}
