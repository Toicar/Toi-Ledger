import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/providers.dart';
import 'package:my_ledger/data/entry_templates.dart';
import 'package:my_ledger/features/categories/categories_page.dart';
import 'package:my_ledger/features/sync/settings_page.dart';
import 'package:my_ledger/domain/operation.dart';
import 'support.dart';
import 'redesign_test.dart' show closeLedger;
import 'templates_widget_test.dart' show showTemplates;
import 'widget_test.dart' show EmptyCredentials, settle;

void main() {
  testWidgets(
    'explicit category edit preserves ID, entry references and history',
    (tester) async {
      final repo = memoryRepository();
      late Operation original;
      await tester.runAsync(() async {
        original = await category(repo, name: '餐饮');
        await entry(repo, original);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: CategoriesPage()),
        ),
      );
      await settle(tester);
      await tester.tap(find.byTooltip('编辑分类'));
      await settle(tester);
      expect(find.text('编辑分类'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, '名称'), '');
      await tester.tap(find.text('保存'));
      await settle(tester);
      expect(find.text('编辑分类'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, '名称'), '日常餐饮');
      await tester.tap(find.text('保存'));
      await settle(tester);
      expect(find.text('日常餐饮'), findsOneWidget);
      final views = (await tester.runAsync(repo.snapshot))!;
      final cat = views
          .singleWhere((view) => view.current.entityType == EntityType.category)
          .current;
      expect(cat.entityId, original.entityId);
      expect(cat.parents, [original.id]);
      expect(
        views
            .singleWhere((view) => view.current.entityType == EntityType.entry)
            .current
            .data['categoryId'],
        original.entityId,
      );
      expect(
        (await tester.runAsync(
          () => repo.operation(original.id),
        ))!.data['name'],
        '餐饮',
      );
      expect(tester.takeException(), isNull);
      await closeLedger(tester, repo);
    },
  );

  testWidgets(
    'category above type can select income without first changing type',
    (tester) async {
      final repo = memoryRepository();
      await tester.runAsync(() async {
        await category(repo, name: '餐饮');
        await category(repo, kind: 'income', name: '工资');
      });
      await showTemplates(tester, repo);
      await tester.tap(find.byTooltip('添加模板'));
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, '模板名称'),
        '固定工资',
      );
      final categoryField = find.widgetWithText(
        DropdownButtonFormField<String>,
        '分类（可选）',
      );
      final kindField = find.widgetWithText(
        DropdownButtonFormField<String>,
        '类型',
      );
      expect(
        tester.getTopLeft(categoryField).dy,
        lessThan(tester.getTopLeft(kindField).dy),
      );
      await tester.tap(categoryField);
      await settle(tester);
      await tester.tap(find.text('工资').last);
      await settle(tester);
      expect(
        find.byKey(const ValueKey('template-kind:income')),
        findsOneWidget,
      );
      await tester.tap(find.text('保存模板'));
      await settle(tester);
      final template = (await tester.runAsync(
        () => EntryTemplatePreferences(repo.db).read(),
      ))!.single;
      expect(template.kind, 'income');
      expect(template.categoryId, isNotNull);
      expect(template.amountMinor, isNull);
      expect(tester.takeException(), isNull);
      await closeLedger(tester, repo);
    },
  );

  testWidgets(
    'password visibility is reversible and setup guide has real provisioning steps',
    (tester) async {
      final repo = memoryRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            credentialProvider.overrideWithValue(EmptyCredentials()),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await settle(tester);
      final field = find.widgetWithText(TextField, '应用专用密码');
      await tester.ensureVisible(field);
      await settle(tester);
      await tester.enterText(field, 'synthetic-password');
      expect(tester.widget<TextField>(field).obscureText, isTrue);
      await tester.tap(find.byTooltip('显示密码'));
      await settle(tester);
      expect(tester.widget<TextField>(field).obscureText, isFalse);
      await tester.tap(find.byTooltip('隐藏密码'));
      await settle(tester);
      expect(tester.widget<TextField>(field).obscureText, isTrue);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('open-sync-guide')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('open-sync-guide')));
      await settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('webdav-setup-instructions')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      await tester.tap(find.text('还没有 WebDAV？从零搭建'));
      await settle(tester);
      expect(find.textContaining('Setup-WebDAV.cmd'), findsOneWidget);
      expect(find.textContaining('service-setup.json'), findsOneWidget);
      expect((await tester.runAsync(repo.allOperations))!, isEmpty);
      expect(tester.takeException(), isNull);
      await closeLedger(tester, repo);
    },
  );

  testWidgets(
    'service import requires fingerprint review and keeps ledger and password',
    (tester) async {
      final repo = memoryRepository();
      final id = (await tester.runAsync(() => repo.ledgerId))!;
      late Directory temporary;
      late String certificate;
      await tester.runAsync(() async {
        temporary = await Directory.systemTemp.createTemp(
          'myledger-import-ui-',
        );
        final generated = await Process.run('openssl', [
          'req',
          '-x509',
          '-newkey',
          'rsa:2048',
          '-nodes',
          '-keyout',
          '${temporary.path}/key.pem',
          '-out',
          '${temporary.path}/ca.pem',
          '-days',
          '1',
          '-subj',
          '/CN=setup-test',
        ]);
        expect(generated.exitCode, 0);
        certificate = await File('${temporary.path}/ca.pem').readAsString();
      });
      addTearDown(() async {
        expect(
          temporary.parent.absolute.path,
          Directory.systemTemp.absolute.path,
        );
        await temporary.delete(recursive: true);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            credentialProvider.overrideWithValue(EmptyCredentials()),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text('导入 WebDAV 服务配置'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      await tester.tap(find.text('导入 WebDAV 服务配置'));
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextField, '公共服务配置 JSON'),
        '{bad',
      );
      await tester.tap(find.text('检查配置'));
      await settle(tester);
      expect(find.textContaining('服务配置无效'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, '公共服务配置 JSON'),
        jsonEncode({
          'version': 1,
          'endpoint': 'https://192.168.1.20:8443/dav/',
          'username': 'myledger',
          'caPem': certificate,
        }),
      );
      await tester.tap(find.text('检查配置'));
      await settle(tester);
      expect(find.text('公共证书 SHA-256（按文件内容计算）'), findsOneWidget);
      await tester.tap(find.text('信任此服务并填入'));
      await settle(tester);
      final endpoint = tester.widget<TextField>(
        find.widgetWithText(TextField, 'HTTPS WebDAV 根目录（必须已存在）'),
      );
      expect(endpoint.controller!.text, 'https://192.168.1.20:8443/dav/');
      expect((await tester.runAsync(() => repo.ledgerId))!, id);
      expect((await tester.runAsync(repo.allOperations))!, isEmpty);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '应用专用密码'))
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await closeLedger(tester, repo);
    },
  );
}
