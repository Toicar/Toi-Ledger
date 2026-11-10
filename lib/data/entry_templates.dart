import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/operation.dart';
import 'database.dart';

class EntryTemplate {
  EntryTemplate({
    required this.id,
    required this.name,
    required this.kind,
    this.categoryId,
    this.amountMinor,
    required this.note,
  }) {
    requireUuid(id);
    if (categoryId != null) requireUuid(categoryId);
    requireText(name, max: 40);
    requireText(note, max: 500, empty: true);
    if (!EntryKind.values.any((value) => value.name == kind)) {
      throw const LedgerException('收支类型无效');
    }
    if (amountMinor != null) parseAmount(formatAmount(amountMinor!));
  }

  final String id, name, kind, note;
  final String? categoryId;
  final int? amountMinor;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'categoryId': categoryId,
    'amountMinor': amountMinor,
    'note': note,
  };

  factory EntryTemplate.fromJson(Object? source) {
    try {
      if (source is! Map<String, dynamic> ||
          source.length != 6 ||
          source.keys.toSet().difference({
            'id',
            'name',
            'kind',
            'categoryId',
            'amountMinor',
            'note',
          }).isNotEmpty) {
        throw const FormatException();
      }
      return EntryTemplate(
        id: source['id'] as String,
        name: source['name'] as String,
        kind: source['kind'] as String,
        categoryId: source['categoryId'] as String?,
        amountMinor: source['amountMinor'] as int?,
        note: source['note'] as String,
      );
    } on LedgerException {
      rethrow;
    } catch (_) {
      throw const LedgerException('快捷模板字段无效');
    }
  }
}

String? templateCategoryIssue(EntryTemplate template, List<EntityView> views) {
  if (template.categoryId == null) return null;
  final matches = views.where(
    (view) =>
        view.current.entityId == template.categoryId &&
        view.current.entityType == EntityType.category,
  );
  if (matches.isEmpty) return '分类已缺失，请编辑模板重新选择';
  final category = matches.single;
  if (category.hasConflict) return '分类存在冲突，请处理冲突或编辑模板重新选择';
  if (category.current.deleted) return '分类已归档，请编辑模板重新选择';
  if (category.current.data['kind'] != template.kind) {
    return '分类收支类型已变化，请编辑模板重新选择';
  }
  return null;
}

class EntryTemplatePreferences {
  EntryTemplatePreferences(this.db);

  final LedgerDatabase db;
  static const key = 'entryTemplates';
  static const maxTemplates = 50;

  static List<EntryTemplate> _validated(List<EntryTemplate> templates) {
    if (templates.length > maxTemplates) {
      throw const LedgerException('快捷模板最多保存 50 个');
    }
    if (templates.map((template) => template.id).toSet().length !=
        templates.length) {
      throw const LedgerException('快捷模板 ID 重复');
    }
    return List.unmodifiable(templates);
  }

  Future<List<EntryTemplate>> read() async {
    final row = await (db.select(
      db.settings,
    )..where((setting) => setting.key.equals(key))).getSingleOrNull();
    if (row == null) return const [];
    try {
      final source = jsonDecode(row.value);
      if (source is! Map<String, dynamic> ||
          source.length != 2 ||
          source['version'] is! int ||
          (source['version'] != 1 && source['version'] != 2) ||
          source['templates'] is! List) {
        throw const FormatException();
      }
      if (source['version'] == 1 &&
          (source['templates'] as List).any(
            (value) =>
                value is Map &&
                (value['categoryId'] == null || value['amountMinor'] == null),
          )) {
        throw const FormatException();
      }
      return _validated(
        (source['templates'] as List).map(EntryTemplate.fromJson).toList(),
      );
    } on LedgerException {
      rethrow;
    } catch (_) {
      throw const LedgerException('快捷模板数据格式或版本无效');
    }
  }

  Future<void> write(List<EntryTemplate> templates) async {
    final values = _validated(templates);
    final encoded = jsonEncode({
      'version': 2,
      'templates': values.map((template) => template.toJson()).toList(),
    });
    await db.transaction(() async {
      await db
          .into(db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(key: key, value: encoded),
          );
    });
  }
}

final entryTemplatesProvider =
    StateNotifierProvider<
      EntryTemplatesController,
      AsyncValue<List<EntryTemplate>>
    >(
      (ref) => EntryTemplatesController(
        EntryTemplatePreferences(ref.watch(repositoryProvider).db),
      ),
    );

class EntryTemplatesController
    extends StateNotifier<AsyncValue<List<EntryTemplate>>> {
  EntryTemplatesController(this._preferences) : super(const AsyncLoading()) {
    _ready = _load();
    _pending = _ready.then<void>((_) {}, onError: (Object _, StackTrace _) {});
  }

  final EntryTemplatePreferences _preferences;
  late Future<List<EntryTemplate>> _ready;
  late Future<void> _pending;
  Future<List<EntryTemplate>> get ready => _ready;

  Future<List<EntryTemplate>> _load() async {
    try {
      final templates = await _preferences.read();
      if (mounted) state = AsyncData(templates);
      return templates;
    } catch (error, stack) {
      if (mounted) state = AsyncError(error, stack);
      rethrow;
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    // A failed change must not prevent subsequent queued changes from running.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> reload() => _enqueue(() async {
    _ready = _load();
    await _ready;
  });

  Future<void> save(EntryTemplate template) => _enqueue(() async {
    await _ready;
    final previous = state.requireValue;
    final index = previous.indexWhere((value) => value.id == template.id);
    final next = [...previous];
    if (index < 0) {
      next.add(template);
    } else {
      next[index] = template;
    }
    await _preferences.write(next);
    if (mounted) state = AsyncData(List.unmodifiable(next));
  });

  Future<void> remove(String id) => _enqueue(() async {
    requireUuid(id);
    await _ready;
    final next = state.requireValue
        .where((template) => template.id != id)
        .toList();
    await _preferences.write(next);
    if (mounted) state = AsyncData(List.unmodifiable(next));
  });
}
