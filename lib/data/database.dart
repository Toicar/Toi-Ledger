import 'package:drift/drift.dart';
part 'database.g.dart';

class OperationRows extends Table {
  TextColumn get id => text()();
  TextColumn get entityId => text()();
  TextColumn get entityType => text()();
  TextColumn get body => text()();
  BoolColumn get pending => boolean()();
  @override
  Set<Column> get primaryKey => {id};
}

class HeadRows extends Table {
  TextColumn get opId => text().references(OperationRows, #id)();
  TextColumn get entityId => text()();
  @override
  Set<Column> get primaryKey => {opId};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [OperationRows, HeadRows, Settings])
class LedgerDatabase extends _$LedgerDatabase {
  LedgerDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX operations_entity ON operation_rows(entity_id)',
      );
      await customStatement(
        'CREATE INDEX heads_entity ON head_rows(entity_id)',
      );
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA busy_timeout = 5000');
      await customStatement('PRAGMA synchronous = FULL');
    },
  );
}
