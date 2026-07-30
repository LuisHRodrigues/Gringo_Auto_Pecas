import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_provider.dart';
import '../services/data_provider.dart';
import '../theme/app_theme.dart';
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

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final parts = data.parts;
    final q = _query.toLowerCase();
    final filtered = parts
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.code.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            p.brand.toLowerCase().contains(q))
        .toList();

    final totalValue = parts.fold<double>(0, (s, p) => s + p.price * p.stock);
    final lowStock = parts.where((p) => p.stock <= 5 && p.stock > 0).length;
    final outStock = parts.where((p) => p.stock == 0).length;

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
    final result = await showDialog<MotorcyclePart>(
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
}

Widget _statsGrid(List<Widget> cards) {
  return LayoutBuilder(builder: (context, c) {
    final cols = c.maxWidth >= 768 ? 4 : 1;
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: cols == 4 ? 2.2 : 4.5,
      children: cards,
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
  const _PartsTable(
      {required this.parts, required this.onEdit, required this.onDelete});
  final List<MotorcyclePart> parts;
  final void Function(MotorcyclePart) onEdit;
  final void Function(String) onDelete;

  BadgeVariant _stockVariant(int q) {
    if (q == 0) return BadgeVariant.destructive;
    if (q <= 5) return BadgeVariant.outline;
    return BadgeVariant.primary;
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
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Código')),
            DataColumn(label: Text('Nome')),
            DataColumn(label: Text('Categoria')),
            DataColumn(label: Text('Marca')),
            DataColumn(label: Text('Preço'), numeric: true),
            DataColumn(label: Text('Estoque')),
            DataColumn(label: Text('Cadastrado por')),
            DataColumn(label: Text('Ações')),
          ],
          rows: parts.map((p) {
            return DataRow(cells: [
              DataCell(Text(p.code,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 13))),
              DataCell(Text(p.name)),
              DataCell(Text(p.category)),
              DataCell(Text(p.brand)),
              DataCell(Text(formatCurrency(p.price))),
              DataCell(AppBadge(
                  label: '${p.stock} un.', variant: _stockVariant(p.stock))),
              DataCell(Tooltip(
                message:
                    '${p.createdBy.name}\n${p.createdBy.email}\n${formatDateTime(p.createdAt)}',
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.person_outline,
                      size: 14, color: AppColors.mutedForeground),
                  const SizedBox(width: 6),
                  Text(p.createdBy.name, style: const TextStyle(fontSize: 13)),
                ]),
              )),
              DataCell(Row(children: [
                IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => onEdit(p)),
                IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppColors.destructive),
                    onPressed: () => onDelete(p.id)),
              ])),
            ]);
          }).toList(),
        ),
      ),
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
  late final _price =
      TextEditingController(text: widget.editing?.price.toString() ?? '');
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
      price: double.tryParse(_price.text.replaceAll(',', '.')) ?? 0,
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
                          hint: '0.00', number: true)),
                ]),
                const SizedBox(height: 16),
                _input(_stock, 'Quantidade em Estoque *',
                    hint: '0', number: true),
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
      bool number = false,
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
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
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
