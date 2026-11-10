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
        title: const Text('删除快捷模板？'),
        content: Text('删除“${template.name}”后，已记录的账目仍会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(entryTemplatesProvider.notifier).remove(template.id);
    } catch (error) {
      if (context.mounted) notify(context, safeError(error));
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
      appBar: AppBar(title: const Text('快捷模板')),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('无法读取快捷模板'),
                const SizedBox(height: 8),
                Text(safeError(error)),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await ref.read(entryTemplatesProvider.notifier).reload();
                    } catch (_) {
                      // The provider displays the read error and offers retry.
                    }
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
        data: (values) => entities.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(safeError(error))),
          data: (views) => values.isEmpty
              ? const Center(
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
                            title: '日常，轻松记。',
                            description: '还没有快捷模板',
                          ),
                          SizedBox(height: 8),
                          Text(
                            '将常用收支保存为模板，下次记账时快速填入。',
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
                            title: '日常，轻松记。',
                            description: '${values.length} 个常用收支模板。轻点填入，确认后记账。',
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
                            ? '未预设分类'
                            : categories.isEmpty
                            ? '分类缺失'
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
                                  '${template.kind == 'income' ? '收入' : '支出'} · $categoryName',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hideAmounts
                                      ? '金额已隐藏'
                                      : template.amountMinor == null
                                      ? '记账时填写金额'
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
                                    issue,
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
                                      child: const Text('使用模板'),
                                    ),
                                    IconButton(
                                      tooltip: '编辑模板',
                                      onPressed: () =>
                                          _edit(context, views, template),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: '删除模板',
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
            ? '快捷模板已达 50 个上限'
            : '添加模板',
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
        notify(context, safeError(error));
      }
    }
  }

  String? _textError(String? value, {required int max, bool empty = false}) {
    try {
      requireText(value?.trim(), max: max, empty: empty);
      return null;
    } catch (error) {
      return safeError(error);
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
      title: Text(widget.existing == null ? '添加快捷模板' : '编辑快捷模板'),
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
                  decoration: const InputDecoration(labelText: '模板名称'),
                  validator: (value) => _textError(value, max: 40),
                ),
                const SizedBox(height: 14),
                if (issue != null) ...[
                  Text(
                    issue,
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
                  decoration: const InputDecoration(
                    labelText: '分类（可选）',
                    helperText: '选择分类后自动匹配收入或支出',
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('不预设分类')),
                    if (categoryId != null && selected == null)
                      DropdownMenuItem(
                        value: categoryId,
                        enabled: false,
                        child: const Text('原分类不可用，请重新选择或留空'),
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
                      : '请选择有效分类或不预设分类',
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
                  decoration: const InputDecoration(labelText: '类型'),
                  items: const [
                    DropdownMenuItem(value: 'expense', child: Text('支出')),
                    DropdownMenuItem(value: 'income', child: Text('收入')),
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
                  decoration: const InputDecoration(
                    labelText: '金额（元）',
                    helperText: '可留空，使用模板时再填写',
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
                      return safeError(error);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: note,
                  enabled: !saving,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: '备注（可选）'),
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
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: saving ? null : () => save(views),
          child: Text(saving ? '保存中…' : '保存模板'),
        ),
      ],
    );
  }
}
