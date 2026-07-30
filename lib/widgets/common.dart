import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Formatação de moeda em Real, equivalente a Intl.NumberFormat('pt-BR').
final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
String formatCurrency(double v) => _currency.format(v);

String formatDate(String iso) {
  final d = DateTime.parse(iso);
  return DateFormat('dd/MM/yyyy').format(d);
}

String formatDateTime(String iso) {
  final d = DateTime.parse(iso);
  return DateFormat('dd/MM/yyyy HH:mm').format(d);
}

/// Executa uma escrita assíncrona (Firestore) e mostra um SnackBar de erro
/// caso ela falhe, em vez de deixar a falha desaparecer silenciosamente.
/// Retorna `true` em caso de sucesso, para o chamador decidir se ainda mostra
/// um toast de sucesso.
Future<bool> runGuarded(
  BuildContext context,
  Future<void> Function() action, {
  String errorMessage =
      'Não foi possível salvar. Verifique sua conexão e tente novamente.',
}) async {
  try {
    await action();
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.destructive,
        ),
      );
    }
    return false;
  }
}

enum BadgeVariant { primary, secondary, outline, destructive, success }

/// Equivalente ao componente Badge do shadcn/ui.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.primary,
    this.icon,
  });

  final String label;
  final BadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    Border? border;

    switch (variant) {
      case BadgeVariant.primary:
        bg = AppColors.primary;
        fg = AppColors.primaryForeground;
        break;
      case BadgeVariant.secondary:
        bg = AppColors.secondary;
        fg = AppColors.secondaryForeground;
        break;
      case BadgeVariant.outline:
        bg = Colors.transparent;
        fg = AppColors.foreground;
        border = Border.all(color: AppColors.border);
        break;
      case BadgeVariant.destructive:
        bg = AppColors.destructive;
        fg = AppColors.destructiveForeground;
        break;
      case BadgeVariant.success:
        bg = AppColors.green600;
        fg = Colors.white;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: border,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Ícone do pistão desenhado via CustomPainter, espelhando o SVG piston-icon.tsx.
class PistonIcon extends StatelessWidget {
  const PistonIcon({super.key, this.size = 24, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PistonPainter(color ?? AppColors.primary),
    );
  }
}

class _PistonPainter extends CustomPainter {
  _PistonPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    Offset p(double x, double y) => Offset(x * s, y * s);

    // Biela
    canvas.drawLine(p(12, 14), p(12, 20), stroke);
    canvas.drawCircle(p(12, 21), 1.5 * s, stroke);
    // Anéis do pistão
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(7 * s, 8 * s, 10 * s, 1.5 * s),
            Radius.circular(0.5 * s)),
        fill);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(7 * s, 10.5 * s, 10 * s, 1.5 * s),
            Radius.circular(0.5 * s)),
        fill);
    // Corpo do pistão
    final body = Path()
      ..moveTo(8 * s, 3 * s)
      ..lineTo(8 * s, 13 * s)
      ..lineTo(16 * s, 13 * s)
      ..lineTo(16 * s, 3 * s)
      ..close();
    canvas.drawPath(body, stroke);
    // Pino
    canvas.drawCircle(p(12, 13.5), 1 * s, fill);
    final pin = Paint()
      ..color = color
      ..strokeWidth = 2.5 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p(10, 13.5), p(14, 13.5), pin);
    // Linhas de detalhe
    final faint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p(8, 5), p(16, 5), faint);
    canvas.drawLine(p(8, 7), p(16, 7), faint);
  }

  @override
  bool shouldRepaint(covariant _PistonPainter old) => old.color != color;
}

/// Cabeçalho de uma página, com ícone em caixa colorida, título e subtítulo.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 32, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(color: AppColors.mutedForeground)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Card de estatística simples (rótulo + número grande), usado nos topos das páginas.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.mutedForeground)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: valueColor)),
        ],
      ),
    );
  }
}
