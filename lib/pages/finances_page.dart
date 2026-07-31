import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/data_provider.dart';
import '../theme/app_theme.dart';
import '../utils/input_formatters.dart';
import '../widgets/common.dart';

/// Porte de src/app/pages/finances.tsx.
/// Controle financeiro: lojas, seletor de mês, adicionar transação,
/// cards de resumo, gráficos (evolução mensal, lucro, receitas/despesas
/// por categoria) e tabela de transações recentes.
class FinancesPage extends StatefulWidget {
  const FinancesPage({super.key});

  @override
  State<FinancesPage> createState() => _FinancesPageState();
}

class _FinancesPageState extends State<FinancesPage> {
  String _selectedMonth = _ymOf(DateTime.now());
  String _activeStore = 'motogest';
  List<Transaction> _transactions = [];

  static const _monthNames = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  static const _monthAbbr = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];

  /// Rótulo curto para os gráficos (ex.: '2026-06' -> 'Jun/26').
  String _shortLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    final m = int.tryParse(parts[1]) ?? 0;
    if (m < 1 || m > 12) return ym;
    final yy = parts[0].length >= 2
        ? parts[0].substring(parts[0].length - 2)
        : parts[0];
    return '${_monthAbbr[m - 1]}/$yy';
  }

  /// Agrega as transações por mês para os gráficos de evolução/lucro.
  /// Considera os meses que possuem transações (até os 6 mais recentes),
  /// em ordem crescente. Reflete dados reais, incluindo as receitas geradas
  /// por OS concluídas.
  List<_MonthPoint> _monthlyAggregates() {
    final entradas = <String, double>{};
    final saidas = <String, double>{};
    final monthsSet = <String>{};
    for (final t in _transactions) {
      monthsSet.add(t.month);
      if (t.type == 'entrada') {
        entradas[t.month] = (entradas[t.month] ?? 0) + t.amount;
      } else {
        saidas[t.month] = (saidas[t.month] ?? 0) + t.amount;
      }
    }
    var months = monthsSet.toList()..sort();
    if (months.isEmpty) months = [_ymOf(DateTime.now())];
    if (months.length > 6) months = months.sublist(months.length - 6);
    return [
      for (final ym in months)
        _MonthPoint(
          _shortLabel(ym),
          entradas[ym] ?? 0,
          saidas[ym] ?? 0,
          (entradas[ym] ?? 0) - (saidas[ym] ?? 0),
        ),
    ];
  }

  static String _ymOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  String _monthLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    final m = int.tryParse(parts[1]) ?? 0;
    if (m < 1 || m > 12) return ym;
    return '${_monthNames[m - 1]} ${parts[0]}';
  }

  /// Meses disponíveis para seleção: o mês atual + todos os meses que possuem
  /// transações (inclusive as receitas geradas por OS concluídas), em ordem
  /// decrescente. Assim qualquer OS concluída aparece no seletor.
  List<_MonthOption> _availableMonths() {
    final set = <String>{_ymOf(DateTime.now())};
    for (final t in _transactions) {
      set.add(t.month);
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return [for (final ym in list) _MonthOption(ym, _monthLabel(ym))];
  }

  // As transações são lidas de forma reativa do DataProvider em [build];
  // este método apenas força um rebuild quando a loja ativa muda.
  void _reloadTransactions() => setState(() {});

  List<Transaction> get _filtered =>
      _transactions.where((t) => t.month == _selectedMonth).toList();

  double get _totalEntradas => _filtered
      .where((t) => t.type == 'entrada')
      .fold(0.0, (a, t) => a + t.amount);

  double get _totalSaidas => _filtered
      .where((t) => t.type == 'saida')
      .fold(0.0, (a, t) => a + t.amount);

  double get _lucro => _totalEntradas - _totalSaidas;

  double get _margem =>
      _totalEntradas > 0 ? (_lucro / _totalEntradas) * 100 : 0;

  List<_CatValue> _byCategory(String type) {
    final map = <String, double>{};
    for (final t in _filtered.where((t) => t.type == type)) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map.entries.map((e) => _CatValue(e.key, e.value)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    // Leitura reativa: recalcula sempre que o Firestore emitir novos dados.
    _transactions = data.transactionsOf(_activeStore);
    final months = _availableMonths();
    // Garante que o mês selecionado exista na lista (ex.: ao trocar de loja
    // ou logo após uma OS ser concluída em um novo mês).
    if (!months.any((m) => m.value == _selectedMonth)) {
      _selectedMonth = months.first.value;
    }
    final stores = data.stores;
    BusinessStore? currentStore;
    for (final s in stores) {
      if (s.id == _activeStore) {
        currentStore = s;
        break;
      }
    }
    final isWide = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com ações
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              const PageHeader(
                icon: Icons.attach_money,
                title: 'Finanças',
                subtitle: 'Controle financeiro da oficina',
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openAddTransaction,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar Transação'),
                  ),
                  const SizedBox(width: 8),
                  _MonthDropdown(
                    value: _selectedMonth,
                    months: months,
                    onChanged: (v) => setState(() => _selectedMonth = v),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Minhas lojas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Minhas Lojas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openCategories,
                    icon: const Icon(Icons.sell_outlined, size: 16),
                    label: const Text('Categorias'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openAddStore,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Adicionar Loja'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StoreCards(
            stores: stores,
            activeStore: _activeStore,
            onSelect: (id) {
              setState(() => _activeStore = id);
              _reloadTransactions();
            },
            onDelete: (id) async {
              final data = context.read<DataProvider>();
              final ok = await runGuarded(context, () => data.deleteStore(id));
              if (!ok || !mounted) return;
              if (_activeStore == id) {
                setState(() => _activeStore = 'motogest');
              }
              _reloadTransactions();
              _toast('Loja removida com sucesso!');
            },
          ),
          const SizedBox(height: 24),

          // Alerta informativo (apenas loja principal)
          if (_activeStore == 'motogest') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.blue50,
                border: Border.all(color: AppColors.blue200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.refresh, size: 18, color: AppColors.blue600),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'As ordens de serviço com status Concluído são '
                      'automaticamente importadas como entradas financeiras.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Indicador da loja ativa
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.blue50, AppColors.indigo50],
              ),
              border: Border.all(color: AppColors.blue200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                        color: Color(currentStore?.color ?? 0xFF3B82F6),
                        width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.shopping_bag,
                      size: 24,
                      color: Color(currentStore?.color ?? 0xFF3B82F6)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Visualizando',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.mutedForeground)),
                    Text(currentStore?.name ?? '',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Cards de resumo
          _SummaryCards(
            totalEntradas: _totalEntradas,
            totalSaidas: _totalSaidas,
            lucro: _lucro,
            margem: _margem,
            wide: isWide,
          ),
          const SizedBox(height: 24),

          // Gráficos
          _ChartsGrid(
            wide: isWide,
            monthly: _monthlyAggregates(),
            entradas: _byCategory('entrada'),
            saidas: _byCategory('saida'),
          ),
          const SizedBox(height: 24),

          // Transações recentes
          _RecentTransactions(transactions: _filtered),
        ],
      ),
    );
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _openAddTransaction() {
    showAppDialog(
      context: context,
      builder: (_) => _TransactionDialog(
        storeId: _activeStore,
        onSubmit: (t) async {
          final data = context.read<DataProvider>();
          final ok = await runGuarded(
              context, () => data.addTransaction(_activeStore, t));
          if (!ok || !mounted) return;
          _reloadTransactions();
          _toast(
              '${t.type == 'entrada' ? 'Receita' : 'Despesa'} adicionada com sucesso!');
        },
      ),
    );
  }

  void _openCategories() {
    showAppDialog(
      context: context,
      builder: (_) => _CategoryManagerDialog(storeId: _activeStore),
    );
  }

  void _openAddStore() {
    showAppDialog(
      context: context,
      builder: (_) => _StoreDialog(
        onSubmit: (s) async {
          final data = context.read<DataProvider>();
          final ok = await runGuarded(context, () => data.addStore(s));
          if (ok && mounted) _toast('Loja adicionada com sucesso!');
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tipos auxiliares
// ---------------------------------------------------------------------------

class _MonthPoint {
  final String mes;
  final double entradas;
  final double saidas;
  final double lucro;
  const _MonthPoint(this.mes, this.entradas, this.saidas, this.lucro);
}

class _MonthOption {
  final String value;
  final String label;
  const _MonthOption(this.value, this.label);
}

class _CatValue {
  final String name;
  final double value;
  const _CatValue(this.name, this.value);
}

// ---------------------------------------------------------------------------
// Seletor de mês
// ---------------------------------------------------------------------------

class _MonthDropdown extends StatelessWidget {
  const _MonthDropdown(
      {required this.value, required this.months, required this.onChanged});
  final String value;
  final List<_MonthOption> months;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: months
              .map(
                  (m) => DropdownMenuItem(value: m.value, child: Text(m.label)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards de lojas
// ---------------------------------------------------------------------------

class _StoreCards extends StatelessWidget {
  const _StoreCards({
    required this.stores,
    required this.activeStore,
    required this.onSelect,
    required this.onDelete,
  });
  final List<BusinessStore> stores;
  final String activeStore;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cols = width >= 1024 ? 4 : (width >= 640 ? 2 : 1);
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.6,
      children: stores.map((store) {
        final active = store.id == activeStore;
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onSelect(store.id),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? AppColors.primary : AppColors.border,
                width: active ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(store.color).withOpacity(0.125),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.store,
                          size: 20, color: Color(store.color)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(store.type,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.mutedForeground)),
                        ],
                      ),
                    ),
                    if (store.id != 'motogest')
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.destructive),
                        onPressed: () => onDelete(store.id),
                      ),
                  ],
                ),
                if (active) ...[
                  const SizedBox(height: 8),
                  const AppBadge(label: 'Ativo'),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards de resumo
// ---------------------------------------------------------------------------

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({
    required this.totalEntradas,
    required this.totalSaidas,
    required this.lucro,
    required this.margem,
    required this.wide,
  });
  final double totalEntradas;
  final double totalSaidas;
  final double lucro;
  final double margem;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _summaryCard('Total Entradas', formatCurrency(totalEntradas),
          'Receitas do mês', AppColors.green600, Icons.arrow_outward),
      _summaryCard('Total Saídas', formatCurrency(totalSaidas),
          'Despesas do mês', AppColors.red600, Icons.south_east),
      _summaryCard(
          'Balanço do Mês',
          formatCurrency(lucro),
          lucro >= 0 ? 'Lucro' : 'Prejuízo',
          lucro >= 0 ? AppColors.green600 : AppColors.red600,
          lucro >= 0 ? Icons.trending_up : Icons.trending_down),
      _summaryCard(
          'Margem de Lucro',
          '${margem.toStringAsFixed(1)}%',
          'Sobre o faturamento',
          margem >= 0 ? AppColors.green600 : AppColors.red600,
          Icons.calendar_today),
    ];

    return GridView.count(
      crossAxisCount: wide ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.7,
      children: cards,
    );
  }

  Widget _summaryCard(
      String title, String value, String hint, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(hint,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.mutedForeground)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gráficos
// ---------------------------------------------------------------------------

class _ChartsGrid extends StatelessWidget {
  const _ChartsGrid({
    required this.wide,
    required this.monthly,
    required this.entradas,
    required this.saidas,
  });
  final bool wide;
  final List<_MonthPoint> monthly;
  final List<_CatValue> entradas;
  final List<_CatValue> saidas;

  @override
  Widget build(BuildContext context) {
    final charts = [
      _chartCard('Evolução Mensal', _AreaChart(monthly: monthly)),
      _chartCard('Lucro Mensal', _LineChartView(monthly: monthly)),
      _chartCard('Receitas por Categoria', _PieChartView(data: entradas)),
      _chartCard('Despesas por Categoria', _BarChartView(data: saidas)),
    ];

    if (!wide) {
      return Column(
        children: [
          for (final c in charts) ...[c, const SizedBox(height: 16)],
        ],
      );
    }
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: charts[0]),
            const SizedBox(width: 16),
            Expanded(child: charts[1]),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: charts[2]),
            const SizedBox(width: 16),
            Expanded(child: charts[3]),
          ],
        ),
      ],
    );
  }

  Widget _chartCard(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(height: 260, child: chart),
        ],
      ),
    );
  }
}

class _AreaChart extends StatelessWidget {
  const _AreaChart({required this.monthly});
  final List<_MonthPoint> monthly;

  @override
  Widget build(BuildContext context) {
    List<FlSpot> spots(double Function(_MonthPoint) f) => [
          for (int i = 0; i < monthly.length; i++)
            FlSpot(i.toDouble(), f(monthly[i])),
        ];

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: _monthTitles(monthly),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          _areaBar(spots((p) => p.entradas), const Color(0xFF10B981)),
          _areaBar(spots((p) => p.saidas), const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  LineChartBarData _areaBar(List<FlSpot> spots, Color color) =>
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: color.withOpacity(0.3)),
      );
}

class _LineChartView extends StatelessWidget {
  const _LineChartView({required this.monthly});
  final List<_MonthPoint> monthly;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: _monthTitles(monthly),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (int i = 0; i < monthly.length; i++)
                FlSpot(i.toDouble(), monthly[i].lucro),
            ],
            isCurved: true,
            color: const Color(0xFF8B5CF6),
            barWidth: 2,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}

FlTitlesData _monthTitles(List<_MonthPoint> monthly) => FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: true, reservedSize: 44),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= monthly.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(monthly[i].mes, style: const TextStyle(fontSize: 11)),
            );
          },
        ),
      ),
    );

class _PieChartView extends StatelessWidget {
  const _PieChartView({required this.data});
  final List<_CatValue> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text('Sem dados no período',
            style: TextStyle(color: AppColors.mutedForeground)),
      );
    }
    final total = data.fold(0.0, (a, d) => a + d.value);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 0,
              sectionsSpace: 2,
              sections: [
                for (int i = 0; i < data.length; i++)
                  PieChartSectionData(
                    value: data[i].value,
                    title:
                        '${(data[i].value / total * 100).toStringAsFixed(0)}%',
                    color: AppColors.chart[i % AppColors.chart.length],
                    radius: 90,
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < data.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        color: AppColors.chart[i % AppColors.chart.length],
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(data[i].name,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarChartView extends StatelessWidget {
  const _BarChartView({required this.data});
  final List<_CatValue> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text('Sem dados no período',
            style: TextStyle(color: AppColors.mutedForeground)),
      );
    }
    final maxY = data.fold(0.0, (a, d) => d.value > a ? d.value : a) * 1.2;
    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 44),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(data[i].name,
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < data.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                  toY: data[i].value,
                  color: const Color(0xFFEF4444),
                  width: 22,
                  borderRadius: BorderRadius.circular(2)),
            ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tabela de transações recentes
// ---------------------------------------------------------------------------

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.transactions});
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final sorted = [
      ...transactions
    ]..sort((a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));
    final rows = sorted.take(10).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transações Recentes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Data')),
                DataColumn(label: Text('Tipo')),
                DataColumn(label: Text('Categoria')),
                DataColumn(label: Text('Descrição')),
                DataColumn(label: Text('Valor'), numeric: true),
              ],
              rows: rows.map((t) {
                final isEntrada = t.type == 'entrada';
                final color = isEntrada ? AppColors.green600 : AppColors.red600;
                return DataRow(cells: [
                  DataCell(Text(formatDate(t.date))),
                  DataCell(Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isEntrada ? AppColors.green100 : AppColors.red100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isEntrada ? Icons.arrow_outward : Icons.south_east,
                            size: 12,
                            color: isEntrada
                                ? AppColors.green700
                                : AppColors.red700),
                        const SizedBox(width: 4),
                        Text(isEntrada ? 'Entrada' : 'Saída',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isEntrada
                                    ? AppColors.green700
                                    : AppColors.red700)),
                      ],
                    ),
                  )),
                  DataCell(Text(t.category)),
                  DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(t.description, overflow: TextOverflow.ellipsis),
                  )),
                  DataCell(Text(
                    '${isEntrada ? '+' : '-'}${formatCurrency(t.amount)}',
                    style: TextStyle(fontWeight: FontWeight.w500, color: color),
                  )),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diálogo: adicionar transação
// ---------------------------------------------------------------------------

// Categorias padrão (valor, rótulo). As de Peças só fazem sentido na loja
// principal (oficina) — lojas novas não devem vir com elas.
const _kEntradaCatsCommon = [
  ['Serviços', 'Serviços'],
  ['Produtos', 'Venda de Produtos'],
  ['Outros', 'Outros'],
];
const _kEntradaCatsOficina = ['Peças', 'Venda de Peças'];

const _kSaidaCatsCommon = [
  ['Produtos', 'Compra de Produtos'],
  ['Funcionários', 'Funcionários'],
  ['Infraestrutura', 'Infraestrutura'],
  ['Outros', 'Outros'],
];
const _kSaidaCatsOficina = ['Peças', 'Compra de Peças'];

List<List<String>> _defaultCatsFor(String type, String storeId) {
  final isOficina = storeId == 'motogest';
  if (type == 'entrada') {
    return [
      if (isOficina) _kEntradaCatsOficina,
      ..._kEntradaCatsCommon,
    ];
  }
  return [
    if (isOficina) _kSaidaCatsOficina,
    ..._kSaidaCatsCommon,
  ];
}

class _TransactionDialog extends StatefulWidget {
  const _TransactionDialog({required this.storeId, required this.onSubmit});
  final String storeId;
  final ValueChanged<Transaction> onSubmit;

  @override
  State<_TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<_TransactionDialog> {
  String _type = 'entrada';
  String? _category;
  final _description = TextEditingController();
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final messenger = ScaffoldMessenger.of(context);
    if (_category == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Selecione uma categoria')));
      return;
    }
    if (_description.text.trim().isEmpty) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Preencha a descrição')));
      return;
    }
    final value = parseCurrencyInput(_amount.text);
    if (value <= 0) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Informe um valor válido')));
      return;
    }
    final dateStr =
        '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
    widget.onSubmit(Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      category: _category!,
      description: _description.text,
      amount: value,
      date: dateStr,
      month: dateStr.split('-').take(2).join('-'),
    ));
    Navigator.of(context).pop();
  }

  /// Abre o gerenciador de categorias já no tipo atual; a categoria criada
  /// é selecionada automaticamente neste diálogo.
  Future<void> _openCategoryManager() async {
    await showAppDialog<void>(
      context: context,
      builder: (_) => _CategoryManagerDialog(
        storeId: widget.storeId,
        initialType: _type,
        onPicked: (type, name) => setState(() {
          _type = type;
          _category = name;
        }),
      ),
    );
  }

  /// Itens do dropdown: categorias padrão + personalizadas da loja (sem
  /// duplicar valores). Mantém o nome do valor já selecionado válido.
  List<DropdownMenuItem<String>> _categoryItems(List<FinanceCategory> custom) {
    final defaults = _defaultCatsFor(_type, widget.storeId);
    final seen = <String>{};
    final items = <DropdownMenuItem<String>>[];
    void add(String value, String label) {
      if (seen.add(value)) {
        items.add(DropdownMenuItem(value: value, child: Text(label)));
      }
    }

    for (final c in defaults) {
      add(c[0], c[1]);
    }
    for (final c in custom) {
      add(c.name, c.name);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final custom = context
        .watch<DataProvider>()
        .customCategoriesFor(widget.storeId, _type);
    final items = _categoryItems(custom);
    // Se a categoria selecionada não existe mais (ex.: removida ou troca de
    // tipo), zera para evitar erro do DropdownButton.
    final selected = items.any((i) => i.value == _category) ? _category : null;
    return AlertDialog(
      title: const Text('Adicionar Transação'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tipo', style: TextStyle(fontWeight: FontWeight.w500)),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'entrada',
                      groupValue: _type,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Entrada'),
                      onChanged: (v) => setState(() {
                        _type = v!;
                        _category = null;
                      }),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'saida',
                      groupValue: _type,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Saída'),
                      onChanged: (v) => setState(() {
                        _type = v!;
                        _category = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Categoria',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _openCategoryManager,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nova categoria'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selected,
                isExpanded: true,
                hint: const Text('Selecione a categoria'),
                items: items,
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 12),
              const Text('Descrição',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration:
                    const InputDecoration(hintText: 'Descrição da transação'),
              ),
              const SizedBox(height: 12),
              const Text('Valor (R\$)',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [CurrencyInputFormatter()],
                decoration: const InputDecoration(hintText: 'R\$ 0,00'),
              ),
              const SizedBox(height: 12),
              const Text('Data', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(formatDate(_date.toIso8601String())),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        ElevatedButton(onPressed: _submit, child: const Text('Adicionar')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Diálogo: adicionar loja
// ---------------------------------------------------------------------------

class _StoreDialog extends StatefulWidget {
  const _StoreDialog({required this.onSubmit});
  final ValueChanged<BusinessStore> onSubmit;

  @override
  State<_StoreDialog> createState() => _StoreDialogState();
}

class _StoreDialogState extends State<_StoreDialog> {
  final _name = TextEditingController();
  final _type = TextEditingController();
  int _color = 0xFF3B82F6;

  static const _palette = [
    0xFF3B82F6,
    0xFF10B981,
    0xFFF59E0B,
    0xFFEF4444,
    0xFF8B5CF6,
    0xFFEC4899,
  ];

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    super.dispose();
  }

  void _submit() {
    final messenger = ScaffoldMessenger.of(context);
    if (_name.text.trim().isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Preencha o nome da loja')));
      return;
    }
    if (_type.text.trim().isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Preencha o tipo de negócio')));
      return;
    }
    widget.onSubmit(BusinessStore(
      id: 'store-${DateTime.now().millisecondsSinceEpoch}',
      name: _name.text,
      type: _type.text,
      icon: 'store',
      color: _color,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar Nova Loja'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nome da Loja',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              decoration:
                  const InputDecoration(hintText: 'Ex: Pet Shop Amigo Fiel'),
            ),
            const SizedBox(height: 12),
            const Text('Tipo de Negócio',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _type,
              decoration: const InputDecoration(
                  hintText: 'Ex: Loja de Ração, Padaria, etc'),
            ),
            const SizedBox(height: 12),
            const Text('Cor', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _palette.map((c) {
                final selected = c == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            selected ? AppColors.primary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        ElevatedButton(onPressed: _submit, child: const Text('Adicionar')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Diálogo: gerenciar categorias personalizadas (criar / renomear / excluir)
// ---------------------------------------------------------------------------

class _CategoryManagerDialog extends StatefulWidget {
  const _CategoryManagerDialog({
    required this.storeId,
    this.initialType = 'entrada',
    this.onPicked,
  });

  final String storeId;
  final String initialType;

  /// Chamado quando uma categoria é criada (tipo, nome). Usado pelo diálogo de
  /// transação para selecioná-la automaticamente; nulo quando aberto da tela.
  final void Function(String type, String name)? onPicked;

  @override
  State<_CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<_CategoryManagerDialog> {
  late String _type = widget.initialType;
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isDuplicate(String name, {String? exceptId}) {
    final lower = name.toLowerCase();
    final inDefaults = _defaultCatsFor(_type, widget.storeId)
        .any((c) => c[0].toLowerCase() == lower);
    final inCustom = context
        .read<DataProvider>()
        .customCategoriesFor(widget.storeId, _type)
        .any((c) => c.id != exceptId && c.name.toLowerCase() == lower);
    return inDefaults || inCustom;
  }

  Future<void> _add() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Informe um nome');
      return;
    }
    if (_isDuplicate(name)) {
      setState(() => _error = 'Essa categoria já existe');
      return;
    }
    final data = context.read<DataProvider>();
    final ok = await runGuarded(
        context, () => data.addCategory(widget.storeId, _type, name));
    if (!ok || !mounted) return;
    _controller.clear();
    setState(() => _error = null);
    widget.onPicked?.call(_type, name);
  }

  Future<void> _rename(FinanceCategory c) async {
    final controller = TextEditingController(text: c.name);
    final messenger = ScaffoldMessenger.of(context);
    final data = context.read<DataProvider>();
    final newName = await showAppDialog<String>(
      context: context,
      builder: (ctx) {
        String? err;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void confirm() {
              final n = controller.text.trim();
              if (n.isEmpty) {
                setLocal(() => err = 'Informe um nome');
                return;
              }
              if (n.toLowerCase() != c.name.toLowerCase() &&
                  _isDuplicate(n, exceptId: c.id)) {
                setLocal(() => err = 'Essa categoria já existe');
                return;
              }
              Navigator.of(ctx).pop(n);
            }

            return AlertDialog(
              title: const Text('Renomear categoria'),
              content: TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    InputDecoration(hintText: 'Novo nome', errorText: err),
                onSubmitted: (_) => confirm(),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar')),
                ElevatedButton(onPressed: confirm, child: const Text('Salvar')),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (newName == null || newName == c.name || !mounted) return;
    final ok = await runGuarded(context, () => data.renameCategory(c, newName));
    if (ok) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Categoria renomeada com sucesso!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final custom = context
        .watch<DataProvider>()
        .customCategoriesFor(widget.storeId, _type);
    return AlertDialog(
      title: const Text('Gerenciar Categorias'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alterna o tipo (entrada/saída) das categorias gerenciadas.
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Entrada'),
                  selected: _type == 'entrada',
                  onSelected: (_) => setState(() {
                    _type = 'entrada';
                    _error = null;
                  }),
                ),
                ChoiceChip(
                  label: const Text('Saída'),
                  selected: _type == 'saida',
                  onSelected: (_) => setState(() {
                    _type = 'saida';
                    _error = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Nome da nova categoria',
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _add, child: const Text('Adicionar')),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Categorias personalizadas',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 4),
            if (custom.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nenhuma categoria personalizada ainda.\n'
                  'As categorias padrão continuam disponíveis.',
                  style:
                      TextStyle(color: AppColors.mutedForeground, fontSize: 13),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in custom)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(c.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Renomear',
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _rename(c),
                            ),
                            IconButton(
                              tooltip: 'Remover',
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.destructive),
                              onPressed: () => runGuarded(
                                  context,
                                  () => context
                                      .read<DataProvider>()
                                      .deleteCategory(c.id)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar')),
      ],
    );
  }
}
