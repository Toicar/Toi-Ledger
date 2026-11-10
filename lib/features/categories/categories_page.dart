import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/ui_common.dart';
import '../../domain/operation.dart';
import '../../app/design_components.dart';
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
            final categories =
                views
                    .where(
                      (v) =>
                          v.current.entityType == EntityType.category &&
                          (!v.current.deleted || v.hasConflict),
                    )
                    .toList()
                  ..sort((a, b) {
                    final order = (a.current.data['kind'] as String).compareTo(
                      b.current.data['kind'] as String,
                    );
                    return order != 0
                        ? order
                        : (a.current.data['name'] as String).compareTo(
                            b.current.data['name'] as String,
                          );
                  });
            return categories.isEmpty
                ? const Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            LedgerStillLife(),
                            PageHeading(
                              eyebrow: 'MAKE ROOM FOR LIFE',
                              title: '生活，自有分类。',
                              description: '从餐饮、交通或工资开始。\n点击右下角添加收入或支出分类。',
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
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                        itemCount: categories.length + 1,
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return PageHeading(
                              eyebrow: 'A PLACE FOR EVERYTHING',
                              title: '生活，自有分类。',
                              description:
                                  '已设置 ${categories.length} 个分类。点击分类或编辑按钮修改名称，历史账目随之更新；归档仍保留历史记录。',
                            );
                          }
                          final v = categories[i - 1];
                          final income = v.current.data['kind'] == 'income';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color:
                                      (income
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.secondary
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.primary)
                                          .withValues(alpha: .09),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  categoryIcon(
                                    v.current.data['name'] as String,
                                    income: income,
                                  ),
                                  size: 20,
                                  color: income
                                      ? Theme.of(context).colorScheme.secondary
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                v.hasConflict
                                    ? '分类冲突 · 点击处理'
                                    : v.current.data['name'] as String,
                              ),
                              subtitle: Text(
                                v.current.data['kind'] == 'income'
                                    ? '收入'
                                    : '支出',
                              ),
                              onTap: () => edit(context, ref, v),
                              trailing: v.hasConflict
                                  ? const Icon(Icons.warning_amber)
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: '编辑分类',
                                          onPressed: () =>
                                              edit(context, ref, v),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          tooltip: '归档分类',
                                          icon: const Icon(
                                            Icons.archive_outlined,
                                          ),
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
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
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
  final form = GlobalKey<FormState>();
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
    title: Text(widget.existing == null ? '添加分类' : '编辑分类'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                enabled: !saving,
                maxLength: 40,
                decoration: const InputDecoration(labelText: '名称'),
                validator: (value) {
                  try {
                    requireText(value?.trim(), max: 40);
                    return null;
                  } catch (error) {
                    return safeError(error);
                  }
                },
              ),
              if (widget.existing != null)
                const Text(
                  '可修改分类的收入／支出类型。已有账单保留原收支类型，新类型用于后续记账。',
                  style: TextStyle(fontSize: 12),
                ),
              DropdownButton<String>(
                value: kind,
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('支出')),
                  DropdownMenuItem(value: 'income', child: Text('收入')),
                ],
                onChanged: saving
                    ? null
                    : (v) => setState(() => kind = v!),
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
        onPressed: saving
            ? null
            : () async {
                if (!form.currentState!.validate()) return;
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
