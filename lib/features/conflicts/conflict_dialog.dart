import '../../l10n/app_strings.dart';
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
      title: Text(context.l10n.chooseTheVersionToKeep),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.allOriginalVersionsRemainInHistory),
              for (final op in view.versions)
                Card(
                  child: ListTile(
                    isThreeLine: true,
                    title: Text(
                      op.entityType == EntityType.category
                          ? '${op.data['name']}${op.deleted ? context.l10n.archivedShort : ''}'
                          : '${op.data['date']} · ¥${formatAmount(op.data['amountMinor'] as int)}${op.deleted ? context.l10n.deletedShort : ''}',
                    ),
                    subtitle: Text(
                      context.l10n.device(
                        op.data['note'] ?? op.data['kind'],
                        op.entityType == EntityType.entry
                            ? context.l10n.categoryIdLine(op.data['categoryId'])
                            : '',
                        op.deviceId.substring(0, 8),
                        op.createdAt,
                      ),
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
          child: Text(context.l10n.later),
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
    if (context.mounted) notify(context, safeError(e, context));
  }
}
