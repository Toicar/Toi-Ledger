import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/ui_common.dart';
import '../../domain/operation.dart';

Future<void> resolveConflict(
  BuildContext context,
  WidgetRef ref,
  EntityView view,
) async {
  final choice = await showDialog<Operation>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('选择要保留的版本'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('全部原始版本仍保留在历史中。处理结果会作为新版本同步；并发处理可能再次产生冲突。'),
              for (final op in view.versions)
                Card(
                  child: ListTile(
                    isThreeLine: true,
                    title: Text(
                      op.entityType == EntityType.category
                          ? '${op.data['name']}${op.deleted ? '（归档）' : ''}'
                          : '${op.data['date']} · ¥${formatAmount(op.data['amountMinor'] as int)}${op.deleted ? '（删除）' : ''}',
                    ),
                    subtitle: Text(
                      '${op.data['note'] ?? op.data['kind']}\n${op.entityType == EntityType.entry ? '分类 ID：${op.data['categoryId']}\n' : ''}设备 ${op.deviceId.substring(0, 8)} · ${op.createdAt}',
                    ),
                    onTap: () => Navigator.pop(context, op),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('稍后处理'),
        ),
      ],
    ),
  );
  if (choice == null) return;
  try {
    await ref
        .read(repositoryProvider)
        .save(
          entityId: choice.entityId,
          type: choice.entityType,
          data: choice.data,
          deleted: choice.deleted,
          expectedHeads: view.versions.map((v) => v.id).toList(),
          resolve: true,
        );
  } catch (e) {
    if (context.mounted) notify(context, safeError(e));
  }
}
