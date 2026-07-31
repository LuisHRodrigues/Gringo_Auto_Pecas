import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Tipo de campo numérico, usado para escolher o [TextInputFormatter]
/// correto (inteiro sem casas decimais vs. valor monetário).
enum NumericFieldType { integer, currency }

final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

/// Formata o valor conforme o usuário digita, tratando os dígitos como
/// centavos (ex.: digitar "1234" vira "R$ 12,34"), igual à maioria dos
/// campos de valor monetário. Bloqueia letras automaticamente, já que só
/// dígitos são considerados.
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final value = int.parse(digits) / 100;
    final text = _currencyFormat.format(value);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Extrai o valor numérico de um texto formatado por [CurrencyInputFormatter]
/// (ou já em formato "R$ 1.234,56").
double parseCurrencyInput(String text) {
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return 0;
  return int.parse(digits) / 100;
}

/// Texto inicial formatado para um campo monetário (usado ao abrir um
/// formulário de edição, para já exibir "R$ 1.234,56" em vez do double cru).
String formatCurrencyInput(double value) => _currencyFormat.format(value);

/// Formatador genérico de máscara: insere os literais de [mask] nas
/// posições indicadas (indexadas pelo dígito que vem em seguida) e trunca em
/// [maxDigits]. Usado para CPF, CEP etc. — qualquer máscara de largura fixa.
class _DigitMaskFormatter extends TextInputFormatter {
  _DigitMaskFormatter({required this.maxDigits, required this.mask});

  final int maxDigits;
  final Map<int, String> mask;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final literal = mask[i];
      if (literal != null) b.write(literal);
      b.write(digits[i]);
    }
    final text = b.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// CPF: 000.000.000-00 (11 dígitos, bloqueia letras e limita o tamanho).
final cpfInputFormatter = _DigitMaskFormatter(
  maxDigits: 11,
  mask: const {3: '.', 6: '.', 9: '-'},
);

/// Telefone brasileiro: (00) 0000-0000 (fixo, 10 dígitos) ou
/// (00) 00000-0000 (celular, 11 dígitos) — o hífen se ajusta conforme a
/// quantidade de dígitos digitados. Bloqueia letras e limita a 11 dígitos.
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 11) digits = digits.substring(0, 11);
    final hyphenAt = digits.length > 10 ? 7 : 6;
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 0) b.write('(');
      if (i == 2) b.write(') ');
      if (i == hyphenAt) b.write('-');
      b.write(digits[i]);
    }
    final text = b.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

final phoneInputFormatter = PhoneInputFormatter();
