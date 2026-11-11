import '../../l10n/app_strings.dart';
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
        notify(context, safeError(e, context));
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
                      widget.existing!.current.data['categoryId'] ==
                          v.current.entityId)),
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
                widget.existing == null
                    ? context.l10n.newEntry
                    : context.l10n.editEntry,
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
                        ? context.l10n.aSmallNoteOfEverydayLife
                        : context.l10n.templateAppliedConfirmToAddThis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 22),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'expense',
                        label: Text(context.l10n.expense),
                        icon: Icon(Icons.north_east_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: 'income',
                        label: Text(context.l10n.income),
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
                      labelText: context.l10n.amountCny,
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
                        return safeError(e, context);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    key: ValueKey('$kind:$categoryId'),
                    initialValue: categoryId ?? '',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.categoryOptional,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(context.l10n.uncategorized2),
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
                        : context.l10n.chooseAnAvailableCategoryOrUncategorized,
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
                        label: Text(context.l10n.addCategoryOptional),
                      ),
                    ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: date,
                    enabled: !saving,
                    decoration: InputDecoration(
                      labelText: context.l10n.dateYyyyMmDd,
                      suffixIcon: IconButton(
                        tooltip: context.l10n.chooseDate,
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
                        return safeError(e, context);
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
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? context.l10n.saving : context.l10n.save),
          ),
        ],
      ),
    );
  }
}
