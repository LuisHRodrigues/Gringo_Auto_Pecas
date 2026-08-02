import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_provider.dart';
import '../services/data_provider.dart';
import '../theme/app_theme.dart';
import '../utils/input_formatters.dart';
import '../widgets/common.dart';

const partCategories = [
  'Motor',
  'Freios',
  'Suspensão',
  'Transmissão',
  'Elétrica',
  'Carroceria',
  'Escapamento',
  'Filtros',
  'Outras',
];

class PartsManagementPage extends StatefulWidget {
  const PartsManagementPage({super.key});

  @override
  State<PartsManagementPage> createState() => _PartsManagementPageState();
}

class _PartsManagementPageState extends State<PartsManagementPage> {
  String _query = '';

  // Estoque otimista: os botões +/- atualizam esse valor na hora, antes da
  // escrita no Firestore ida-e-volta terminar (o que pode levar ~1s), pra a
  // tela responder instantaneamente ao clique. A entrada é removida assim
  // que o valor "de verdade" (vindo do listener em tempo real) alcançar o
  // que foi mostrado aqui, ou se a escrita falhar.
  final Map<String, int> _pendingStock = {};

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  List<MotorcyclePart> _withPendingStock(List<MotorcyclePart> parts) {
    _pendingStock.removeWhere(
        (id, stock) => !parts.any((p) => p.id == id && p.stock != stock));
    if (_pendingStock.isEmpty) return parts;
    return [
      for (final p in parts)
        _pendingStock.containsKey(p.id)
            ? p.copyWith(stock: _pendingStock[p.id]!)
            : p,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final parts = _withPendingStock(data.parts);
    final q = _query.toLowerCase();
    final filtered = parts
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.code.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            p.brand.toLowerCase().contains(q))
        .toList();

    final totalValue = parts.fold<double>(0, (s, p) => s + p.price * p.stock);
    final lowStockParts = parts
        .where((p) => p.stock <= 5 && p.stock > 0)
        .toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    final outStockParts = parts.where((p) => p.stock == 0).toList();
    final lowStock = lowStockParts.length;
    final outStock = outStockParts.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            icon: Icons.inventory_2_outlined,
            title: 'Gerenciamento de Peças',
            subtitle: 'Controle completo do seu estoque de peças',
          ),
          const SizedBox(height: 32),
          _statsGrid([
            StatCard(label: 'Total de Peças', value: '${parts.length}'),
            StatCard(
                label: 'Valor em Estoque', value: formatCurrency(totalValue)),
            StatCard(
                label: 'Estoque Baixo',
                value: '$lowStock',
                valueColor: AppColors.yellow600),
            StatCard(
                label: 'Sem Estoque',
                value: '$outStock',
                valueColor: AppColors.destructive),
          ]),
          if (lowStockParts.isNotEmpty || outStockParts.isNotEmpty) ...[
            const SizedBox(height: 24),
            _StockAlertsPanel(
              lowStockParts: lowStockParts,
              outStockParts: outStockParts,
              onEdit: (p) => _openForm(editing: p),
              onAdjustStock: _adjustStock,
            ),
          ],
          const SizedBox(height: 24),
          _actionsBar(
            hint: 'Buscar por nome, código, categoria ou marca...',
            onChanged: (v) => setState(() => _query = v),
            buttonLabel: 'Nova Peça',
            onAdd: () => _openForm(),
          ),
          const SizedBox(height: 24),
          _PartsTable(
            parts: filtered,
            onEdit: (p) => _openForm(editing: p),
            onAdjustStock: _adjustStock,
            onDelete: (id) async {
              final data = context.read<DataProvider>();
              final ok = await runGuarded(context, () => data.deletePart(id));
              if (ok && mounted) _toast('Peça removida com sucesso!');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openForm({MotorcyclePart? editing}) async {
    final result = await showAppDialog<MotorcyclePart>(
      context: context,
      builder: (_) => _PartFormDialog(editing: editing),
    );
    if (result == null || !mounted) return;
    final data = context.read<DataProvider>();
    if (editing != null) {
      final ok = await runGuarded(context, () => data.updatePart(result));
      if (ok && mounted) _toast('Peça atualizada com sucesso!');
    } else {
      final ok = await runGuarded(context, () => data.addPart(result));
      if (ok && mounted) _toast('Peça adicionada com sucesso!');
    }
  }

  /// Ajusta o estoque em +1/-1 direto da lista, sem abrir o formulário de
  /// edição. Atualiza o número na tela na hora (otimista) em vez de esperar
  /// a ida-e-volta com o Firestore — sem isso, cada clique levava ~1s pra
  /// refletir, porque a tela só reagia quando o listener em tempo real
  /// recebia a confirmação de volta do servidor. Sem toast de sucesso (evita
  /// spam ao clicar várias vezes seguidas) — só avisa em caso de falha.
  Future<void> _adjustStock(MotorcyclePart part, int delta) async {
    final newStock = part.stock + delta;
    if (newStock < 0) return;
    setState(() => _pendingStock[part.id] = newStock);
    final data = context.read<DataProvider>();
    final ok = await runGuarded(
        context, () => data.updatePart(part.copyWith(stock: newStock)));
    if (!ok && mounted) {
      setState(() => _pendingStock.remove(part.id));
    }
  }
}

/// Painel de alertas de estoque: transforma os cards "Estoque Baixo" e "Sem
/// Estoque" em algo acionável, listando quais peças são e permitindo editar
/// o estoque delas direto daqui, sem precisar procurar na tabela.
class _StockAlertsPanel extends StatelessWidget {
  const _StockAlertsPanel({
    required this.lowStockParts,
    required this.outStockParts,
    required this.onEdit,
    required this.onAdjustStock,
  });

  final List<MotorcyclePart> lowStockParts;
  final List<MotorcyclePart> outStockParts;
  final void Function(MotorcyclePart) onEdit;
  final void Function(MotorcyclePart, int) onAdjustStock;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 768;
      final panels = [
        if (outStockParts.isNotEmpty)
          _alertCard(
            icon: Icons.remove_shopping_cart_outlined,
            color: AppColors.destructive,
            title: 'Sem estoque',
            subtitle: '${outStockParts.length} '
                '${outStockParts.length == 1 ? 'peça precisa' : 'peças precisam'} '
                'de reposição urgente',
            parts: outStockParts,
          ),
        if (lowStockParts.isNotEmpty)
          _alertCard(
            icon: Icons.warning_amber_outlined,
            color: AppColors.yellow600,
            title: 'Estoque baixo',
            subtitle: '${lowStockParts.length} '
                '${lowStockParts.length == 1 ? 'peça está' : 'peças estão'} '
                'com 5 unidades ou menos',
            parts: lowStockParts,
          ),
      ];
      if (wide && panels.length == 2) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: panels[0]),
            const SizedBox(width: 16),
            Expanded(child: panels[1]),
          ],
        );
      }
      return Column(
        children: [
          for (var i = 0; i < panels.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            panels[i],
          ],
        ],
      );
    });
  }

  Widget _alertCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<MotorcyclePart> parts,
  }) {
    // Evita um card gigante quando há muitas peças na mesma situação.
    const maxVisible = 4;
    final visible = parts.take(maxVisible).toList();
    final remaining = parts.length - visible.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color)),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.mutedForeground)),
          const SizedBox(height: 12),
          for (final p in visible) _alertRow(p, color),
          if (remaining > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+ $remaining outra${remaining == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground)),
            ),
        ],
      ),
    );
  }

  Widget _alertRow(MotorcyclePart p, Color color) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => onEdit(p),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  Text('${p.code} · ${p.category}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.mutedForeground)),
                ],
              ),
            ),
          ),
        ),
        _miniStepButton(
          icon: Icons.remove_circle_outline,
          onPressed: p.stock > 0 ? () => onAdjustStock(p, -1) : null,
        ),
        SizedBox(
          width: 28,
          child: Text('${p.stock}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ),
        _miniStepButton(
          icon: Icons.add_circle_outline,
          onPressed: () => onAdjustStock(p, 1),
        ),
      ],
    );
  }

  Widget _miniStepButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 16),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(2),
      onPressed: onPressed,
    );
  }
}

Widget _statsGrid(List<Widget> cards) {
  return LayoutBuilder(builder: (context, c) {
    final cols = c.maxWidth >= 768 ? 4 : 1;
    const spacing = 16.0;
    final width = (c.maxWidth - spacing * (cols - 1)) / cols;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final card in cards) SizedBox(width: width, child: card),
      ],
    );
  });
}

Widget _actionsBar({
  required String hint,
  required ValueChanged<String> onChanged,
  required String buttonLabel,
  required VoidCallback onAdd,
}) {
  return LayoutBuilder(builder: (context, c) {
    final field = TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 18),
      ),
    );
    final button = ElevatedButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add, size: 18),
      label: Text(buttonLabel),
    );
    if (c.maxWidth < 640) {
      return Column(children: [
        field,
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: button)
      ]);
    }
    return Row(children: [
      Expanded(child: field),
      const SizedBox(width: 16),
      button,
    ]);
  });
}

class _PartsTable extends StatelessWidget {
  const _PartsTable({
    required this.parts,
    required this.onEdit,
    required this.onDelete,
    required this.onAdjustStock,
  });
  final List<MotorcyclePart> parts;
  final void Function(MotorcyclePart) onEdit;
  final void Function(String) onDelete;
  final void Function(MotorcyclePart, int) onAdjustStock;

  static const _headerStyle = TextStyle(
      fontSize: AppTableStyle.headerFontSize,
      fontWeight: FontWeight.w600,
      color: AppColors.foreground);
  static const _cellStyle = TextStyle(
      fontSize: AppTableStyle.cellFontSize, color: AppColors.foreground);
  static const _cellPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 14);
  static const _rowDivider = BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)));

  Widget _actionButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(6),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) {
      return const _EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Nenhuma peça cadastrada',
        subtitle: 'Adicione sua primeira peça usando o botão acima',
      );
    }

    const minWidth = 960.0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, constraints) {
        final width =
            constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: DefaultTextStyle.merge(
              style: _cellStyle,
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(0.5),
                  4: FlexColumnWidth(0.8),
                  5: FlexColumnWidth(1.3),
                  6: FlexColumnWidth(1),
                  7: FlexColumnWidth(1.1),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  const TableRow(
                    decoration: _rowDivider,
                    children: [
                      _HeaderCell('Código'),
                      _HeaderCell('Nome'),
                      _HeaderCell('Categoria'),
                      _HeaderCell('Marca'),
                      _HeaderCell('Preço', alignEnd: true),
                      _HeaderCell('Estoque', center: true),
                      _HeaderCell('Cadastrado por'),
                      _HeaderCell('Ações'),
                    ],
                  ),
                  for (final p in parts)
                    TableRow(
                      decoration: _rowDivider,
                      children: [
                        Padding(
                          padding: _cellPadding,
                          child: Text(p.code,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'monospace')),
                        ),
                        Padding(
                          padding: _cellPadding,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                        Padding(
                          padding: _cellPadding,
                          child:
                              Text(p.category, overflow: TextOverflow.ellipsis),
                        ),
                        Padding(
                          padding: _cellPadding,
                          child: Text(p.brand, overflow: TextOverflow.ellipsis),
                        ),
                        Padding(
                          padding: _cellPadding,
                          child: Text(formatCurrency(p.price),
                              textAlign: TextAlign.right),
                        ),
                        Padding(
                          padding: _cellPadding,
                          child: Center(
                              child: _StockStepper(
                                  part: p, onAdjust: onAdjustStock)),
                        ),
                        Padding(
                          padding: _cellPadding,
                          child: Tooltip(
                            message:
                                '${p.createdBy.name}\n${p.createdBy.email}\n${formatDateTime(p.createdAt)}',
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.person_outline,
                                  size: 14, color: AppColors.mutedForeground),
                              const SizedBox(width: 6),
                              Flexible(
                                  child: Text(p.createdBy.name,
                                      overflow: TextOverflow.ellipsis)),
                            ]),
                          ),
                        ),
                        Padding(
                          padding: _cellPadding,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            _actionButton(
                                icon: Icons.edit_outlined,
                                onPressed: () => onEdit(p)),
                            _actionButton(
                                icon: Icons.delete_outline,
                                color: AppColors.destructive,
                                onPressed: () => onDelete(p.id)),
                          ]),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {this.alignEnd = false, this.center = false});
  final String label;
  final bool alignEnd;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _PartsTable._cellPadding,
      child: Text(label,
          textAlign: center
              ? TextAlign.center
              : (alignEnd ? TextAlign.right : TextAlign.left),
          style: _PartsTable._headerStyle),
    );
  }
}

/// Badge de estoque com botões +/- ao lado, pra ajustar a quantidade direto
/// na lista (add/remove uma unidade) sem precisar abrir a edição completa.
class _StockStepper extends StatelessWidget {
  const _StockStepper({required this.part, required this.onAdjust});
  final MotorcyclePart part;
  final void Function(MotorcyclePart, int) onAdjust;

  BadgeVariant _variant(int q) {
    if (q == 0) return BadgeVariant.destructive;
    if (q <= 5) return BadgeVariant.warning;
    return BadgeVariant.success;
  }

  Widget _stepButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(4),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepButton(
          icon: Icons.remove_circle_outline,
          tooltip: 'Diminuir 1 unidade',
          onPressed: part.stock > 0 ? () => onAdjust(part, -1) : null,
        ),
        SizedBox(
          width: 64,
          child: Center(
            child: AppBadge(
                label: '${part.stock} un.', variant: _variant(part.stock)),
          ),
        ),
        _stepButton(
          icon: Icons.add_circle_outline,
          tooltip: 'Aumentar 1 unidade',
          onPressed: () => onAdjust(part, 1),
        ),
      ],
    );
  }
}

class _PartFormDialog extends StatefulWidget {
  const _PartFormDialog({this.editing});
  final MotorcyclePart? editing;

  @override
  State<_PartFormDialog> createState() => _PartFormDialogState();
}

class _PartFormDialogState extends State<_PartFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.editing?.code ?? '');
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _brand = TextEditingController(text: widget.editing?.brand ?? '');
  late final _price = TextEditingController(
      text: widget.editing != null
          ? formatCurrencyInput(widget.editing!.price)
          : '');
  late final _stock =
      TextEditingController(text: widget.editing?.stock.toString() ?? '');
  late final _desc =
      TextEditingController(text: widget.editing?.description ?? '');
  late String? _category = widget.editing?.category;

  @override
  void dispose() {
    for (final c in [_code, _name, _brand, _price, _stock, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) return;
    final auth = context.read<AuthProvider>().user!;
    final editing = widget.editing;
    final part = MotorcyclePart(
      id: editing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      code: _code.text,
      name: _name.text,
      category: _category!,
      brand: _brand.text,
      price: parseCurrencyInput(_price.text),
      stock: int.tryParse(_stock.text) ?? 0,
      description: _desc.text.isEmpty ? null : _desc.text,
      barcode: editing?.barcode,
      createdBy: editing?.createdBy ??
          Creator(id: auth.id, name: auth.name, email: auth.email),
      createdAt: editing?.createdAt ?? DateTime.now().toIso8601String(),
    );
    Navigator.of(context).pop(part);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(editing ? 'Editar Peça' : 'Nova Peça'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editing
                      ? 'Atualize as informações da peça'
                      : 'Adicione uma nova peça ao inventário',
                  style: const TextStyle(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: _input(_code, 'Código *', hint: 'Ex: MT-001')),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Categoria *',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _category,
                          isExpanded: true,
                          hint: const Text('Selecione'),
                          items: partCategories
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => _category = v),
                          validator: (v) => v == null ? 'Obrigatório' : null,
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                _input(_name, 'Nome da Peça *',
                    hint: 'Ex: Pastilha de Freio Dianteira'),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _input(_brand, 'Marca *', hint: 'Ex: Honda')),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _input(_price, 'Preço (R\$) *',
                          hint: 'R\$ 0,00',
                          numeric: NumericFieldType.currency)),
                ]),
                const SizedBox(height: 16),
                _input(_stock, 'Quantidade em Estoque *',
                    hint: '0', numeric: NumericFieldType.integer),
                const SizedBox(height: 16),
                _input(_desc, 'Descrição',
                    hint: 'Informações adicionais sobre a peça...',
                    maxLines: 3,
                    required: false),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: _submit,
            child: Text(editing ? 'Atualizar' : 'Adicionar')),
      ],
    );
  }

  Widget _input(TextEditingController c, String label,
      {String? hint,
      NumericFieldType? numeric,
      int maxLines = 1,
      bool required = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: c,
          maxLines: maxLines,
          keyboardType: numeric != null
              ? TextInputType.numberWithOptions(
                  decimal: numeric == NumericFieldType.currency)
              : null,
          inputFormatters: switch (numeric) {
            NumericFieldType.integer => [
                FilteringTextInputFormatter.digitsOnly
              ],
            NumericFieldType.currency => [CurrencyInputFormatter()],
            null => null,
          },
          decoration: InputDecoration(hintText: hint),
          validator: required
              ? (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null
              : null,
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 64, color: AppColors.mutedForeground),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.mutedForeground)),
        ],
      ),
    );
  }
}

// Reaproveitados por outras telas:
Widget statsGridShared(List<Widget> cards) => _statsGrid(cards);
Widget actionsBarShared({
  required String hint,
  required ValueChanged<String> onChanged,
  required String buttonLabel,
  required VoidCallback onAdd,
}) =>
    _actionsBar(
        hint: hint,
        onChanged: onChanged,
        buttonLabel: buttonLabel,
        onAdd: onAdd);
Widget emptyStateShared(
        {required IconData icon,
        required String title,
        required String subtitle}) =>
    _EmptyState(icon: icon, title: title, subtitle: subtitle);
