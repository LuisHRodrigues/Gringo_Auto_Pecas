import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_provider.dart';
import '../services/data_provider.dart';
import '../theme/app_theme.dart';
import '../utils/input_formatters.dart';
import '../widgets/common.dart';
import 'parts_management_page.dart'
    show statsGridShared, actionsBarShared, emptyStateShared;

const _roleLabels = {
  'mechanic': 'Mecânico',
  'attendant': 'Atendente',
  'manager': 'Gerente',
  'cashier': 'Caixa',
};

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  String _query = '';

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final employees = data.employees;
    final q = _query.toLowerCase();
    final filtered = employees
        .where((e) =>
            e.name.toLowerCase().contains(q) ||
            e.cpf.contains(q) ||
            e.email.toLowerCase().contains(q) ||
            e.phone.contains(q))
        .toList();

    final active = employees.where((e) => e.status == 'active').length;
    final mechanics = employees
        .where((e) => e.role == 'mechanic' && e.status == 'active')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            icon: Icons.people_outline,
            title: 'Funcionários',
            subtitle: 'Gerencie sua equipe de trabalho',
          ),
          const SizedBox(height: 32),
          statsGridShared([
            StatCard(label: 'Total', value: '${employees.length}'),
            StatCard(
                label: 'Ativos',
                value: '$active',
                valueColor: AppColors.green600),
            StatCard(
                label: 'Mecânicos',
                value: '$mechanics',
                valueColor: AppColors.blue600),
            StatCard(
                label: 'Inativos',
                value: '${employees.length - active}',
                valueColor: AppColors.mutedForeground),
          ]),
          const SizedBox(height: 24),
          actionsBarShared(
            hint: 'Buscar por nome, CPF, email ou telefone...',
            onChanged: (v) => setState(() => _query = v),
            buttonLabel: 'Novo Funcionário',
            onAdd: () => _openForm(),
          ),
          const SizedBox(height: 24),
          if (filtered.isEmpty)
            emptyStateShared(
              icon: Icons.people_outline,
              title: 'Nenhum funcionário cadastrado',
              subtitle: 'Cadastre seu primeiro funcionário',
            )
          else
            _table(filtered),
        ],
      ),
    );
  }

  Widget _table(List<Employee> employees) {
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
            DataColumn(label: Text('Nome')),
            DataColumn(label: Text('CPF')),
            DataColumn(label: Text('Cargo')),
            DataColumn(label: Text('Telefone')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Admissão')),
            DataColumn(label: Text('Salário'), numeric: true),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Ações')),
          ],
          rows: employees.map((e) {
            return DataRow(cells: [
              DataCell(Text(e.name,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
              DataCell(Text(e.cpf,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 13))),
              DataCell(Text(_roleLabels[e.role] ?? e.role)),
              DataCell(Text(e.phone)),
              DataCell(Text(e.email, style: const TextStyle(fontSize: 13))),
              DataCell(Text(formatDate(e.hireDate),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.mutedForeground))),
              DataCell(Text(formatCurrency(e.salary),
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(e.status == 'active'
                  ? const AppBadge(
                      label: 'Ativo', variant: BadgeVariant.success)
                  : const AppBadge(
                      label: 'Inativo', variant: BadgeVariant.outline)),
              DataCell(Row(children: [
                IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _openForm(editing: e)),
                IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppColors.destructive),
                    onPressed: () async {
                      final data = context.read<DataProvider>();
                      final ok = await runGuarded(
                          context, () => data.deleteEmployee(e.id));
                      if (ok && mounted) _toast('Funcionário removido!');
                    }),
              ])),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _openForm({Employee? editing}) async {
    final result = await showAppDialog<Employee>(
      context: context,
      builder: (_) => _EmployeeFormDialog(editing: editing),
    );
    if (result == null || !mounted) return;
    final data = context.read<DataProvider>();
    if (editing != null) {
      final ok = await runGuarded(context, () => data.updateEmployee(result));
      if (ok && mounted) _toast('Funcionário atualizado!');
    } else {
      final ok = await runGuarded(context, () => data.addEmployee(result));
      if (ok && mounted) _toast('Funcionário cadastrado!');
    }
  }
}

class _EmployeeFormDialog extends StatefulWidget {
  const _EmployeeFormDialog({this.editing});
  final Employee? editing;

  @override
  State<_EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<_EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _cpf = TextEditingController(text: widget.editing?.cpf ?? '');
  late final _phone = TextEditingController(text: widget.editing?.phone ?? '');
  late final _email = TextEditingController(text: widget.editing?.email ?? '');
  late final _salary = TextEditingController(
      text: widget.editing != null
          ? formatCurrencyInput(widget.editing!.salary)
          : '');
  late String _role = widget.editing?.role ?? 'mechanic';
  late String _status = widget.editing?.status ?? 'active';
  late DateTime _hireDate = widget.editing != null
      ? DateTime.parse(widget.editing!.hireDate)
      : DateTime.now();

  @override
  void dispose() {
    for (final c in [_name, _cpf, _phone, _email, _salary]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>().user!;
    final editing = widget.editing;
    final e = Employee(
      id: editing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.text,
      cpf: _cpf.text,
      role: _role,
      phone: _phone.text,
      email: _email.text,
      hireDate: _hireDate.toIso8601String().split('T').first,
      salary: parseCurrencyInput(_salary.text),
      status: _status,
      createdBy: editing?.createdBy ??
          Creator(id: auth.id, name: auth.name, email: auth.email),
      createdAt: editing?.createdAt ?? DateTime.now().toIso8601String(),
    );
    Navigator.of(context).pop(e);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(editing ? 'Editar Funcionário' : 'Novo Funcionário'),
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
                        ? 'Atualize as informações do funcionário'
                        : 'Cadastre um novo funcionário',
                    style: const TextStyle(color: AppColors.mutedForeground)),
                const SizedBox(height: 16),
                _input(_name, 'Nome Completo *',
                    hint: 'Nome completo do funcionário'),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: _input(_cpf, 'CPF *',
                          hint: '000.000.000-00',
                          formatters: [cpfInputFormatter])),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _dropdown(
                    label: 'Cargo *',
                    value: _role,
                    items: _roleLabels,
                    onChanged: (v) => setState(() => _role = v!),
                  )),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: _input(_phone, 'Telefone *',
                          hint: '(00) 00000-0000',
                          formatters: [phoneInputFormatter])),
                  const SizedBox(width: 16),
                  Expanded(
                      child:
                          _input(_email, 'Email *', hint: 'email@exemplo.com')),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _dateField()),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _input(_salary, 'Salário (R\$) *',
                          hint: 'R\$ 0,00',
                          numeric: NumericFieldType.currency)),
                ]),
                const SizedBox(height: 16),
                _dropdown(
                  label: 'Status *',
                  value: _status,
                  items: const {'active': 'Ativo', 'inactive': 'Inativo'},
                  onChanged: (v) => setState(() => _status = v!),
                ),
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
            child: Text(editing ? 'Atualizar' : 'Cadastrar')),
      ],
    );
  }

  Widget _input(TextEditingController c, String label,
      {String? hint,
      NumericFieldType? numeric,
      List<TextInputFormatter>? formatters}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: c,
          keyboardType: numeric != null
              ? TextInputType.numberWithOptions(
                  decimal: numeric == NumericFieldType.currency)
              : (formatters != null ? TextInputType.phone : null),
          inputFormatters: formatters ??
              switch (numeric) {
                NumericFieldType.integer => [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                NumericFieldType.currency => [CurrencyInputFormatter()],
                null => null,
              },
          decoration: InputDecoration(hintText: hint),
          validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
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

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Data de Admissão *',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _hireDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => _hireDate = picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(),
            child: Text(formatDate(_hireDate.toIso8601String())),
          ),
        ),
      ],
    );
  }
}
