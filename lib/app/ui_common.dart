import '../l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../domain/operation.dart';

String ledgerMoney(int minor) {
  final parts = formatAmount(minor).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return '¥$whole.${parts[1]}';
}

String safeError(Object error, [BuildContext? context]) {
  final strings = context == null
      ? const AppStrings(Locale('zh', 'CN'))
      : context.l10n;
  return strings.message(
    error is LedgerException ? error.message : '操作失败，数据未提交；请重试',
  );
}

void notify(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(context.l10n.message(message))));

Future<bool> confirmDelete(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteThisItem),
        content: Text(context.l10n.deletionSyncsToOtherDevicesHistorical),
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
    ) ??
    false;
