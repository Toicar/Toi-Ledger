import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/features/statistics/chart_viewport.dart';

void main() {
  test('zoom keeps the date under the focal point', () {
    final full = ChartViewport.full(366);
    final zoomed = full.zoom(4, .7);
    expect(zoomed.span, 91.5);
    expect(zoomed.start + zoomed.span * .7, closeTo(366 * .7, 1e-9));
    final translated = zoomed.transform(
      scale: 1.5,
      initialFocal: .4,
      currentFocal: .6,
    );
    expect(
      translated.start + translated.span * .6,
      closeTo(zoomed.start + zoomed.span * .4, 1e-9),
    );
  });

  test('pan and zoom clamp dates with a two day minimum', () {
    final full = ChartViewport.full(31);
    expect(full.pan(999).start, 0);
    final zoomed = full.zoom(1000, .5);
    expect(zoomed.span, 2);
    expect(zoomed.pan(-999).start, 0);
    expect(zoomed.pan(999).end, 31);
    expect(zoomed.zoom(.00001, .5).span, 31);
    expect(ChartViewport.full(1).zoom(100, .5).span, 1);
  });

  test('non finite gesture values never produce invalid viewports', () {
    final viewport = ChartViewport.full(31).zoom(2, .5);
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
      0.0,
      -1.0,
    ]) {
      final result = viewport.zoom(value, double.nan).pan(value);
      expect(result.start.isFinite, isTrue);
      expect(result.span.isFinite, isTrue);
      expect(result.start, greaterThanOrEqualTo(0));
      expect(result.end, lessThanOrEqualTo(31));
    }
  });
}
