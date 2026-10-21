import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/ui_common.dart';
import '../../domain/operation.dart';

class EntryEditor extends ConsumerStatefulWidget {
  const EntryEditor({super.key, required this.views, this.existing});
  final List<EntityView> views;
  final EntityView? existing;
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
    amount = TextEditingController(
      text: data == null ? '' : formatAmount(data['amountMinor'] as int),
    );
    note = TextEditingController(text: data?['note'] as String? ?? '');
    date = TextEditingController(
      text:
          data?['date'] as String? ??
          DateTime.now().toIso8601String().substring(0, 10),
    );
    kind = data?['kind'] as String? ?? 'expense';
    categoryId = data?['categoryId'] as String?;
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
    final categories = widget.views
        .where(
          (v) =>
              v.current.entityType == EntityType.category &&
              !v.hasConflict &&
              !v.current.deleted &&
              v.current.data['kind'] == kind,
        )
        .toList();
    final selected = categories.any((v) => v.current.entityId == categoryId)
        ? categoryId
        : null;
    return AlertDialog(
      title: Text(widget.existing == null ? '记一笔' : '编辑账目'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: const [
                    DropdownMenuItem(value: 'expense', child: Text('支出')),
                    DropdownMenuItem(value: 'income', child: Text('收入')),
                  ],
                  onChanged: widget.existing != null || saving
                      ? null
                      : (v) => setState(() {
                          kind = v!;
                          categoryId = null;
                        }),
                ),
                TextFormField(
                  controller: amount,
                  decoration: const InputDecoration(labelText: '金额（元）'),
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
                DropdownButtonFormField<String>(
                  key: ValueKey(kind),
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: '分类'),
                  items: categories
                      .map(
                        (v) => DropdownMenuItem(
                          value: v.current.entityId,
                          child: Text(v.current.data['name'] as String),
                        ),
                      )
                      .toList(),
                  validator: (v) => v == null ? '请先在分类管理中添加或选择分类' : null,
                  onChanged: saving
                      ? null
                      : (v) => setState(() => categoryId = v),
                ),
                TextFormField(
                  controller: date,
                  decoration: const InputDecoration(labelText: '日期 YYYY-MM-DD'),
                  validator: (v) {
                    try {
                      requireDate(v);
                      return null;
                    } catch (e) {
                      return safeError(e);
                    }
                  },
                ),
                TextFormField(
                  controller: note,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: '备注（可选）'),
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
          onPressed: saving ? null : save,
          child: Text(saving ? '保存中…' : '保存'),
        ),
      ],
    );
  }
}
