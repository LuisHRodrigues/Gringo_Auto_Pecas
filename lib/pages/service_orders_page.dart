import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_provider.dart';
import '../services/data_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'parts_management_page.dart'
    show statsGridShared, actionsBarShared, emptyStateShared;

const _statusLabels = {
  'pending': 'Pendente',
  'in-progress': 'Em Andamento',
  'completed': 'Concluída',
  'cancelled': 'Cancelada',
};

Widget statusBadge(String status) {
  switch (status) {
    case 'pending':
      return const AppBadge(label: 'Pendente', variant: BadgeVariant.outline);
    case 'in-progress':
      return const AppBadge(
          label: 'Em Andamento', variant: BadgeVariant.primary);
    case 'completed':
      return const AppBadge(label: 'Concluída', variant: BadgeVariant.success);
    case 'cancelled':
      return const AppBadge(
          label: 'Cancelada', variant: BadgeVariant.destructive);
    default:
      return AppBadge(label: status);
  }
}

/// Decodifica uma foto que pode ser data URL base64 (web) ou caminho de arquivo.
Widget photoImage(String src, {BoxFit fit = BoxFit.cover}) {
  if (src.isEmpty) {
    return const Icon(Icons.broken_image_outlined);
  }
  if (src.startsWith('data:')) {
    final base64Part = src.substring(src.indexOf(',') + 1);
    return Image.memory(base64Decode(base64Part), fit: fit);
  }
  if (src.startsWith('http://') || src.startsWith('https://')) {
    return Image.network(src,
        fit: fit,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined));
  }
  if (!kIsWeb && File(src).existsSync()) {
    return Image.file(File(src), fit: fit);
  }
  return const Icon(Icons.broken_image_outlined);
}

/// Abre a foto em tela cheia, com zoom/pan (pinça ou scroll) e botão de fechar.
void showPhotoViewer(BuildContext context, String src) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // Toque no fundo também fecha o visualizador.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(child: photoImage(src, fit: BoxFit.contain)),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ServiceOrdersPage extends StatefulWidget {
  const ServiceOrdersPage({super.key});

  @override
  State<ServiceOrdersPage> createState() => _ServiceOrdersPageState();
}

class _ServiceOrdersPageState extends State<ServiceOrdersPage> {
  String _query = '';

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final orders = data.orders;
    final q = _query.toLowerCase();
    final filtered = orders
        .where((o) =>
            o.orderNumber.toLowerCase().contains(q) ||
            o.customerName.toLowerCase().contains(q) ||
            o.motorcyclePlate.toLowerCase().contains(q) ||
            o.mechanicName.toLowerCase().contains(q))
        .toList();

    final pending = orders.where((o) => o.status == 'pending').length;
    final inProgress = orders.where((o) => o.status == 'in-progress').length;
    final completed = orders.where((o) => o.status == 'completed').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            icon: Icons.description_outlined,
            title: 'Ordens de Serviço',
            subtitle: 'Gerencie todas as ordens de serviço',
          ),
          const SizedBox(height: 32),
          statsGridShared([
            StatCard(label: 'Total', value: '${orders.length}'),
            StatCard(
                label: 'Pendentes',
                value: '$pending',
                valueColor: AppColors.yellow600),
            StatCard(
                label: 'Em Andamento',
                value: '$inProgress',
                valueColor: AppColors.blue600),
            StatCard(
                label: 'Concluídas',
                value: '$completed',
                valueColor: AppColors.green600),
          ]),
          const SizedBox(height: 24),
          actionsBarShared(
            hint: 'Buscar por número, cliente, placa ou mecânico...',
            onChanged: (v) => setState(() => _query = v),
            buttonLabel: 'Nova Ordem de Serviço',
            onAdd: () => _openForm(),
          ),
          const SizedBox(height: 24),
          if (filtered.isEmpty)
            emptyStateShared(
              icon: Icons.description_outlined,
              title: 'Nenhuma ordem de serviço',
              subtitle: 'Crie sua primeira ordem de serviço',
            )
          else
            _table(filtered),
        ],
      ),
    );
  }

  Widget _table(List<ServiceOrder> orders) {
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
            DataColumn(label: Text('Número OS')),
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('Moto')),
            DataColumn(label: Text('Placa')),
            DataColumn(label: Text('Mecânico')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Fotos')),
            DataColumn(label: Text('Valor Total'), numeric: true),
            DataColumn(label: Text('Data')),
            DataColumn(label: Text('Ações')),
          ],
          rows: orders.map((o) {
            return DataRow(cells: [
              DataCell(Text(o.orderNumber,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 13))),
              DataCell(Text(o.customerName)),
              DataCell(Text('${o.motorcycleBrand} ${o.motorcycleModel}')),
              DataCell(Text(o.motorcyclePlate,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 13))),
              DataCell(Text(o.mechanicName)),
              DataCell(statusBadge(o.status)),
              DataCell(o.photos.isNotEmpty
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.image_outlined,
                          size: 16, color: AppColors.mutedForeground),
                      const SizedBox(width: 4),
                      Text('${o.photos.length}',
                          style: const TextStyle(
                              color: AppColors.mutedForeground)),
                    ])
                  : const Text('-',
                      style: TextStyle(color: AppColors.mutedForeground))),
              DataCell(Text(formatCurrency(o.totalCost),
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(formatDate(o.createdAt),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.mutedForeground))),
              DataCell(Row(children: [
                IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    onPressed: () => _openDetails(o)),
                IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _openForm(editing: o)),
                IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppColors.destructive),
                    onPressed: () async {
                      final data = context.read<DataProvider>();
                      final ok = await runGuarded(
                          context, () => data.deleteOrder(o.id));
                      if (ok && mounted) _toast('Ordem de serviço removida!');
                    }),
              ])),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _openForm({ServiceOrder? editing}) async {
    final result = await showDialog<ServiceOrder>(
      context: context,
      builder: (_) => _OrderFormDialog(editing: editing),
    );
    if (result == null || !mounted) return;
    final data = context.read<DataProvider>();
    if (editing != null) {
      final ok = await runGuarded(context, () => data.updateOrder(result));
      if (ok && mounted) _toast('Ordem de serviço atualizada!');
    } else {
      final ok = await runGuarded(context, () => data.addOrder(result));
      if (ok && mounted) _toast('Ordem de serviço criada!');
    }
  }

  void _openDetails(ServiceOrder o) {
    showDialog(context: context, builder: (_) => _OrderDetailsDialog(order: o));
  }
}

// ---------------- Formulário ----------------
class _OrderFormDialog extends StatefulWidget {
  const _OrderFormDialog({this.editing});
  final ServiceOrder? editing;

  @override
  State<_OrderFormDialog> createState() => _OrderFormDialogState();
}

class _OrderFormDialogState extends State<_OrderFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _orderNumber = TextEditingController(
      text: widget.editing?.orderNumber ??
          'OS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  late final _customerName =
      TextEditingController(text: widget.editing?.customerName ?? '');
  late final _customerPhone =
      TextEditingController(text: widget.editing?.customerPhone ?? '');
  late final _brand =
      TextEditingController(text: widget.editing?.motorcycleBrand ?? '');
  late final _model =
      TextEditingController(text: widget.editing?.motorcycleModel ?? '');
  late final _plate =
      TextEditingController(text: widget.editing?.motorcyclePlate ?? '');
  late final _problem =
      TextEditingController(text: widget.editing?.problem ?? '');
  late String? _mechanicId = widget.editing?.mechanicId;
  late final _labor =
      TextEditingController(text: widget.editing?.laborCost.toString() ?? '0');
  late final _total =
      TextEditingController(text: widget.editing?.totalCost.toString() ?? '0');
  late String _status = widget.editing?.status ?? 'pending';
  late List<String> _photos = List.of(widget.editing?.photos ?? const []);

  final _picker = ImagePicker();

  @override
  void dispose() {
    for (final c in [
      _orderNumber,
      _customerName,
      _customerPhone,
      _brand,
      _model,
      _plate,
      _problem,
      _labor,
      _total
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= 3) {
      _snack('Você pode adicionar no máximo 3 fotos');
      return;
    }
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    String value;
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      value = 'data:image/png;base64,${base64Encode(bytes)}';
    } else {
      value = picked.path;
    }
    setState(() => _photos = [..._photos, value]);
    _snack('1 foto adicionada');
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>().user!;
    final editing = widget.editing;
    // Resolve o nome do mecânico a partir do funcionário selecionado.
    String mechanicName = editing?.mechanicName ?? '';
    for (final e in context.read<DataProvider>().employees) {
      if (e.id == _mechanicId) {
        mechanicName = e.name;
        break;
      }
    }
    final order = ServiceOrder(
      id: editing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      orderNumber: _orderNumber.text,
      customerName: _customerName.text,
      customerPhone: _customerPhone.text,
      motorcycleBrand: _brand.text,
      motorcycleModel: _model.text,
      motorcyclePlate: _plate.text,
      problem: _problem.text,
      status: _status,
      mechanicId: _mechanicId ?? '',
      mechanicName: mechanicName,
      photos: _photos,
      partsUsed: editing?.partsUsed ?? const [],
      laborCost: double.tryParse(_labor.text.replaceAll(',', '.')) ?? 0,
      totalCost: double.tryParse(_total.text.replaceAll(',', '.')) ?? 0,
      createdBy: editing?.createdBy ??
          Creator(id: auth.id, name: auth.name, email: auth.email),
      createdAt: editing?.createdAt ?? DateTime.now().toIso8601String(),
      completedAt: _status == 'completed'
          ? (editing?.completedAt ?? DateTime.now().toIso8601String())
          : null,
    );
    Navigator.of(context).pop(order);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    return AlertDialog(
      backgroundColor: AppColors.card,
      title:
          Text(editing ? 'Editar Ordem de Serviço' : 'Nova Ordem de Serviço'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: _input(_orderNumber, 'Número da OS *',
                          enabled: false)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _dropdown(
                    'Status *',
                    _status,
                    _statusLabels,
                    (v) => setState(() => _status = v!),
                  )),
                ]),
                _section('Dados do Cliente'),
                _input(_customerName, 'Nome do Cliente *',
                    hint: 'Nome completo'),
                const SizedBox(height: 16),
                _input(_customerPhone, 'Telefone *', hint: '(00) 00000-0000'),
                _section('Dados da Moto'),
                Row(children: [
                  Expanded(child: _input(_brand, 'Marca *', hint: 'Ex: Honda')),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _input(_model, 'Modelo *', hint: 'Ex: CB 500')),
                ]),
                const SizedBox(height: 16),
                _input(_plate, 'Placa *', hint: 'ABC-1234'),
                _section('Fotos da Moto (Estado de Chegada)'),
                _photosGrid(),
                _section('Serviço'),
                _input(_problem, 'Descrição do Problema *',
                    hint: 'Descreva o problema relatado pelo cliente...',
                    maxLines: 3),
                const SizedBox(height: 16),
                _mechanicField(),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child:
                          _input(_labor, 'Mão de Obra (R\$) *', number: true)),
                  const SizedBox(width: 16),
                  Expanded(
                      child:
                          _input(_total, 'Valor Total (R\$) *', number: true)),
                ]),
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
            onPressed: _submit, child: Text(editing ? 'Atualizar' : 'Criar')),
      ],
    );
  }

  Widget _photosGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < _photos.length; i++)
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: photoImage(_photos[i]),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _photos = [..._photos]..removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.destructive,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_photos.length < 3)
              InkWell(
                onTap: _pickPhoto,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.muted.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.mutedForeground.withOpacity(0.25),
                      style: BorderStyle.solid,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.upload_outlined,
                          color: AppColors.mutedForeground),
                      const SizedBox(height: 4),
                      Text('${3 - _photos.length} restante(s)',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.mutedForeground)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Você pode adicionar até 3 fotos (máx. 5MB cada)',
            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
      ],
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  /// Dropdown com os mecânicos ativos cadastrados (cargo "Mecânico" +
  /// status "Ativo"), no lugar do antigo campo de texto livre.
  Widget _mechanicField() {
    final mechanics = context
        .watch<DataProvider>()
        .employees
        .where((e) => e.role == 'mechanic' && e.status == 'active')
        .toList();

    final items = <DropdownMenuItem<String>>[
      for (final m in mechanics)
        DropdownMenuItem(value: m.id, child: Text(m.name)),
    ];
    // Garante que o mecânico já vinculado à OS continue visível mesmo que
    // tenha ficado inativo ou sido removido depois da criação.
    if (_mechanicId != null && !mechanics.any((m) => m.id == _mechanicId)) {
      final legacyName = widget.editing?.mechanicName.isNotEmpty == true
          ? widget.editing!.mechanicName
          : 'Mecânico';
      items.insert(
        0,
        DropdownMenuItem(
          value: _mechanicId,
          child: Text('$legacyName (indisponível)'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mecânico Responsável *',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _mechanicId,
          isExpanded: true,
          hint: Text(mechanics.isEmpty
              ? 'Nenhum mecânico ativo cadastrado'
              : 'Selecione o mecânico'),
          items: items,
          onChanged: (v) => setState(() => _mechanicId = v),
          validator: (v) => (v == null || v.isEmpty)
              ? 'Selecione o mecânico responsável'
              : null,
        ),
        if (mechanics.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Cadastre um funcionário com cargo "Mecânico" e status "Ativo" '
              'na aba Funcionários para poder selecioná-lo aqui.',
              style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
            ),
          ),
      ],
    );
  }

  Widget _input(TextEditingController c, String label,
      {String? hint,
      bool number = false,
      int maxLines = 1,
      bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: c,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          decoration: InputDecoration(hintText: hint),
          validator: enabled
              ? (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null
              : null,
        ),
      ],
    );
  }

  Widget _dropdown(String label, String value, Map<String, String> items,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          items: items.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ---------------- Detalhes ----------------
class _OrderDetailsDialog extends StatelessWidget {
  const _OrderDetailsDialog({required this.order});
  final ServiceOrder order;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text('Ordem de Serviço ${order.orderNumber}')),
          statusBadge(order.status),
        ],
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Criada em ${formatDateTime(order.createdAt)}',
                  style: const TextStyle(color: AppColors.mutedForeground)),
              const SizedBox(height: 20),
              _block('Cliente', [
                _kv('Nome', order.customerName),
                _kv('Telefone', order.customerPhone),
              ]),
              _divider(),
              _block('Motocicleta', [
                _kv('Marca', order.motorcycleBrand),
                _kv('Modelo', order.motorcycleModel),
                _kv('Placa', order.motorcyclePlate),
              ]),
              if (order.photos.isNotEmpty) ...[
                _divider(),
                const Text('Fotos do Estado de Chegada',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: order.photos
                      .map((p) => SizedBox(
                            width: 120,
                            height: 120,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => showPhotoViewer(context, p),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      photoImage(p),
                                      Positioned(
                                        right: 4,
                                        bottom: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.45),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Icon(Icons.zoom_in,
                                              size: 16, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
              _divider(),
              const Text('Serviço',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _kvCol('Problema Relatado', order.problem),
              const SizedBox(height: 8),
              _kvCol('Mecânico Responsável', order.mechanicName),
              _divider(),
              const Text('Valores',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mão de Obra',
                      style: TextStyle(color: AppColors.mutedForeground)),
                  Text(formatCurrency(order.laborCost),
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text(formatCurrency(order.totalCost),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ],
              ),
              _divider(),
              Text('Cadastrado por: ${order.createdBy.name}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground)),
              Text('Email: ${order.createdBy.email}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedForeground)),
              if (order.completedAt != null)
                Text('Concluída em: ${formatDateTime(order.completedAt!)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.mutedForeground)),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar')),
      ],
    );
  }

  Widget _divider() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 16), child: Divider());

  Widget _block(String title, List<Widget> kvs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(spacing: 32, runSpacing: 12, children: kvs),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(k,
            style: const TextStyle(
                fontSize: 13, color: AppColors.mutedForeground)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _kvCol(String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k,
            style: const TextStyle(
                fontSize: 13, color: AppColors.mutedForeground)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
