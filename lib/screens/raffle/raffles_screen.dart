import 'package:flutter/material.dart';
import 'package:lucky_day/data/models/models.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/raffle_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/raffle_card.dart';
import '../../widgets/winners_banner.dart';

class RafflesScreen extends StatefulWidget {
  const RafflesScreen({super.key});
  @override
  State<RafflesScreen> createState() => _RafflesScreenState();
}

class _RafflesScreenState extends State<RafflesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _sortBy;      // 'price_asc', 'price_desc', 'fill_asc', 'fill_desc'
  double? _minPrice;
  double? _maxPrice;
  String? _categoryId;
  String? _categoryName;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RaffleProvider>().fetchAll();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Filtre + tri local sur une liste de raffles
  List<Raffle> _apply(List<Raffle> source) {
    var list = source.where((r) {
      final matchSearch = _search.isEmpty ||
          r.title.toLowerCase().contains(_search.toLowerCase()) ||
          (r.product?.name.toLowerCase().contains(_search.toLowerCase()) ?? false);
      final matchMin = _minPrice == null || r.entryPrice >= _minPrice!;
      final matchMax = _maxPrice == null || r.entryPrice <= _maxPrice!;
      final matchCat = _categoryId == null ||
        r.productCategoryId == _categoryId;
      return matchSearch && matchMin && matchMax && matchCat;
    }).toList();

    switch (_sortBy) {
      case 'price_asc':  list.sort((a, b) => a.entryPrice.compareTo(b.entryPrice)); break;
      case 'price_desc': list.sort((a, b) => b.entryPrice.compareTo(a.entryPrice)); break;
      case 'fill_asc':   list.sort((a, b) => a.fillPercentage.compareTo(b.fillPercentage)); break;
      case 'fill_desc':  list.sort((a, b) => b.fillPercentage.compareTo(a.fillPercentage)); break;
    }
    return list;
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FilterSheet(
        currentSort: _sortBy,
        currentMin: _minPrice,
        currentMax: _maxPrice,
        currentCategoryId:   _categoryId,      
        currentCategoryName: _categoryName,    
        onApply: (sort, min, max, categoryId, categoryName) {
          setState(() { _sortBy = sort; _minPrice = min; _maxPrice = max; _categoryId   = categoryId; _categoryName = categoryName; });
        },
        onReset: () {
          setState(() { _sortBy = null; _minPrice = null; _maxPrice = null; _categoryId = null; _categoryName = null; });
        },
      ),
    );
  }

bool get _hasActiveFilters =>
    _sortBy != null || _minPrice != null || _maxPrice != null || _categoryId != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.star, color: AppTheme.accentColor, size: 20),
          SizedBox(width: 8),
          Text('Tombolas'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<RaffleProvider>().fetchAll(),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: '⭐ Forte'),
            Tab(text: '🎯 Moyenne'),
            Tab(text: '🎲 Faible'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Barre recherche + filtre ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une tombola...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            })
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 8),
              // Bouton filtre avec badge si actif
              Stack(children: [
                IconButton(
                  onPressed: _openFilters,
                  icon: Icon(
                    Icons.tune,
                    color: _hasActiveFilters
                        ? AppTheme.secondaryColor
                        : AppTheme.textSecondary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: _hasActiveFilters
                        ? AppTheme.secondaryColor.withOpacity(0.1)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (_hasActiveFilters)
                  Positioned(
                    right: 6, top: 6,
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.secondaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ]),
            ]),
          ),

          // ── Chips filtres actifs ──────────────────────────────────────
          if (_hasActiveFilters || _search.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(children: [
                if (_sortBy != null)
                  _filterChip(_sortLabel(_sortBy!),
                      () => setState(() => _sortBy = null)),
                if (_minPrice != null)
                  _filterChip('Min: ${_minPrice!.toInt()} XOF',
                      () => setState(() => _minPrice = null)),
                if (_maxPrice != null)
                  _filterChip('Max: ${_maxPrice!.toInt()} XOF',
                      () => setState(() => _maxPrice = null)),
                if (_categoryId != null)
                  _filterChip(_categoryName ?? 'Catégorie',
                      () => setState(() { _categoryId = null; _categoryName = null; })),
                if (_hasActiveFilters)
                  TextButton(
                    onPressed: () => setState(() {
                      _sortBy = null; _minPrice = null; _maxPrice = null;
                    }),
                    child: const Text('Tout effacer',
                        style: TextStyle(fontSize: 12, color: Colors.red)),
                  ),
              ]),
            ),

          // ── Tabs ──────────────────────────────────────────────────────
          Expanded(
            child: Consumer<RaffleProvider>(
              builder: (_, prov, __) {
                if (prov.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (prov.errorMessage != null) {
                  return Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(prov.errorMessage!, style: AppTheme.bodyText),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: () => prov.fetchAll(),
                          child: const Text('Réessayer')),
                    ],
                  ));
                }
                return TabBarView(
                  controller: _tab,
                  children: [
                    _buildTab(prov, AppConstants.highProbability),
                    _buildTab(prov, AppConstants.mediumProbability),
                    _buildTab(prov, AppConstants.lowProbability),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(RaffleProvider prov, String type) {
    final raffles = _apply(prov.byProbability(type));
    final winners = prov.recentWinners(type);

    return RefreshIndicator(
      onRefresh: () => prov.fetchAll(),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: WinnersBanner(winners: winners)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(children: [
                const Icon(Icons.confirmation_number_outlined,
                    size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text('Tombolas disponibles',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${raffles.length}',
                      style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ]),
            ),
          ),
          raffles.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off,
                            size: 64, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          _search.isNotEmpty || _hasActiveFilters
                              ? 'Aucun résultat pour ces filtres'
                              : 'Aucune tombola disponible',
                          style: AppTheme.bodyText,
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => RaffleCard(raffle: raffles[i], onTap: () {}),
                      childCount: raffles.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, VoidCallback onRemove) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onRemove,
      backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
      side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.2)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );

  String _sortLabel(String sort) {
    switch (sort) {
      case 'price_asc':  return 'Prix ↑';
      case 'price_desc': return 'Prix ↓';
      case 'fill_asc':   return 'Remplissage ↑';
      case 'fill_desc':  return 'Remplissage ↓';
      default: return sort;
    }
  }
}

// ─── Bottom Sheet Filtres ─────────────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final String? currentSort;
  final double? currentMin;
  final double? currentMax;
  final VoidCallback onReset;
  final String? currentCategoryId;
  final String? currentCategoryName;
  final void Function(String? sort, double? min, double? max,
      String? categoryId, String? categoryName) onApply;
  
  const _FilterSheet({
    required this.currentSort,
    required this.currentMin,
    required this.currentMax,
    required this.onApply,
    required this.onReset,
    this.currentCategoryId,
    this.currentCategoryName,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _sort;
  String? _categoryId;
  String? _categoryName;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sort = widget.currentSort;
    if (widget.currentMin != null) _minCtrl.text = widget.currentMin!.toInt().toString();
    if (widget.currentMax != null) _maxCtrl.text = widget.currentMax!.toInt().toString();
    _categoryId = widget.currentCategoryId;
    _categoryName = widget.currentCategoryName;

    WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<CategoryProvider>().fetchProductCategories();
    });
  
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Filtres & Tri',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 20),

          // ── Tri ─────────────────────────────────────────────────────────
          const Text('Trier par',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _sortChip('Prix croissant', 'price_asc', Icons.arrow_upward),
            _sortChip('Prix décroissant', 'price_desc', Icons.arrow_downward),
            _sortChip('Moins rempli', 'fill_asc', Icons.people_outline),
            _sortChip('Plus rempli', 'fill_desc', Icons.people),
          ]),
          const SizedBox(height: 20),

          //___ Catégorie (à implémenter) ─────────────────────────────────────────
          const SizedBox(height: 20),
          const Text('Catégorie de produit',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          Consumer<CategoryProvider>(
            builder: (_, catProv, __) {
              if (catProv.productCategories.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, size: 16, color: AppTheme.textSecondary),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'Le filtre par catégorie sera disponible prochainement',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    )),
                  ]),
                );
              }
              return Wrap(spacing: 8, runSpacing: 8,
                children: [
                  // Chip "Toutes"
                  FilterChip(
                    label: const Text('Toutes'),
                    selected: _categoryId == null,
                    onSelected: (_) => setState(() { _categoryId = null; _categoryName = null; }),
                    selectedColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(
                        color: _categoryId == null ? Colors.white : AppTheme.textPrimary,
                        fontSize: 12),
                    showCheckmark: false,
                  ),
                  ...catProv.productCategories.map((cat) {
                    final selected = _categoryId == cat.id;
                    return FilterChip(
                      label: Text(cat.name),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _categoryId   = selected ? null : cat.id;
                        _categoryName = selected ? null : cat.name;
                      }),
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                          color: selected ? Colors.white : AppTheme.textPrimary,
                          fontSize: 12),
                      showCheckmark: false,
                    );
                  }),
                ],
              );
            },
          ),

          // ── Prix ─────────────────────────────────────────────────────────
          const Text("Prix d'entrée (XOF)",
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Min', prefixText: '  ',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text('—', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _maxCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max', prefixText: '  ',
                  isDense: true,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 28),

          // ── Boutons ──────────────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  widget.onReset();
                  Navigator.pop(context);
                },
                child: const Text('Réinitialiser'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(
                    _sort,
                    _minCtrl.text.isNotEmpty ? double.tryParse(_minCtrl.text) : null,
                    _maxCtrl.text.isNotEmpty ? double.tryParse(_maxCtrl.text) : null,
                    _categoryId,      
                    _categoryName,                     
                  );
                  Navigator.pop(context);
                },
                child: const Text('Appliquer'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _sortChip(String label, String value, IconData icon) {
    final selected = _sort == value;
    return FilterChip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14,
            color: selected ? Colors.white : AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(label),
      ]),
      selected: selected,
      onSelected: (_) => setState(() => _sort = selected ? null : value),
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.textPrimary,
          fontSize: 13),
      showCheckmark: false,
    );
  }
}