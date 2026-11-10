import 'package:flutter/material.dart';
import '../../domain/operation.dart';

String statisticsMoney(int minor) {
  final parts = formatAmount(minor).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return '¥$whole.${parts[1]}';
}

class StatisticsSegments<T> extends StatelessWidget {
  const StatisticsSegments({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.itemKey,
  });
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final Key Function(T)? itemKey;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in values)
              Semantics(
                selected: value == selected,
                button: true,
                child: Material(
                  color: value == selected
                      ? scheme.surface
                      : Colors.transparent,
                  elevation: value == selected ? 1 : 0,
                  shadowColor: Colors.black.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    key: itemKey?.call(value),
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => onChanged(value),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Text(
                          label(value),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: value == selected
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
