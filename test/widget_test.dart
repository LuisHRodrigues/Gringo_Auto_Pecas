import 'package:flutter_test/flutter_test.dart';
import 'package:gmp_gestor/widgets/common.dart';

void main() {
  group('formatCurrency', () {
    test('formata valores em Real', () {
      expect(formatCurrency(1234.5), contains('1.234,50'));
      expect(formatCurrency(1234.5), startsWith('R\$'));
      expect(formatCurrency(0), contains('0,00'));
    });
  });

  group('formatDate', () {
    test('formata data ISO em dd/MM/yyyy', () {
      expect(formatDate('2026-07-29T10:00:00.000'), '29/07/2026');
    });
  });

  group('formatDateTime', () {
    test('formata data e hora ISO', () {
      expect(formatDateTime('2026-07-29T10:05:00.000'), '29/07/2026 10:05');
    });
  });
}
