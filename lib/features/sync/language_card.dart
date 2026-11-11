import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/language_controller.dart';
import '../../app/design_components.dart';
import '../../l10n/app_strings.dart';

class LanguageCard extends ConsumerStatefulWidget {
  const LanguageCard({super.key});
  @override
  ConsumerState<LanguageCard> createState() => _LanguageCardState();
}

class _LanguageCardState extends ConsumerState<LanguageCard> {
  bool saving = false;
  bool failed = false;
  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(languageProvider);
    final strings = context.l10n;
    return PaperPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.language, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(strings.languageDescription),
          const SizedBox(height: 12),
          RadioGroup<LedgerLanguage>(
            groupValue: selected,
            onChanged: (value) async {
              if (saving || value == null) return;
              setState(() {
                saving = true;
                failed = false;
              });
              try {
                await ref.read(languageProvider.notifier).setLanguage(value);
              } catch (_) {
                if (mounted) setState(() => failed = true);
              } finally {
                if (mounted) setState(() => saving = false);
              }
            },
            child: Column(
              children: [
                for (final value in LedgerLanguage.values)
                  RadioListTile<LedgerLanguage>(
                    key: ValueKey('language-${value.name}'),
                    contentPadding: EdgeInsets.zero,
                    value: value,
                    enabled: !saving,
                    title: Text(switch (value) {
                      LedgerLanguage.system => strings.systemLanguage,
                      LedgerLanguage.zh => '简体中文',
                      LedgerLanguage.en => 'English',
                    }),
                  ),
              ],
            ),
          ),
          if (failed)
            Text(
              strings.languageSaveFailed,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
