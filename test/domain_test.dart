import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ledger/domain/operation.dart';
import 'support.dart';

void main() {
  test('money parsing uses exact minor units', () {
    expect(parseAmount('0.01'), 1);
    expect(parseAmount('12.30'), 1230);
    expect(parseAmount('9999999999.99'), maxAmountMinor);
    expect(formatAmount(-1234), '-12.34');
    for (final bad in [
      '0',
      '-1',
      'NaN',
      '1e3',
      '01',
      '.1',
      '1.001',
      '10000000000',
      '1,000',
    ]) {
      expect(
        () => parseAmount(bad),
        throwsA(isA<LedgerException>()),
        reason: bad,
      );
    }
  });
  test('date validation rejects normalization and bounds', () {
    expect(requireDate('2024-02-29'), '2024-02-29');
    for (final bad in [
      '2026-02-29',
      '2026-04-31',
      '2026-13-01',
      '2026-1-01',
      '1899-01-01',
    ]) {
      expect(() => requireDate(bad), throwsA(isA<LedgerException>()));
    }
  });
  test('operation round trip, canonical ordering and tamper detection', () {
    final op = Operation(
      id: uuid.v4(),
      ledgerId: uuid.v4(),
      deviceId: uuid.v4(),
      entityId: uuid.v4(),
      entityType: EntityType.category,
      parents: [],
      data: {'name': '测试', 'kind': 'expense'},
      deleted: false,
      createdAt: '2026-10-21T00:00:00.000Z',
    );
    expect(Operation.decode(op.encode()).canonical, op.canonical);
    final envelope = jsonDecode(op.encode()) as Map<String, dynamic>;
    envelope['operation']['data']['name'] = '被修改';
    expect(
      () => Operation.decode(jsonEncode(envelope)),
      throwsA(isA<LedgerException>()),
    );
    envelope['operation']['version'] = 99;
    expect(
      () => Operation.decode(jsonEncode(envelope)),
      throwsA(isA<LedgerException>()),
    );
    expect(canonicalJson({'b': 2, 'a': 1}), '{"a":1,"b":2}');
  });
}
