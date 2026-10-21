import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/ui_common.dart';
import '../../domain/operation.dart';
import '../conflicts/conflict_dialog.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});
  Future<void> edit(
    BuildContext context,
    WidgetRef ref, [
    EntityView? view,
  ]) async {
    if (view?.hasConflict ?? false) {
      await resolveConflict(context, ref, view!);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => CategoryEditor(existing: view),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('分类管理')),
    body: ref
        .watch(entitiesProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(safeError(e))),
          data: (views) {
            final categories = views
                .where(
                  (v) =>
                      v.current.entityType == EntityType.category &&
                      (!v.current.deleted || v.hasConflict),
                )
                .toList();
            return categories.isEmpty
                ? const Center(child: Text('点击右下角添加收入或支出分类'))
                : ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (_, i) {
                      final v = categories[i];
                      return ListTile(
                        title: Text(
                          v.hasConflict
                              ? '分类冲突 · 点击处理'
                              : v.current.data['name'] as String,
                        ),
                        subtitle: Text(
                          v.current.data['kind'] == 'income' ? '收入' : '支出',
                        ),
                        onTap: () => edit(context, ref, v),
                        trailing: v.hasConflict
                            ? const Icon(Icons.warning_amber)
                            : IconButton(
                                tooltip: '归档分类',
                                icon: const Icon(Icons.archive_outlined),
                                onPressed: () async {
                                  if (await confirmDelete(context)) {
                                    try {
                                      await ref
                                          .read(repositoryProvider)
                                          .remove(v);
                                    } catch (e) {
                                      if (context.mounted) {
                                        notify(context, safeError(e));
                                      }
                                    }
                                  }
                                },
                              ),
                      );
                    },
                  );
          },
        ),
    floatingActionButton: FloatingActionButton(
      tooltip: '添加分类',
      onPressed: () => edit(context, ref),
      child: const Icon(Icons.add),
    ),
  );
}

class CategoryEditor extends ConsumerStatefulWidget {
  const CategoryEditor({super.key, this.existing});
  final EntityView? existing;
  @override
  ConsumerState<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<CategoryEditor> {
  late final TextEditingController name;
  late String kind;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: widget.existing?.current.data['name'] as String? ?? '',
    );
    kind = widget.existing?.current.data['kind'] as String? ?? 'expense';
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('分类'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            maxLength: 40,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          DropdownButton<String>(
            value: kind,
            items: const [
              DropdownMenuItem(value: 'expense', child: Text('支出')),
              DropdownMenuItem(value: 'income', child: Text('收入')),
            ],
            onChanged: widget.existing != null || saving
                ? null
                : (v) => setState(() => kind = v!),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                setState(() => saving = true);
                try {
                  await ref
                      .read(repositoryProvider)
                      .save(
                        entityId: widget.existing?.current.entityId,
                        type: EntityType.category,
                        data: {'name': name.text.trim(), 'kind': kind},
                        expectedHeads: widget.existing?.versions
                            .map((v) => v.id)
                            .toList(),
                      );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    setState(() => saving = false);
                    if (context.mounted) notify(context, safeError(e));
                  }
                }
              },
        child: const Text('保存'),
      ),
    ],
  );
}
