import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/data_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'parts_management_page.dart' show emptyStateShared;

class SearchPartsPage extends StatefulWidget {
  const SearchPartsPage({super.key});

  @override
  State<SearchPartsPage> createState() => _SearchPartsPageState();
}

class _SearchPartsPageState extends State<SearchPartsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _category = 'all';
  String _brand = 'all';
  String _stock = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() {
      _category = 'all';
      _brand = 'all';
      _stock = 'all';
      _query = '';
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final parts = context.watch<DataProvider>().parts;
    final categories = {for (final p in parts) p.category}.toList();
    final brands = {for (final p in parts) p.brand}.toList();
    final q = _query.toLowerCase();

    final filtered = parts.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(q) ||
          p.code.toLowerCase().contains(q) ||
          (p.description?.toLowerCase().contains(q) ?? false) ||
          p.brand.toLowerCase().contains(q);
      final matchesCat = _category == 'all' || p.category == _category;
      final matchesBrand = _brand == 'all' || p.brand == _brand;
      final matchesStock = _stock == 'all' ||
          (_stock == 'in-stock' && p.stock > 0) ||
          (_stock == 'low-stock' && p.stock > 0 && p.stock <= 5) ||
          (_stock == 'out-of-stock' && p.stock == 0);
      return matchesSearch && matchesCat && matchesBrand && matchesStock;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            icon: Icons.search,
            title: 'Busca de Peças',
            subtitle: 'Consulte o catálogo completo de peças disponíveis',
          ),
          const SizedBox(height: 32),
          _filtersCard(categories, brands, filtered.length),
          const SizedBox(height: 32),
          if (filtered.isEmpty)
            emptyStateShared(
              icon: Icons.inventory_2_outlined,
              title: 'Nenhuma peça encontrada',
              subtitle: 'Tente ajustar os filtros de busca',
            )
          else
            _resultsGrid(filtered),
        ],
      ),
    );
  }

  Widget _filtersCard(List<String> categories, List<String> brands, int count) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.filter_list, size: 20, color: AppColors.mutedForeground),
            SizedBox(width: 8),
            Text('Filtros de Busca',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 1024 ? 4 : (c.maxWidth >= 640 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: cols == 1 ? 5 : 3,
              children: [
                _labeled(
                    'Buscar',
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Nome, código ou descrição...',
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                    )),
                _labeled(
                    'Categoria',
                    _select(
                      _category,
                      {'all': 'Todas', for (final c in categories) c: c},
                      (v) => setState(() => _category = v!),
                    )),
                _labeled(
                    'Marca',
                    _select(
                      _brand,
                      {'all': 'Todas', for (final b in brands) b: b},
                      (v) => setState(() => _brand = v!),
                    )),
                _labeled(
                    'Disponibilidade',
                    _select(
                      _stock,
                      const {
                        'all': 'Todos',
                        'in-stock': 'Em estoque',
                        'low-stock': 'Estoque baixo',
                        'out-of-stock': 'Sem estoque',
                      },
                      (v) => setState(() => _stock = v!),
                    )),
              ],
            );
          }),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count ${count == 1 ? 'peça encontrada' : 'peças encontradas'}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.mutedForeground),
              ),
              OutlinedButton(
                  onPressed: _clear, child: const Text('Limpar filtros')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _labeled(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _select(String value, Map<String, String> items,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      items: items.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _resultsGrid(List<MotorcyclePart> parts) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1024 ? 3 : (c.maxWidth >= 768 ? 2 : 1);
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.15,
        children: parts.map(_card).toList(),
      );
    });
  }

  Widget _stockBadge(int stock) {
    if (stock == 0) {
      return const AppBadge(
          label: 'Sem estoque', variant: BadgeVariant.destructive);
    }
    if (stock <= 5) {
      return const AppBadge(
          label: 'Estoque baixo', variant: BadgeVariant.outline);
    }
    return const AppBadge(label: 'Disponível', variant: BadgeVariant.primary);
  }

  Widget _card(MotorcyclePart p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Código: ${p.code}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.mutedForeground)),
                  ],
                ),
              ),
              _stockBadge(p.stock),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _kv('Categoria', p.category)),
            Expanded(child: _kv('Marca', p.brand)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _kv('Preço', formatCurrency(p.price), big: true)),
            Expanded(child: _kv('Estoque', '${p.stock} unidades')),
          ]),
          if (p.description != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(p.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.mutedForeground)),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool big = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k,
            style: const TextStyle(
                fontSize: 13, color: AppColors.mutedForeground)),
        Text(v,
            style: TextStyle(
                fontSize: big ? 18 : 14,
                fontWeight: big ? FontWeight.w700 : FontWeight.w500)),
      ],
    );
  }
}
