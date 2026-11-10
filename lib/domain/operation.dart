import 'dart:convert';
import 'package:crypto/crypto.dart';

const maxAmountMinor = 999999999999;
final uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

enum EntityType { entry, category }

enum EntryKind { income, expense }

class LedgerException implements Exception {
  const LedgerException(this.message);
  final String message;
  @override
  String toString() => message;
}

String requireUuid(Object? value) {
  if (value is! String || !uuidPattern.hasMatch(value)) {
    throw const LedgerException('无效的 UUID');
  }
  return value;
}

String requireText(Object? value, {int max = 200, bool empty = false}) {
  if (value is! String ||
      value.length > max ||
      (!empty && value.trim().isEmpty)) {
    throw const LedgerException('文字为空或超出长度限制');
  }
  return value;
}

String requireDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const LedgerException('日期格式应为 YYYY-MM-DD');
  }
  final date = DateTime.tryParse(value);
  if (date == null ||
      date.year < 1900 ||
      date.year > 2200 ||
      date.toIso8601String().substring(0, 10) != value) {
    throw const LedgerException('日期无效（支持 1900–2200 年）');
  }
  return value;
}

int parseAmount(String input) {
  final text = input.trim();
  if (!RegExp(r'^(0|[1-9]\d{0,9})(\.\d{1,2})?$').hasMatch(text)) {
    throw const LedgerException('金额须为正数，最多两位小数');
  }
  final parts = text.split('.');
  final minor =
      int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  if (minor <= 0 || minor > maxAmountMinor) {
    throw const LedgerException('金额超出允许范围');
  }
  return minor;
}

String formatAmount(int minor) =>
    '${minor < 0 ? '-' : ''}${minor.abs() ~/ 100}.${(minor.abs() % 100).toString().padLeft(2, '0')}';

String canonicalJson(Object? value) {
  Object? normalize(Object? v) {
    if (v is Map<String, dynamic>) {
      final keys = v.keys.toList()..sort();
      return {for (final k in keys) k: normalize(v[k])};
    }
    if (v is List) return v.map(normalize).toList();
    return v;
  }

  return jsonEncode(normalize(value));
}

class Operation {
  Operation({
    required this.id,
    required this.ledgerId,
    required this.deviceId,
    required this.entityId,
    required this.entityType,
    required List<String> parents,
    required Map<String, dynamic> data,
    required this.deleted,
    required this.createdAt,
    int? protocolVersion,
  }) : parents = List.unmodifiable(parents.toList()..sort()),
       protocolVersion =
           protocolVersion ??
           (entityType == EntityType.entry && data['categoryId'] == null
               ? 2
               : 1),
       data = Map.unmodifiable(data) {
    validate();
  }
  final String id, ledgerId, deviceId, entityId;
  final EntityType entityType;
  final List<String> parents;
  final Map<String, dynamic> data;
  final bool deleted;
  final String createdAt;
  final int protocolVersion;

  void validate() {
    if (protocolVersion != 1 && protocolVersion != 2 && protocolVersion != 3) {
      throw const LedgerException('不支持的操作协议版本，请更新应用');
    }
    if (protocolVersion == 3 && (entityType != EntityType.category || parents.isEmpty)) {
      throw const LedgerException('分类类型变更须引用已有分类版本');
    }
    for (final value in [id, ledgerId, deviceId, entityId, ...parents]) {
      requireUuid(value);
    }
    if (parents.length > 256 ||
        parents.toSet().length != parents.length ||
        parents.contains(id)) {
      throw const LedgerException('操作父版本无效或过多');
    }
    final time = DateTime.tryParse(createdAt);
    if (time == null ||
        !createdAt.endsWith('Z') ||
        time.toUtc().toIso8601String() != createdAt) {
      throw const LedgerException('操作时间须为标准 UTC 时间');
    }
    final allowed = entityType == EntityType.category
        ? {'name', 'kind'}
        : {'amountMinor', 'kind', 'categoryId', 'date', 'note'};
    if (data.keys.toSet().difference(allowed).isNotEmpty ||
        data.length != allowed.length) {
      throw const LedgerException('操作字段不符合协议');
    }
    if (!EntryKind.values.any((k) => k.name == data['kind'])) {
      throw const LedgerException('收支类型无效');
    }
    if (entityType == EntityType.category) {
      requireText(data['name'], max: 40);
    } else {
      final amount = data['amountMinor'];
      if (amount is! int || amount <= 0 || amount > maxAmountMinor) {
        throw const LedgerException('金额须为整数分且在范围内');
      }
      if (data['categoryId'] != null || protocolVersion == 1) {
        requireUuid(data['categoryId']);
      }
      requireDate(data['date']);
      requireText(data['note'], max: 500, empty: true);
    }
  }

  Map<String, dynamic> toJson() => {
    'version': protocolVersion,
    'id': id,
    'ledgerId': ledgerId,
    'deviceId': deviceId,
    'entityId': entityId,
    'entityType': entityType.name,
    'parents': parents,
    'data': data,
    'deleted': deleted,
    'createdAt': createdAt,
  };
  String get canonical => canonicalJson(toJson());
  String get digest => sha256.convert(utf8.encode(canonical)).toString();
  String encode() => canonicalJson({'operation': toJson(), 'sha256': digest});

  static Operation decode(String source) {
    try {
      final envelope = jsonDecode(source) as Map<String, dynamic>;
      if (envelope.length != 2) throw const FormatException();
      final map = envelope['operation'] as Map<String, dynamic>;
      if (map.length != 10 ||
          map['version'] is! int ||
          (map['version'] != 1 && map['version'] != 2 && map['version'] != 3)) {
        throw const FormatException();
      }
      final op = Operation(
        id: map['id'] as String,
        ledgerId: map['ledgerId'] as String,
        deviceId: map['deviceId'] as String,
        entityId: map['entityId'] as String,
        entityType: EntityType.values.byName(map['entityType'] as String),
        parents: (map['parents'] as List).cast<String>(),
        data: map['data'] as Map<String, dynamic>,
        deleted: map['deleted'] as bool,
        createdAt: map['createdAt'] as String,
        protocolVersion: map['version'] as int,
      );
      if (envelope['sha256'] != op.digest) {
        throw const LedgerException('日志校验失败');
      }
      return op;
    } on LedgerException {
      rethrow;
    } catch (_) {
      throw const LedgerException('日志格式或协议版本无效');
    }
  }
}

class EntityView {
  EntityView(List<Operation> versions)
    : versions = List.unmodifiable(
        versions.toList()..sort((a, b) => a.id.compareTo(b.id)),
      );
  final List<Operation> versions;
  Operation get current => versions.first;
  bool get hasConflict => versions.length > 1;
}

class MonthlyTotal {
  const MonthlyTotal(this.income, this.expense, this.conflicts);
  final int income, expense, conflicts;
  int get balance => income - expense;
}
