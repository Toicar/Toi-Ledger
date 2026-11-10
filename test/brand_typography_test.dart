import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/app/app_theme.dart';
import 'package:my_ledger/app/brand_mark.dart';
import 'package:my_ledger/app/design_components.dart';
import 'package:my_ledger/app/presentation_controller.dart';
import 'package:my_ledger/features/statistics/category_chart.dart';
import 'support.dart';
import 'redesign_test.dart' show pumpLedger, closeLedger;
import 'widget_test.dart' show settle;

String? renderedFamily(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(finder).text.style?.fontFamily;

void main() {
  test(
    'brand hides the ledger behind pen and bottle without erasing paper',
    () async {
      const paper = Color(0xfffaf8f3);
      const ink = Color(0xffb75b3e);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(paper, BlendMode.src);
      LedgerBrand.paint(canvas, ink);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1024, 1024);
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        void expectColor(int x, int y, Color expected) {
          final offset = (1024 * y + x) * 4;
          final argb = expected.toARGB32();
          expect(bytes.getUint8(offset), (argb >> 16) & 255);
          expect(bytes.getUint8(offset + 1), (argb >> 8) & 255);
          expect(bytes.getUint8(offset + 2), argb & 255);
          expect(bytes.getUint8(offset + 3), 255);
        }

        expectColor(627, 722, paper); // Rear book edge inside the open bottle.
        expectColor(614, 552, ink); // Curved barrel in front of the book edge.
        expectColor(652, 610, paper); // Nib's breather hole.
        expectColor(663, 637, paper); // Slit remains distinct above the bottle.
        expectColor(684, 792, ink); // Foreground bottle's base.
      } finally {
        image.dispose();
        picture.dispose();
      }
    },
  );

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      '$platform: rendered money, buttons, editor and chart use one body face',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final repo = memoryRepository();
        await tester.runAsync(() async {
          final cat = await category(repo, name: '日常餐饮');
          await entry(
            repo,
            cat,
            amount: 12345,
            date: DateTime.now().toIso8601String().substring(0, 10),
          );
        });
        await pumpLedger(
          tester,
          repo,
          size: platform == TargetPlatform.windows
              ? const Size(1280, 900)
              : const Size(420, 900),
        );
        final body = platform == TargetPlatform.windows ? 'Cambria' : 'serif';
        final cjkBody = platform == TargetPlatform.windows
            ? 'Microsoft YaHei UI'
            : 'sans-serif';
        final title = body;
        expect(renderedFamily(tester, find.text('每一笔，都是生活。')), title);
        expect(
          tester
              .renderObject<RenderParagraph>(find.text('每一笔，都是生活。'))
              .text
              .style
              ?.fontFamilyFallback,
          platform == TargetPlatform.windows ? ['SimSun'] : isEmpty,
        );
        expect(
          renderedFamily(
            tester,
            find.text(
              platform == TargetPlatform.windows ? '¥123.45' : '支出 ¥123.45',
            ),
          ),
          body,
        );
        expect(renderedFamily(tester, find.text('记一笔')), body);
        expect(
          tester
              .renderObject<RenderParagraph>(find.text('记一笔'))
              .text
              .style
              ?.fontFamilyFallback,
          [cjkBody],
        );
        await tester.tap(find.text('记一笔'));
        await settle(tester);
        final amountEditor = find.descendant(
          of: find.widgetWithText(TextFormField, '金额（元）'),
          matching: find.byType(EditableText),
        );
        expect(
          tester.widget<EditableText>(amountEditor).style.fontFamily,
          body,
        );
        expect(
          tester.widget<EditableText>(amountEditor).style.fontFamilyFallback,
          [cjkBody],
        );
        await tester.tap(find.text('取消'));
        await settle(tester);
        await tester.ensureVisible(find.text('统计分析').first);
        await settle(tester);
        await tester.tap(find.text('统计分析').first);
        await settle(tester);
        final chart = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('category-chart')),
        );
        expect(
          (chart.painter! as CategoryPlotPainter).labelStyle.fontFamily,
          body,
        );
        expect(
          (chart.painter! as CategoryPlotPainter).labelStyle.fontFamilyFallback,
          [cjkBody],
        );
        expect(tester.takeException(), isNull);
        await closeLedger(tester, repo);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness: notebook hides rear leaves and pot hides its stem',
      (tester) async {
        final theme = AppTheme.resolve(
          brightness,
          LedgerStyle.satin,
          platform: TargetPlatform.windows,
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: const SizedBox(
                    width: 160,
                    height: 160,
                    child: LedgerStillLife(size: 160),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          } finally {
            image.dispose();
          }
        });
        void expectPaperAt(int x, int y, double tint) {
          final expected = Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: tint),
            theme.colorScheme.surface,
          ).toARGB32();
          final index = (160 * y + x) * 4;
          expect(bytes!.getUint8(index), closeTo((expected >> 16) & 255, 1));
          expect(bytes.getUint8(index + 1), closeTo((expected >> 8) & 255, 1));
          expect(bytes.getUint8(index + 2), closeTo(expected & 255, 1));
          expect(bytes.getUint8(index + 3), 255);
        }

        // These interior points previously exposed a stem through the notebook,
        // or continued the stem below the pot's upper edge.
        expectPaperAt(105, 90, .08);
        expectPaperAt(126, 109, .04);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
