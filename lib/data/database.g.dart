// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $OperationRowsTable extends OperationRows
    with TableInfo<$OperationRowsTable, OperationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OperationRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pendingMeta = const VerificationMeta(
    'pending',
  );
  @override
  late final GeneratedColumn<bool> pending = GeneratedColumn<bool>(
    'pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityId,
    entityType,
    body,
    pending,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operation_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<OperationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('pending')) {
      context.handle(
        _pendingMeta,
        pending.isAcceptableOrUnknown(data['pending']!, _pendingMeta),
      );
    } else if (isInserting) {
      context.missing(_pendingMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OperationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      pending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending'],
      )!,
    );
  }

  @override
  $OperationRowsTable createAlias(String alias) {
    return $OperationRowsTable(attachedDatabase, alias);
  }
}

class OperationRow extends DataClass implements Insertable<OperationRow> {
  final String id;
  final String entityId;
  final String entityType;
  final String body;
  final bool pending;
  const OperationRow({
    required this.id,
    required this.entityId,
    required this.entityType,
    required this.body,
    required this.pending,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_id'] = Variable<String>(entityId);
    map['entity_type'] = Variable<String>(entityType);
    map['body'] = Variable<String>(body);
    map['pending'] = Variable<bool>(pending);
    return map;
  }

  OperationRowsCompanion toCompanion(bool nullToAbsent) {
    return OperationRowsCompanion(
      id: Value(id),
      entityId: Value(entityId),
      entityType: Value(entityType),
      body: Value(body),
      pending: Value(pending),
    );
  }

  factory OperationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperationRow(
      id: serializer.fromJson<String>(json['id']),
      entityId: serializer.fromJson<String>(json['entityId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      body: serializer.fromJson<String>(json['body']),
      pending: serializer.fromJson<bool>(json['pending']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityId': serializer.toJson<String>(entityId),
      'entityType': serializer.toJson<String>(entityType),
      'body': serializer.toJson<String>(body),
      'pending': serializer.toJson<bool>(pending),
    };
  }

  OperationRow copyWith({
    String? id,
    String? entityId,
    String? entityType,
    String? body,
    bool? pending,
  }) => OperationRow(
    id: id ?? this.id,
    entityId: entityId ?? this.entityId,
    entityType: entityType ?? this.entityType,
    body: body ?? this.body,
    pending: pending ?? this.pending,
  );
  OperationRow copyWithCompanion(OperationRowsCompanion data) {
    return OperationRow(
      id: data.id.present ? data.id.value : this.id,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      body: data.body.present ? data.body.value : this.body,
      pending: data.pending.present ? data.pending.value : this.pending,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperationRow(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('entityType: $entityType, ')
          ..write('body: $body, ')
          ..write('pending: $pending')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entityId, entityType, body, pending);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperationRow &&
          other.id == this.id &&
          other.entityId == this.entityId &&
          other.entityType == this.entityType &&
          other.body == this.body &&
          other.pending == this.pending);
}

class OperationRowsCompanion extends UpdateCompanion<OperationRow> {
  final Value<String> id;
  final Value<String> entityId;
  final Value<String> entityType;
  final Value<String> body;
  final Value<bool> pending;
  final Value<int> rowid;
  const OperationRowsCompanion({
    this.id = const Value.absent(),
    this.entityId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.body = const Value.absent(),
    this.pending = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OperationRowsCompanion.insert({
    required String id,
    required String entityId,
    required String entityType,
    required String body,
    required bool pending,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entityId = Value(entityId),
       entityType = Value(entityType),
       body = Value(body),
       pending = Value(pending);
  static Insertable<OperationRow> custom({
    Expression<String>? id,
    Expression<String>? entityId,
    Expression<String>? entityType,
    Expression<String>? body,
    Expression<bool>? pending,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityId != null) 'entity_id': entityId,
      if (entityType != null) 'entity_type': entityType,
      if (body != null) 'body': body,
      if (pending != null) 'pending': pending,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OperationRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? entityId,
    Value<String>? entityType,
    Value<String>? body,
    Value<bool>? pending,
    Value<int>? rowid,
  }) {
    return OperationRowsCompanion(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      body: body ?? this.body,
      pending: pending ?? this.pending,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (pending.present) {
      map['pending'] = Variable<bool>(pending.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationRowsCompanion(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('entityType: $entityType, ')
          ..write('body: $body, ')
          ..write('pending: $pending, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HeadRowsTable extends HeadRows with TableInfo<$HeadRowsTable, HeadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HeadRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
    'op_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES operation_rows (id)',
    ),
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [opId, entityId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'head_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<HeadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('op_id')) {
      context.handle(
        _opIdMeta,
        opId.isAcceptableOrUnknown(data['op_id']!, _opIdMeta),
      );
    } else if (isInserting) {
      context.missing(_opIdMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {opId};
  @override
  HeadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HeadRow(
      opId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_id'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
    );
  }

  @override
  $HeadRowsTable createAlias(String alias) {
    return $HeadRowsTable(attachedDatabase, alias);
  }
}

class HeadRow extends DataClass implements Insertable<HeadRow> {
  final String opId;
  final String entityId;
  const HeadRow({required this.opId, required this.entityId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['op_id'] = Variable<String>(opId);
    map['entity_id'] = Variable<String>(entityId);
    return map;
  }

  HeadRowsCompanion toCompanion(bool nullToAbsent) {
    return HeadRowsCompanion(opId: Value(opId), entityId: Value(entityId));
  }

  factory HeadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HeadRow(
      opId: serializer.fromJson<String>(json['opId']),
      entityId: serializer.fromJson<String>(json['entityId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'opId': serializer.toJson<String>(opId),
      'entityId': serializer.toJson<String>(entityId),
    };
  }

  HeadRow copyWith({String? opId, String? entityId}) =>
      HeadRow(opId: opId ?? this.opId, entityId: entityId ?? this.entityId);
  HeadRow copyWithCompanion(HeadRowsCompanion data) {
    return HeadRow(
      opId: data.opId.present ? data.opId.value : this.opId,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HeadRow(')
          ..write('opId: $opId, ')
          ..write('entityId: $entityId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(opId, entityId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HeadRow &&
          other.opId == this.opId &&
          other.entityId == this.entityId);
}

class HeadRowsCompanion extends UpdateCompanion<HeadRow> {
  final Value<String> opId;
  final Value<String> entityId;
  final Value<int> rowid;
  const HeadRowsCompanion({
    this.opId = const Value.absent(),
    this.entityId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HeadRowsCompanion.insert({
    required String opId,
    required String entityId,
    this.rowid = const Value.absent(),
  }) : opId = Value(opId),
       entityId = Value(entityId);
  static Insertable<HeadRow> custom({
    Expression<String>? opId,
    Expression<String>? entityId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (opId != null) 'op_id': opId,
      if (entityId != null) 'entity_id': entityId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HeadRowsCompanion copyWith({
    Value<String>? opId,
    Value<String>? entityId,
    Value<int>? rowid,
  }) {
    return HeadRowsCompanion(
      opId: opId ?? this.opId,
      entityId: entityId ?? this.entityId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HeadRowsCompanion(')
          ..write('opId: $opId, ')
          ..write('entityId: $entityId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LedgerDatabase extends GeneratedDatabase {
  _$LedgerDatabase(QueryExecutor e) : super(e);
  $LedgerDatabaseManager get managers => $LedgerDatabaseManager(this);
  late final $OperationRowsTable operationRows = $OperationRowsTable(this);
  late final $HeadRowsTable headRows = $HeadRowsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    operationRows,
    headRows,
    settings,
  ];
}

typedef $$OperationRowsTableCreateCompanionBuilder =
    OperationRowsCompanion Function({
      required String id,
      required String entityId,
      required String entityType,
      required String body,
      required bool pending,
      Value<int> rowid,
    });
typedef $$OperationRowsTableUpdateCompanionBuilder =
    OperationRowsCompanion Function({
      Value<String> id,
      Value<String> entityId,
      Value<String> entityType,
      Value<String> body,
      Value<bool> pending,
      Value<int> rowid,
    });

final class $$OperationRowsTableReferences
    extends
        BaseReferences<_$LedgerDatabase, $OperationRowsTable, OperationRow> {
  $$OperationRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$HeadRowsTable, List<HeadRow>> _headRowsRefsTable(
    _$LedgerDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.headRows,
    aliasName: $_aliasNameGenerator(db.operationRows.id, db.headRows.opId),
  );

  $$HeadRowsTableProcessedTableManager get headRowsRefs {
    final manager = $$HeadRowsTableTableManager(
      $_db,
      $_db.headRows,
    ).filter((f) => f.opId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_headRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$OperationRowsTableFilterComposer
    extends Composer<_$LedgerDatabase, $OperationRowsTable> {
  $$OperationRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pending => $composableBuilder(
    column: $table.pending,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> headRowsRefs(
    Expression<bool> Function($$HeadRowsTableFilterComposer f) f,
  ) {
    final $$HeadRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.headRows,
      getReferencedColumn: (t) => t.opId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeadRowsTableFilterComposer(
            $db: $db,
            $table: $db.headRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$OperationRowsTableOrderingComposer
    extends Composer<_$LedgerDatabase, $OperationRowsTable> {
  $$OperationRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pending => $composableBuilder(
    column: $table.pending,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OperationRowsTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $OperationRowsTable> {
  $$OperationRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<bool> get pending =>
      $composableBuilder(column: $table.pending, builder: (column) => column);

  Expression<T> headRowsRefs<T extends Object>(
    Expression<T> Function($$HeadRowsTableAnnotationComposer a) f,
  ) {
    final $$HeadRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.headRows,
      getReferencedColumn: (t) => t.opId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeadRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.headRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$OperationRowsTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $OperationRowsTable,
          OperationRow,
          $$OperationRowsTableFilterComposer,
          $$OperationRowsTableOrderingComposer,
          $$OperationRowsTableAnnotationComposer,
          $$OperationRowsTableCreateCompanionBuilder,
          $$OperationRowsTableUpdateCompanionBuilder,
          (OperationRow, $$OperationRowsTableReferences),
          OperationRow,
          PrefetchHooks Function({bool headRowsRefs})
        > {
  $$OperationRowsTableTableManager(
    _$LedgerDatabase db,
    $OperationRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OperationRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OperationRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OperationRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<bool> pending = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationRowsCompanion(
                id: id,
                entityId: entityId,
                entityType: entityType,
                body: body,
                pending: pending,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entityId,
                required String entityType,
                required String body,
                required bool pending,
                Value<int> rowid = const Value.absent(),
              }) => OperationRowsCompanion.insert(
                id: id,
                entityId: entityId,
                entityType: entityType,
                body: body,
                pending: pending,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$OperationRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({headRowsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (headRowsRefs) db.headRows],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (headRowsRefs)
                    await $_getPrefetchedData<
                      OperationRow,
                      $OperationRowsTable,
                      HeadRow
                    >(
                      currentTable: table,
                      referencedTable: $$OperationRowsTableReferences
                          ._headRowsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$OperationRowsTableReferences(
                            db,
                            table,
                            p0,
                          ).headRowsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.opId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$OperationRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $OperationRowsTable,
      OperationRow,
      $$OperationRowsTableFilterComposer,
      $$OperationRowsTableOrderingComposer,
      $$OperationRowsTableAnnotationComposer,
      $$OperationRowsTableCreateCompanionBuilder,
      $$OperationRowsTableUpdateCompanionBuilder,
      (OperationRow, $$OperationRowsTableReferences),
      OperationRow,
      PrefetchHooks Function({bool headRowsRefs})
    >;
typedef $$HeadRowsTableCreateCompanionBuilder =
    HeadRowsCompanion Function({
      required String opId,
      required String entityId,
      Value<int> rowid,
    });
typedef $$HeadRowsTableUpdateCompanionBuilder =
    HeadRowsCompanion Function({
      Value<String> opId,
      Value<String> entityId,
      Value<int> rowid,
    });

final class $$HeadRowsTableReferences
    extends BaseReferences<_$LedgerDatabase, $HeadRowsTable, HeadRow> {
  $$HeadRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $OperationRowsTable _opIdTable(_$LedgerDatabase db) => db.operationRows
      .createAlias($_aliasNameGenerator(db.headRows.opId, db.operationRows.id));

  $$OperationRowsTableProcessedTableManager get opId {
    final $_column = $_itemColumn<String>('op_id')!;

    final manager = $$OperationRowsTableTableManager(
      $_db,
      $_db.operationRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_opIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HeadRowsTableFilterComposer
    extends Composer<_$LedgerDatabase, $HeadRowsTable> {
  $$HeadRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  $$OperationRowsTableFilterComposer get opId {
    final $$OperationRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.opId,
      referencedTable: $db.operationRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationRowsTableFilterComposer(
            $db: $db,
            $table: $db.operationRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HeadRowsTableOrderingComposer
    extends Composer<_$LedgerDatabase, $HeadRowsTable> {
  $$HeadRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  $$OperationRowsTableOrderingComposer get opId {
    final $$OperationRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.opId,
      referencedTable: $db.operationRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationRowsTableOrderingComposer(
            $db: $db,
            $table: $db.operationRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HeadRowsTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $HeadRowsTable> {
  $$HeadRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  $$OperationRowsTableAnnotationComposer get opId {
    final $$OperationRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.opId,
      referencedTable: $db.operationRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.operationRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HeadRowsTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $HeadRowsTable,
          HeadRow,
          $$HeadRowsTableFilterComposer,
          $$HeadRowsTableOrderingComposer,
          $$HeadRowsTableAnnotationComposer,
          $$HeadRowsTableCreateCompanionBuilder,
          $$HeadRowsTableUpdateCompanionBuilder,
          (HeadRow, $$HeadRowsTableReferences),
          HeadRow,
          PrefetchHooks Function({bool opId})
        > {
  $$HeadRowsTableTableManager(_$LedgerDatabase db, $HeadRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HeadRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HeadRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HeadRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> opId = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HeadRowsCompanion(
                opId: opId,
                entityId: entityId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String opId,
                required String entityId,
                Value<int> rowid = const Value.absent(),
              }) => HeadRowsCompanion.insert(
                opId: opId,
                entityId: entityId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HeadRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({opId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (opId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.opId,
                                referencedTable: $$HeadRowsTableReferences
                                    ._opIdTable(db),
                                referencedColumn: $$HeadRowsTableReferences
                                    ._opIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$HeadRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $HeadRowsTable,
      HeadRow,
      $$HeadRowsTableFilterComposer,
      $$HeadRowsTableOrderingComposer,
      $$HeadRowsTableAnnotationComposer,
      $$HeadRowsTableCreateCompanionBuilder,
      $$HeadRowsTableUpdateCompanionBuilder,
      (HeadRow, $$HeadRowsTableReferences),
      HeadRow,
      PrefetchHooks Function({bool opId})
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$LedgerDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$LedgerDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$LedgerDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$LedgerDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$LedgerDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$LedgerDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$LedgerDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$LedgerDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $LedgerDatabaseManager {
  final _$LedgerDatabase _db;
  $LedgerDatabaseManager(this._db);
  $$OperationRowsTableTableManager get operationRows =>
      $$OperationRowsTableTableManager(_db, _db.operationRows);
  $$HeadRowsTableTableManager get headRows =>
      $$HeadRowsTableTableManager(_db, _db.headRows);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
