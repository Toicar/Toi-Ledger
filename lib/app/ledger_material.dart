import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation_controller.dart';
import 'app_theme.dart';

class LedgerCanvas extends ConsumerWidget {
  const LedgerCanvas({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(presentationProvider);
    return CustomPaint(
      painter: _MaterialCanvas(
        settings.style,
        settings.accent.seed,
        Theme.of(context).brightness == Brightness.dark,
      ),
      child: child,
    );
  }
}

/// Blur stays on the overview; scrolling cards use transparent theme surfaces.
class LedgerSurface extends ConsumerWidget {
  const LedgerSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(presentationProvider).style != LedgerStyle.glass) {
      return Card(child: child);
    }
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: .10),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? .16 : .72),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface.withValues(alpha: .66),
                  theme.colorScheme.surface.withValues(alpha: .36),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class LedgerMaterialSample extends StatelessWidget {
  const LedgerMaterialSample({
    super.key,
    required this.style,
    required this.seed,
    required this.dark,
  });
  final LedgerStyle style;
  final Color seed;
  final bool dark;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      height: 100,
      width: double.infinity,
      child: CustomPaint(
        painter: _MaterialCanvas(style, seed, dark, sample: true),
      ),
    ),
  );
}

class _MaterialCanvas extends CustomPainter {
  const _MaterialCanvas(
    this.style,
    this.seed,
    this.dark, {
    this.sample = false,
  });
  final LedgerStyle style;
  final Color seed;
  final bool dark, sample;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paper = dark ? LedgerColors.darkPaper : LedgerColors.paper;
    canvas.drawRect(
      rect,
      Paint()..color = Color.alphaBlend(seed.withValues(alpha: .03), paper),
    );
    if (style == LedgerStyle.glass) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(seed.withValues(alpha: dark ? .28 : .16), paper),
              paper,
              Color.alphaBlend(seed.withValues(alpha: dark ? .10 : .24), paper),
            ],
          ).createShader(rect),
      );
      for (final (center, radius, color) in [
        (
          Offset(size.width * .18, size.height * .18),
          size.shortestSide * .65,
          seed,
        ),
        (
          Offset(size.width * .85, size.height * .76),
          size.shortestSide * .72,
          HSLColor.fromColor(
            seed,
          ).withHue((HSLColor.fromColor(seed).hue + 65) % 360).toColor(),
        ),
      ]) {
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                color.withValues(alpha: dark ? .20 : .24),
                color.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: center, radius: radius)),
        );
      }
    } else {
      // Sparse deterministic fibers avoid bitmap assets and per-frame randomness.
      final grain = Paint()
        ..color = (dark ? Colors.white : seed).withValues(alpha: .045)
        ..strokeWidth = .6;
      for (var y = 5.0; y < size.height; y += 15) {
        for (var x = 4.0 + ((y ~/ 15) % 3) * 5; x < size.width; x += 19) {
          canvas.drawLine(Offset(x, y), Offset(x + 2.3, y + .6), grain);
        }
      }
    }
    if (sample) {
      final glass = style == LedgerStyle.glass;
      final card = RRect.fromRectAndRadius(
        Rect.fromLTWH(14, 16, size.width - 28, size.height - 32),
        Radius.circular(glass ? 14 : 8),
      );
      if (!glass) {
        canvas.drawShadow(
          Path()..addRRect(card),
          Colors.black.withValues(alpha: .10),
          3,
          false,
        );
      }
      canvas.drawRRect(
        card,
        Paint()
          ..color = (dark ? const Color(0xff343630) : Colors.white).withValues(
            alpha: glass ? .48 : .96,
          ),
      );
      canvas.drawRRect(
        card,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = (glass ? Colors.white : seed).withValues(
            alpha: glass ? .65 : .15,
          ),
      );
      final line = Paint()
        ..color = seed.withValues(alpha: dark ? .9 : .8)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(28, 36), Offset(size.width * .55, 36), line);
      line
        ..strokeWidth = 3
        ..color = (dark ? Colors.white : Colors.black).withValues(alpha: .22);
      canvas.drawLine(const Offset(28, 51), Offset(size.width * .70, 51), line);
      canvas.drawLine(const Offset(28, 62), Offset(size.width * .44, 62), line);
    }
  }

  @override
  bool shouldRepaint(_MaterialCanvas old) =>
      old.style != style ||
      old.seed != seed ||
      old.dark != dark ||
      old.sample != sample;
}
