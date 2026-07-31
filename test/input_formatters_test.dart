import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motogest/utils/input_formatters.dart';

TextEditingValue _apply(TextInputFormatter f, String oldText, String newText) {
  return f.formatEditUpdate(
    TextEditingValue(text: oldText),
    TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length)),
  );
}

void main() {
  group('cpfInputFormatter', () {
    test('formata dígitos como 000.000.000-00', () {
      final result = _apply(cpfInputFormatter, '', '12345678901');
      expect(result.text, '123.456.789-01');
    });

    test('ignora letras digitadas', () {
      final result = _apply(cpfInputFormatter, '', '123abc456');
      expect(result.text, '123.456');
    });

    test('trunca em 11 dígitos', () {
      final result = _apply(cpfInputFormatter, '', '123456789013456');
      expect(result.text, '123.456.789-01');
    });
  });

  group('phoneInputFormatter', () {
    test('celular (11 dígitos) usa hífen após o 5º dígito do número', () {
      final result = _apply(phoneInputFormatter, '', '91987654321');
      expect(result.text, '(91) 98765-4321');
    });

    test('fixo (10 dígitos) usa hífen após o 4º dígito do número', () {
      final result = _apply(phoneInputFormatter, '', '9187654321');
      expect(result.text, '(91) 8765-4321');
    });

    test('ignora letras digitadas', () {
      final result = _apply(phoneInputFormatter, '', '(91) abc987-6543a21');
      expect(result.text, '(91) 98765-4321');
    });
  });

  group('CurrencyInputFormatter', () {
    final formatter = CurrencyInputFormatter();

    test('trata os dígitos como centavos', () {
      final result = _apply(formatter, '', '1234');
      expect(result.text, contains('12,34'));
    });

    test('campo vazio permanece vazio', () {
      final result = _apply(formatter, 'R\$ 12,34', '');
      expect(result.text, '');
    });
  });

  group('parseCurrencyInput', () {
    test('extrai o valor numérico de um texto formatado', () {
      expect(parseCurrencyInput('R\$ 1.234,56'), 1234.56);
      expect(parseCurrencyInput(''), 0);
    });
  });
}
