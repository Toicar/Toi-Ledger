import 'dart:math' as math;

/// Immutable day coordinates, independent of totals and chart aggregation.
class ChartViewport {
  const ChartViewport._(this.totalDays, this.start, this.span);
  factory ChartViewport.full(int totalDays) {
    if (totalDays < 1) throw ArgumentError.value(totalDays, 'totalDays');
    return ChartViewport._(totalDays, 0, totalDays.toDouble());
  }
  final int totalDays;
  final double start, span;
  double get end => start + span;
  ChartViewport _bounded(double nextStart, double nextSpan) {
    final boundedSpan = (nextSpan.isFinite ? nextSpan : span).clamp(
      math.min(2, totalDays).toDouble(),
      totalDays.toDouble(),
    );
    final boundedStart = (nextStart.isFinite ? nextStart : start).clamp(
      0.0,
      totalDays - boundedSpan,
    );
    return ChartViewport._(totalDays, boundedStart, boundedSpan);
  }

  ChartViewport pan(double days) => _bounded(start + days, span);
  ChartViewport zoom(double scale, double focalFraction) => transform(
    scale: scale,
    initialFocal: focalFraction,
    currentFocal: focalFraction,
  );
  ChartViewport transform({
    required double scale,
    required double initialFocal,
    required double currentFocal,
  }) {
    if (!scale.isFinite || scale <= 0) return this;
    final initial = initialFocal.isFinite ? initialFocal.clamp(0.0, 1.0) : .5;
    final current = currentFocal.isFinite ? currentFocal.clamp(0.0, 1.0) : .5;
    final nextSpan = (span / scale).clamp(
      math.min(2, totalDays).toDouble(),
      totalDays.toDouble(),
    );
    return _bounded(start + span * initial - nextSpan * current, nextSpan);
  }
}
