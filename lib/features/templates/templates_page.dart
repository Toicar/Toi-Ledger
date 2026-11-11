import '../../l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app/presentation_controller.dart';
import '../../app/providers.dart';
import '../../app/ui_common.dart';
import '../../data/entry_templates.dart';
import '../../domain/operation.dart';
import '../../app/design_components.dart';
import '../../app/ledger_typography.dart';
import '../ledger/entry_editor.dart';

class TemplatesPage extends ConsumerWidget {
  const TemplatesPage({super.key});

  Future<void> _edit(
    BuildContext context,
    List<EntityView> views, [
    EntryTemplate? template,
  ]) => showDialog<void>(
    context: context,
    builder: (_) => _TemplateEditor(views: views, existing: template),
  );

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    EntryTemplate template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteThisQuickTemplate),
        content: Text(
          context.l10n.deletingKeepsEntriesAlreadyRecorded(template.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(entryTemplatesProvider.notifier).remove(template.id);
    } catch (error) {
      if (context.mounted) notify(context, safeError(error, context));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(entryTemplatesProvider);
    final entities = ref.watch(entitiesProvider);
    final hideAmounts = ref.watch(presentationProvider).hideAmounts;
    final canAdd =
        templates.asData != null &&
        templates.requireValue.length < EntryTemplatePreferences.maxTemplates &&
        entities.asData != null;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.quickTemplates)),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.couldNotLoadQuickTemplates),
                const SizedBox(height: 8),
                Text(safeError(error, context)),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await ref.read(entryTemplatesProvider.notifier).reload();
                    } catch (_) {
                      // The provider displays the read error and offers retry.
                    }
                  },
                  child: Text(context.l10n.retry),
                ),
              ],
            ),
          ),
        ),
        data: (values) => entities.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(safeError(error, context))),
          data: (views) => values.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LedgerStillLife(),
                          SizedBox(height: 16),
                          PageHeading(
                            eyebrow: 'LESS TYPING, MORE LIVING',
                            title: context.l10n.aSimplerEveryday,
                            description: context.l10n.noQuickTemplatesYet,
                          ),
                          SizedBox(height: 8),
                          Text(
                            context.l10n.saveFrequentIncomeOrExpensesAs,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: values.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return PageHeading(
                            eyebrow: 'LESS TYPING, MORE LIVING',
                            title: context.l10n.aSimplerEveryday,
                            description: context.l10n
                                .quickTemplatesApplyOneReviewIt(values.length),
                          );
                        }
                        final template = values[index - 1];
                        final issue = templateCategoryIssue(template, views);
                        final categories = views.where(
                          (view) =>
                              view.current.entityId == template.categoryId &&
                              view.current.entityType == EntityType.category,
                        );
                        final categoryName = template.categoryId == null
                            ? context.l10n.noPresetCategory
                            : categories.isEmpty
                            ? context.l10n.missingCategory
                            : categories.single.current.data['name'] as String;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  template.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${template.kind == 'income' ? context.l10n.income : context.l10n.expense} · $categoryName',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hideAmounts
                                      ? context.l10n.amountsHidden
                                      : template.amountMinor == null
                                      ? context.l10n.enterAnAmountWhenRecording
                                      : '¥${formatAmount(template.amountMinor!)}',
                                  style: LedgerTypography.of(
                                    context,
                                  ).number(size: 25),
                                ),
                                if (template.note.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    template.note,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (issue != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    context.l10n.message(issue),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    FilledButton(
                                      onPressed: issue == null
                                          ? () => showDialog<void>(
                                              context: context,
                                              builder: (_) => EntryEditor(
                                                views: views,
                                                template: template,
                                              ),
                                            )
                                          : null,
                                      child: Text(context.l10n.useTemplate),
                                    ),
                                    IconButton(
                                      tooltip: context.l10n.editTemplate,
                                      onPressed: () =>
                                          _edit(context, views, template),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: context.l10n.deleteTemplate,
                                      onPressed: () =>
                                          _remove(context, ref, template),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip:
            templates.asData != null &&
                templates.requireValue.length >=
                    EntryTemplatePreferences.maxTemplates
            ? context.l10n.limitOfQuickTemplatesReached
            : context.l10n.addTemplate,
        onPressed: canAdd ? () => _edit(context, entities.requireValue) : null,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TemplateEditor extends ConsumerStatefulWidget {
  const _TemplateEditor({required this.views, this.existing});
  final List<EntityView> views;
  final EntryTemplate? existing;

  @override
  ConsumerState<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends ConsumerState<_TemplateEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, amount, note;
  late String kind;
  String? categoryId;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final template = widget.existing;
    name = TextEditingController(text: template?.name ?? '');
    amount = TextEditingController(
      text: template?.amountMinor == null
          ? ''
          : formatAmount(template!.amountMinor!),
    );
    note = TextEditingController(text: template?.note ?? '');
    kind = template?.kind ?? 'expense';
    categoryId = template?.categoryId;
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save(List<EntityView> views) async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final template = EntryTemplate(
        id: widget.existing?.id ?? const Uuid().v4(),
        name: name.text.trim(),
        kind: kind,
        categoryId: categoryId,
        amountMinor: amount.text.trim().isEmpty
            ? null
            : parseAmount(amount.text),
        note: note.text.trim(),
      );
      final issue = templateCategoryIssue(template, views);
      if (issue != null) throw LedgerException(issue);
      await ref.read(entryTemplatesProvider.notifier).save(template);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        notify(context, safeError(error, context));
      }
    }
  }

  String? _textError(String? value, {required int max, bool empty = false}) {
    try {
      requireText(value?.trim(), max: max, empty: empty);
      return null;
    } catch (error) {
      return safeError(error, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final views = ref.watch(entitiesProvider).asData?.value ?? widget.views;
    final categories = views
        .where(
          (view) =>
              view.current.entityType == EntityType.category &&
              !view.hasConflict &&
              !view.current.deleted,
        )
        .toList();
    final selected =
        categories.any((view) => view.current.entityId == categoryId)
        ? categoryId
        : null;
    final issue = widget.existing == null || selected != null
        ? null
        : categoryId == null
        ? null
        : templateCategoryIssue(widget.existing!, views);
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? context.l10n.addQuickTemplate
            : context.l10n.editQuickTemplate,
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: name,
                  enabled: !saving,
                  maxLength: 40,
                  decoration: InputDecoration(
                    labelText: context.l10n.templateName,
                  ),
                  validator: (value) => _textError(value, max: 40),
                ),
                const SizedBox(height: 14),
                if (issue != null) ...[
                  Text(
                    context.l10n.message(issue),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                DropdownButtonFormField<String>(
                  key: ValueKey('$kind:$categoryId'),
                  initialValue: categoryId ?? '',
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.categoryOptional,
                    helperText: context.l10n.selectingACategorySetsIncomeOr,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(context.l10n.noPresetCategory2),
                    ),
                    if (categoryId != null && selected == null)
                      DropdownMenuItem(
                        value: categoryId,
                        enabled: false,
                        child: Text(
                          context
                              .l10n
                              .originalCategoryUnavailableChooseAnotherOr,
                        ),
                      ),
                    ...categories.map(
                      (view) => DropdownMenuItem(
                        value: view.current.entityId,
                        child: Tooltip(
                          message: view.current.data['name'] as String,
                          child: Text(
                            view.current.data['name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                  validator: (value) =>
                      value == null ||
                          value.isEmpty ||
                          categories.any((c) => c.current.entityId == value)
                      ? null
                      : context.l10n.chooseAnAvailableCategoryOrLeave,
                  onChanged: saving
                      ? null
                      : (value) => setState(() {
                          categoryId = value == '' ? null : value;
                          if (categoryId != null) {
                            kind =
                                categories
                                        .singleWhere(
                                          (c) =>
                                              c.current.entityId == categoryId,
                                        )
                                        .current
                                        .data['kind']
                                    as String;
                          }
                        }),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey('template-kind:$kind'),
                  initialValue: kind,
                  decoration: InputDecoration(labelText: context.l10n.type),
                  items: [
                    DropdownMenuItem(
                      value: 'expense',
                      child: Text(context.l10n.expense),
                    ),
                    DropdownMenuItem(
                      value: 'income',
                      child: Text(context.l10n.income),
                    ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(() {
                          kind = value!;
                          if (!categories.any(
                            (c) =>
                                c.current.entityId == categoryId &&
                                c.current.data['kind'] == kind,
                          )) {
                            categoryId = null;
                          }
                        }),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: amount,
                  enabled: !saving,
                  decoration: InputDecoration(
                    labelText: context.l10n.amountCny,
                    helperText: context.l10n.leaveBlankToEnterAnAmount,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    try {
                      parseAmount(value);
                      return null;
                    } catch (error) {
                      return safeError(error, context);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: note,
                  enabled: !saving,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: context.l10n.noteOptional,
                  ),
                  validator: (value) =>
                      _textError(value, max: 500, empty: true),
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
          onPressed: saving ? null : () => save(views),
          child: Text(saving ? context.l10n.saving : context.l10n.saveTemplate),
        ),
      ],
    );
  }
}
