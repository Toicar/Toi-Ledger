import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/ui_common.dart';
import '../../data/entry_templates.dart';
import '../../domain/operation.dart';
import '../../app/design_components.dart';
import '../../app/ledger_typography.dart';
import '../categories/categories_page.dart';

class EntryEditor extends ConsumerStatefulWidget {
  const EntryEditor({
    super.key,
    required this.views,
    this.existing,
    this.template,
  }) : assert(existing == null || template == null);
  final List<EntityView> views;
  final EntityView? existing;
  final EntryTemplate? template;
  @override
  ConsumerState<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends ConsumerState<EntryEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController amount, note, date;
  late String kind;
  String? categoryId;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final data = widget.existing?.current.data;
    final template = widget.template;
    amount = TextEditingController(
      text: data != null
          ? formatAmount(data['amountMinor'] as int)
          : template?.amountMinor == null
          ? ''
          : formatAmount(template!.amountMinor!),
    );
    note = TextEditingController(
      text: data?['note'] as String? ?? template?.note ?? '',
    );
    date = TextEditingController(
      text:
          data?['date'] as String? ??
          DateTime.now().toIso8601String().substring(0, 10),
    );
    kind = data?['kind'] as String? ?? template?.kind ?? 'expense';
    categoryId = data?['categoryId'] as String? ?? template?.categoryId;
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    date.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await ref
          .read(repositoryProvider)
          .save(
            entityId: widget.existing?.current.entityId,
            type: EntityType.entry,
            expectedHeads: widget.existing?.versions.map((o) => o.id).toList(),
            data: {
              'amountMinor': parseAmount(amount.text),
              'kind': kind,
              'categoryId': categoryId,
              'date': requireDate(date.text.trim()),
              'note': note.text.trim(),
            },
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        notify(context, safeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final views = ref.watch(entitiesProvider).asData?.value ?? widget.views;
    final categories = views
        .where(
          (v) =>
              v.current.entityType == EntityType.category &&
              !v.hasConflict &&
              !v.current.deleted &&
              (v.current.data['kind'] == kind ||
                  (widget.existing != null &&
                      widget.existing!.current.data['categoryId'] == v.current.entityId)),
        )
        .toList();
    final selected = categories.any((v) => v.current.entityId == categoryId)
        ? categoryId
        : null;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (!saving) save();
        },
      },
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            const LedgerMark(size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.existing == null ? '记一笔' : '编辑账目',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.template == null
                        ? '认真记下，平常生活里的这一笔。'
                        : '已填入模板，确认后才会记入账本。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 22),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'expense',
                        label: Text('支出'),
                        icon: Icon(Icons.north_east_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: 'income',
                        label: Text('收入'),
                        icon: Icon(Icons.south_west_rounded, size: 16),
                      ),
                    ],
                    selected: {kind},
                    showSelectedIcon: false,
                    onSelectionChanged: widget.existing != null || saving
                        ? null
                        : (values) => setState(() {
                            kind = values.single;
                            categoryId = null;
                          }),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: amount,
                    enabled: !saving,
                    autofocus: widget.existing == null,
                    style: LedgerTypography.of(context).number(size: 32),
                    decoration: InputDecoration(
                      labelText: '金额（元）',
                      prefixText: '¥ ',
                      prefixStyle: LedgerTypography.of(
                        context,
                      ).number(size: 28),
                      hintText: '0.00',
                      hintStyle: LedgerTypography.of(context).number(
                        size: 32,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: .5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 22,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      try {
                        parseAmount(v ?? '');
                        return null;
                      } catch (e) {
                        return safeError(e);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    key: ValueKey('$kind:$categoryId'),
                    initialValue: categoryId ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '分类（可选）'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('未分类')),
                      if (categoryId != null && selected == null)
                        DropdownMenuItem(
                          value: categoryId,
                          enabled: false,
                          child: const Text('原分类不可用，请重新选择或留空'),
                        ),
                      ...categories.map(
                        (v) => DropdownMenuItem(
                          value: v.current.entityId,
                          child: Tooltip(
                            message: v.current.data['name'] as String,
                            child: Text(
                              v.current.data['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                    validator: (v) =>
                        v == null ||
                            v.isEmpty ||
                            categories.any((c) => c.current.entityId == v)
                        ? null
                        : '请选择有效分类或未分类',
                    onChanged: saving
                        ? null
                        : (v) =>
                              setState(() => categoryId = v == '' ? null : v),
                  ),
                  if (categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TextButton.icon(
                        onPressed: saving
                            ? null
                            : () => showDialog<void>(
                                context: context,
                                builder: (_) => const CategoryEditor(),
                              ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('添加分类（可选）'),
                      ),
                    ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: date,
                    enabled: !saving,
                    decoration: InputDecoration(
                      labelText: '日期 YYYY-MM-DD',
                      suffixIcon: IconButton(
                        tooltip: '选择日期',
                        onPressed: saving
                            ? null
                            : () async {
                                final parsed = DateTime.tryParse(date.text);
                                final initial =
                                    parsed != null &&
                                        parsed.year >= 1900 &&
                                        parsed.year <= 2200
                                    ? parsed
                                    : DateTime.now();
                                final selected = await showDatePicker(
                                  context: context,
                                  initialDate: initial,
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime(2200, 12, 31),
                                );
                                if (selected != null && mounted) {
                                  date.text = selected
                                      .toIso8601String()
                                      .substring(0, 10);
                                }
                              },
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                      ),
                    ),
                    validator: (v) {
                      try {
                        requireDate(v);
                        return null;
                      } catch (e) {
                        return safeError(e);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: note,
                    enabled: !saving,
                    maxLength: 500,
                    decoration: const InputDecoration(labelText: '备注（可选）'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? '保存中…' : '保存'),
          ),
        ],
      ),
    );
  }
}
