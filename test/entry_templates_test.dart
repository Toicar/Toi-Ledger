import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/providers.dart';
import 'package:my_ledger/data/database.dart';
import 'package:my_ledger/data/entry_templates.dart';
import 'package:my_ledger/data/ledger_repository.dart';
import 'package:my_ledger/domain/operation.dart';
import 'support.dart';

EntryTemplate template({String? id, String? categoryId, String name = '午餐'}) =>
    EntryTemplate(
      id: id ?? uuid.v4(),
      name: name,
      kind: 'expense',
      categoryId: categoryId ?? uuid.v4(),
      amountMinor: 1234,
      note: '工作日午餐',
    );

void main() {
  late LedgerRepository repo;
  late ProviderContainer container;
  setUp(() {
    repo = memoryRepository();
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
  });
  tearDown(() async {
    container.dispose();
    await repo.db.close();
  });

  Future<List<EntryTemplate>> loaded() =>
      container.read(entryTemplatesProvider.notifier).ready;

  test(
    'missing templates load empty without creating settings or operations',
    () async {
      expect(await loaded(), isEmpty);
      expect(await repo.db.select(repo.db.settings).get(), isEmpty);
      expect(await repo.allOperations(), isEmpty);
    },
  );

  test('template CRUD persists locally without ledger operations', () async {
    final first = template();
    final controller = container.read(entryTemplatesProvider.notifier);
    await controller.save(first);
    expect(
      (await EntryTemplatePreferences(repo.db).read()).single.toJson(),
      first.toJson(),
    );
    final changed = template(id: first.id, name: '晚餐');
    await controller.save(changed);
    expect(
      container.read(entryTemplatesProvider).requireValue.single.name,
      '晚餐',
    );
    await controller.remove(first.id);
    expect(await EntryTemplatePreferences(repo.db).read(), isEmpty);
    expect(await repo.allOperations(), isEmpty);
    expect(await repo.db.select(repo.db.headRows).get(), isEmpty);
  });

  test(
    'queued updates keep additions and continue after a rejected change',
    () async {
      final controller = container.read(entryTemplatesProvider.notifier);
      final first = template();
      final second = template();
      await Future.wait([controller.save(first), controller.save(second)]);
      expect(
        container.read(entryTemplatesProvider).requireValue.map((t) => t.id),
        [first.id, second.id],
      );
      await expectLater(
        controller.remove('invalid'),
        throwsA(isA<LedgerException>()),
      );
      await controller.remove(first.id);
      expect(
        (await EntryTemplatePreferences(repo.db).read()).single.id,
        second.id,
      );
    },
  );

  test('failed write preserves prior memory and persisted JSON', () async {
    final controller = container.read(entryTemplatesProvider.notifier);
    final first = template();
    await controller.save(first);
    final stored = (await repo.db.select(repo.db.settings).get()).single.value;
    await repo.db.customStatement('PRAGMA query_only = ON');
    await expectLater(controller.save(template()), throwsA(isA<Exception>()));
    expect(
      container.read(entryTemplatesProvider).requireValue.single.id,
      first.id,
    );
    expect((await repo.db.select(repo.db.settings).get()).single.value, stored);
  });

  test(
    'corrupt read remains an error and cannot be overwritten by save',
    () async {
      await repo.db
          .into(repo.db.settings)
          .insert(
            SettingsCompanion.insert(
              key: EntryTemplatePreferences.key,
              value: '{broken',
            ),
          );
      final controller = container.read(entryTemplatesProvider.notifier);
      await expectLater(controller.ready, throwsA(isA<LedgerException>()));
      expect(container.read(entryTemplatesProvider).hasError, isTrue);
      await expectLater(
        controller.save(template()),
        throwsA(isA<LedgerException>()),
      );
      expect(
        (await repo.db.select(repo.db.settings).get()).single.value,
        '{broken',
      );
    },
  );

  test('database read failures are surfaced', () async {
    await repo.db.customStatement('DROP TABLE settings');
    final controller = container.read(entryTemplatesProvider.notifier);
    await expectLater(controller.ready, throwsA(isA<Exception>()));
    expect(container.read(entryTemplatesProvider).hasError, isTrue);
  });

  test('disk reopen restores versioned templates', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger-templates-',
    );
    final file = File('${directory.path}/ledger.sqlite');
    var db = LedgerDatabase(NativeDatabase(file));
    final saved = template();
    try {
      await EntryTemplatePreferences(db).write([saved]);
      await db.close();
      db = LedgerDatabase(NativeDatabase(file));
      expect(
        (await EntryTemplatePreferences(db).read()).single.toJson(),
        saved.toJson(),
      );
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'strict decoding rejects malformed, extra and unsupported fields',
    () async {
      final valid = {
        'version': 1,
        'templates': [template().toJson()],
      };
      for (final invalid in <Object?>[
        [],
        {'version': 3, 'templates': []},
        {'version': 1.0, 'templates': []},
        {...valid, 'extra': true},
        {
          'version': 1,
          'templates': [
            {...template().toJson(), 'extra': true},
          ],
        },
        {
          'version': 1,
          'templates': [
            {...template().toJson(), 'amountMinor': 1.2},
          ],
        },
      ]) {
        await repo.db
            .into(repo.db.settings)
            .insertOnConflictUpdate(
              SettingsCompanion.insert(
                key: EntryTemplatePreferences.key,
                value: jsonEncode(invalid),
              ),
            );
        await expectLater(
          EntryTemplatePreferences(repo.db).read(),
          throwsA(isA<LedgerException>()),
        );
      }
    },
  );

  test('template validates UUID, kind, name, amount and note', () {
    final valid = template().toJson();
    for (final change in <Map<String, Object?>>[
      {'id': 'invalid'},
      {'categoryId': 'invalid'},
      {'name': ' '},
      {'name': '名' * 41},
      {'kind': 'transfer'},
      {'amountMinor': 0},
      {'amountMinor': maxAmountMinor + 1},
      {'note': '注' * 501},
    ]) {
      expect(
        () => EntryTemplate.fromJson({...valid, ...change}),
        throwsA(isA<LedgerException>()),
      );
    }
  });

  test('fifty templates may be edited but a fifty-first is rejected', () async {
    final controller = container.read(entryTemplatesProvider.notifier);
    final templates = List.generate(50, (_) => template());
    await EntryTemplatePreferences(repo.db).write(templates);
    await controller.reload();
    await expectLater(
      controller.save(template()),
      throwsA(isA<LedgerException>()),
    );
    await controller.save(template(id: templates.first.id, name: '新名称'));
    expect(container.read(entryTemplatesProvider).requireValue, hasLength(50));
    expect(
      container.read(entryTemplatesProvider).requireValue.first.name,
      '新名称',
    );
    await expectLater(
      EntryTemplatePreferences(repo.db).write([...templates, template()]),
      throwsA(isA<LedgerException>()),
    );
    await expectLater(
      EntryTemplatePreferences(
        repo.db,
      ).write([templates.first, templates.first]),
      throwsA(isA<LedgerException>()),
    );
  });

  test(
    'category availability explains missing archived conflicting or changed kind',
    () async {
      final cat = await category(repo);
      final saved = template(categoryId: cat.entityId);
      expect(
        templateCategoryIssue(saved, [
          EntityView([cat]),
        ]),
        isNull,
      );
      expect(templateCategoryIssue(saved, []), contains('缺失'));
      final archived = await repo.save(
        entityId: cat.entityId,
        type: EntityType.category,
        data: cat.data,
        deleted: true,
        expectedHeads: [cat.id],
      );
      expect(
        templateCategoryIssue(saved, [
          EntityView([archived]),
        ]),
        contains('归档'),
      );
      expect(
        templateCategoryIssue(saved, [
          EntityView([cat, archived]),
        ]),
        contains('冲突'),
      );
      final income = Operation(
        id: uuid.v4(),
        ledgerId: cat.ledgerId,
        deviceId: cat.deviceId,
        entityId: cat.entityId,
        entityType: EntityType.category,
        parents: [],
        data: {'name': '变更类型', 'kind': 'income'},
        deleted: false,
        createdAt: cat.createdAt,
      );
      expect(
        templateCategoryIssue(saved, [
          EntityView([income]),
        ]),
        contains('类型'),
      );
    },
  );
}
