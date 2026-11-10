// Opt-in visual acceptance captures of real widgets and synthetic memory data.
// Local Windows fonts are read only for QA; they are never bundled in the app.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/ledger_app.dart';
import 'package:my_ledger/app/appearance_controller.dart';
import 'package:my_ledger/app/presentation_controller.dart';
import 'package:my_ledger/app/theme_accent.dart';
import 'package:my_ledger/app/providers.dart';
import 'package:my_ledger/domain/operation.dart';
import 'support.dart';
import 'redesign_test.dart' show closeLedger;
import 'widget_test.dart' show EmptyCredentials, settle;

void main() {
  const directory = String.fromEnvironment('MYLEDGER_CAPTURE_DIR');
  testWidgets(
    'visual acceptance: materials, colors, optional categories and drill-down',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(() async {
        for (final (family, files) in [
          ('Cambria', ['cambria.ttc', 'cambriab.ttf']),
          ('Microsoft YaHei UI', ['msyh.ttc', 'msyhbd.ttc']),
          ('SimSun', ['simsun.ttc']),
        ]) {
          final loader = FontLoader(family);
          for (final file in files) {
            final bytes = await File('C:/Windows/Fonts/$file').readAsBytes();
            loader.addFont(Future.value(ByteData.sublistView(bytes)));
          }
          await loader.load();
        }
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        await Directory(directory).create(recursive: true);
      });
      for (final (name, style, accent, mode, size, scale, destination) in [
        (
          'appearance-satin-bamboo',
          LedgerStyle.satin,
          LedgerAccent.bamboo,
          ThemeMode.light,
          const Size(1280, 1100),
          1.0,
          '外观',
        ),
        (
          'appearance-glass-bamboo',
          LedgerStyle.glass,
          LedgerAccent.bamboo,
          ThemeMode.light,
          const Size(1280, 1100),
          1.0,
          '外观',
        ),
        (
          'appearance-glass-lotus-dark',
          LedgerStyle.glass,
          LedgerAccent.lotus,
          ThemeMode.dark,
          const Size(1280, 1100),
          1.0,
          '外观',
        ),
        (
          'appearance-mobile',
          LedgerStyle.satin,
          LedgerAccent.gardenia,
          ThemeMode.light,
          const Size(390, 844),
          1.3,
          '外观',
        ),
        (
          'statistics-groups',
          LedgerStyle.satin,
          LedgerAccent.azure,
          ThemeMode.light,
          const Size(1280, 1100),
          1.0,
          '统计分析',
        ),
        (
          'statistics-other-mobile',
          LedgerStyle.glass,
          LedgerAccent.bamboo,
          ThemeMode.light,
          const Size(390, 844),
          1.2,
          '统计分析',
        ),
        (
          'sync-settings-mobile',
          LedgerStyle.satin,
          LedgerAccent.clay,
          ThemeMode.light,
          const Size(390, 844),
          1.2,
          '同步设置',
        ),
        (
          'sync-guide-desktop',
          LedgerStyle.glass,
          LedgerAccent.azure,
          ThemeMode.light,
          const Size(1280, 1100),
          1.0,
          '同步设置',
        ),
        (
          'sync-guide-mobile',
          LedgerStyle.satin,
          LedgerAccent.clay,
          ThemeMode.light,
          const Size(390, 844),
          1.2,
          '同步设置',
        ),
      ]) {
        final repo = memoryRepository();
        await tester.runAsync(() async {
          final meal = await category(repo, name: '餐饮美食');
          final income = await category(repo, kind: 'income', name: '工资收入');
          final date = DateTime.now().toIso8601String().substring(0, 10);
          await entry(repo, meal, amount: 6800, date: date);
          await entry(repo, income, amount: 1800000, date: date);
          for (final (amount, note) in [
            (280000, '房租 · 一处安稳的角落'),
            (3500, '咖啡与早餐'),
            (1800, '交通零用'),
          ]) {
            await repo.save(
              type: EntityType.entry,
              data: {
                'kind': 'expense',
                'categoryId': null,
                'amountMinor': amount,
                'date': date,
                'note': note,
              },
            );
          }
        });
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(name),
            overrides: [
              repositoryProvider.overrideWithValue(repo),
              credentialProvider.overrideWithValue(EmptyCredentials()),
              initialThemeModeProvider.overrideWithValue(mode),
              initialPresentationProvider.overrideWithValue(
                PresentationSettings(style: style, accent: accent),
              ),
            ],
            child: RepaintBoundary(key: captureKey, child: const LedgerApp()),
          ),
        );
        await settle(tester);
        if (size.width >= 1000) {
          await tester.tap(find.text(destination).first);
        } else if (destination == '外观') {
          await tester.tap(find.byTooltip('外观'));
        } else if (destination == '同步设置') {
          await tester.tap(find.byTooltip('同步设置'));
        } else {
          await tester.ensureVisible(find.text('统计分析').first);
          await tester.tap(find.text('统计分析').first);
        }
        await settle(tester);
        if (name.startsWith('sync-guide')) {
          await tester.tap(find.byKey(const ValueKey('open-sync-guide')));
          await settle(tester);
          if (name == 'sync-guide-mobile') {
            await tester.ensureVisible(find.text('加入现有账本'));
            await settle(tester);
            await tester.tap(find.text('加入现有账本'));
            await settle(tester);
          }
        }
        Future<void> capture(String suffix) async {
          expect(tester.takeException(), isNull, reason: suffix);
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(captureKey),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            try {
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await File('$directory/$suffix.png').writeAsBytes(
                bytes.buffer.asUint8List(
                  bytes.offsetInBytes,
                  bytes.lengthInBytes,
                ),
              );
            } finally {
              image.dispose();
            }
          });
        }

        if (destination == '统计分析') {
          await tester.ensureVisible(find.text('其他'));
          await settle(tester);
          if (name.contains('other-mobile')) {
            await tester.tap(find.text('其他'));
            await settle(tester);
          }
        }
        await capture(name);
        if (name == 'sync-guide-mobile') {
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('webdav-setup-instructions')),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await settle(tester);
          await tester.tap(find.text('还没有 WebDAV？从零搭建'));
          await settle(tester);
          await tester.ensureVisible(find.textContaining('Setup-WebDAV.cmd'));
          await settle(tester);
          await capture('sync-setup-mobile');
        }
        if (name == 'appearance-mobile') {
          await tester.ensureVisible(
            find.byKey(const ValueKey('accent-gardenia')),
          );
          await settle(tester);
          await capture('appearance-mobile-colors');
        }
        if (name.contains('other-mobile')) {
          await tester.scrollUntilVisible(
            find.text('咖啡与早餐'),
            240,
            scrollable: find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .last,
          );
          await settle(tester);
          await capture('statistics-other-mobile-bills');
        }
        await closeLedger(tester, repo);
      }
      debugDefaultTargetPlatformOverride = null;
    },
    skip: directory.isEmpty || !Platform.isWindows,
  );
}
