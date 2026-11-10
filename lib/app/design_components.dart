import 'package:flutter/material.dart';
import 'brand_mark.dart';

/// The growing pen and ledger share geometry with the native launcher icon.
class LedgerMark extends StatelessWidget {
  const LedgerMark({super.key, this.size = 36, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _BrandMark(color ?? Theme.of(context).colorScheme.primary),
    ),
  );
}

class _BrandMark extends CustomPainter {
  const _BrandMark(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 720, size.height / 720);
    canvas.translate(-152, -152);
    LedgerBrand.paint(canvas, color, logicalSize: size.width);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrandMark oldDelegate) => oldDelegate.color != color;
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.trailing,
  });
  final String eyebrow, title, description;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.2,
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.headlineLarge),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.7,
            ),
          ),
          if (trailing != null) ...[const SizedBox(height: 18), trailing!],
        ],
      ),
    );
  }
}

class PaperPanel extends StatelessWidget {
  const PaperPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

IconData categoryIcon(String name, {bool income = false}) {
  if (income) return Icons.south_west_rounded;
  if (RegExp('餐|吃|饭|食|饮|咖啡').hasMatch(name)) return Icons.restaurant_rounded;
  if (RegExp('车|交通|出行|油').hasMatch(name)) {
    return Icons.directions_transit_rounded;
  }
  if (RegExp('购|衣|服|日用').hasMatch(name)) return Icons.shopping_bag_outlined;
  if (RegExp('房|住|水|电|家').hasMatch(name)) return Icons.cottage_outlined;
  if (RegExp('医|药|健康').hasMatch(name)) return Icons.favorite_border_rounded;
  if (RegExp('书|学|教育').hasMatch(name)) return Icons.auto_stories_outlined;
  if (RegExp('玩|娱乐|电影').hasMatch(name)) return Icons.local_activity_outlined;
  return Icons.receipt_long_outlined;
}

/// Decorative still life, deliberately distinct from a data visualization.
class LedgerStillLife extends StatelessWidget {
  const LedgerStillLife({super.key, this.size = 140});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _StillLife(
        Theme.of(context).colorScheme.primary,
        Theme.of(context).scaffoldBackgroundColor.a == 0
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).scaffoldBackgroundColor,
      ),
    ),
  );
}

class _StillLife extends CustomPainter {
  const _StillLife(this.clay, this.paper);
  final Color clay, paper;

  Offset stemAt(double t) {
    final u = 1 - t;
    return const Offset(126, 109) * (u * u * u) +
        const Offset(118, 84) * (3 * u * u * t) +
        const Offset(126, 49) * (3 * u * t * t) +
        const Offset(137, 20) * (t * t * t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 160);
    final line = Paint()
      ..color = clay
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
      const Rect.fromLTWH(15, 126, 132, 12),
      Paint()..color = clay.withValues(alpha: .07),
    );
    canvas.drawCircle(
      const Offset(43, 27),
      10,
      Paint()..color = clay.withValues(alpha: .16),
    );

    // The plant stands behind the notebook. Anchor every leaf to the actual
    // stem curve, then cover its hidden parts with the opaque notebook below.
    canvas.drawPath(
      Path()
        ..moveTo(126, 109)
        ..cubicTo(118, 84, 126, 49, 137, 20),
      line,
    );
    for (var i = 0; i < 5; i++) {
      final point = stemAt(.24 + i * .14);
      final side = i.isEven ? -1.0 : 1.0;
      canvas.drawPath(
        Path()
          ..moveTo(point.dx, point.dy)
          ..cubicTo(
            point.dx + side * 16,
            point.dy - 16,
            point.dx + side * 28,
            point.dy - 15,
            point.dx + side * 26,
            point.dy - 8,
          )
          ..cubicTo(
            point.dx + side * 25,
            point.dy + 1,
            point.dx + side * 8,
            point.dy + 4,
            point.dx,
            point.dy,
          ),
        Paint()..color = clay.withValues(alpha: .22),
      );
    }
    canvas.save();
    canvas.translate(28, 55);
    canvas.rotate(-.16);
    final book = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 76, 71),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      book,
      Paint()..color = Color.alphaBlend(clay.withValues(alpha: .08), paper),
    );
    canvas.drawRRect(book, line);
    canvas.drawLine(const Offset(12, 0), const Offset(12, 71), line);
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(24, 23.0 + i * 12),
        Offset(60.0 - i * 5, 23.0 + i * 12),
        line..color = clay.withValues(alpha: .4),
      );
    }
    canvas.restore();
    line.color = clay;
    // The pot is in front of the book's lower corner and hides the stem below
    // its rim, keeping foreground/background relationships unambiguous.
    final pot = Path()
      ..moveTo(112, 104)
      ..lineTo(143, 104)
      ..lineTo(139, 130)
      ..lineTo(116, 130)
      ..close();
    canvas.drawPath(
      pot,
      Paint()..color = Color.alphaBlend(clay.withValues(alpha: .04), paper),
    );
    canvas.drawPath(pot, line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StillLife oldDelegate) =>
      oldDelegate.clay != clay || oldDelegate.paper != paper;
}
