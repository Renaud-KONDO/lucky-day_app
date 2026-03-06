import 'package:flutter/material.dart';
import 'package:lucky_day/data/models/models.dart';
import 'package:lucky_day/screens/raffle/raffle_detail_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
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
  bool _hideParticipated = false;

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
    final userParticipations = context.read<RaffleProvider>().myRaffles.map((r) => r.id).toSet();

    var list = source.where((r) {
      final matchSearch = _search.isEmpty ||
          r.title.toLowerCase().contains(_search.toLowerCase()) ||
          (r.product?.name.toLowerCase().contains(_search.toLowerCase()) ?? false);
      final matchMin = _minPrice == null || r.entryPrice >= _minPrice!;
      final matchMax = _maxPrice == null || r.entryPrice <= _maxPrice!;
      final matchCat = _categoryId == null ||
        r.productCategoryId == _categoryId;

      final matchParticipation = !_hideParticipated || !userParticipations.contains(r.id);

      return matchSearch && matchMin && matchMax && matchCat && matchParticipation;
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
        currentHideParticipated: _hideParticipated,
        onApply: (sort, min, max, categoryId, categoryName, hideParticipated) {
          setState(() { _sortBy = sort; _minPrice = min; _maxPrice = max; _categoryId   = categoryId; _categoryName = categoryName; _hideParticipated = hideParticipated;});
        },
        onReset: () {
          setState(() { _sortBy = null; _minPrice = null; _maxPrice = null; _categoryId = null; _categoryName = null; _hideParticipated = false;});
        },
      ),
    );
  }

bool get _hasActiveFilters =>
    _sortBy != null || _minPrice != null || _maxPrice != null || _categoryId != null || _hideParticipated;

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
                if (_hideParticipated)
                  _filterChip('Masquer mes participations',
                    () => setState(() => _hideParticipated = false)),
                if (_hasActiveFilters)
                  TextButton(
                    onPressed: () => setState(() {
                      _sortBy = null; _minPrice = null; _maxPrice = null; _hideParticipated = false;
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
    final userParticipations = prov.myRaffles.map((r) => r.id).toSet();


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
                    (_, i) {
                      final raffle = raffles[i];
                      // ✅ Vérifier si l'utilisateur participe déjà
                      final isParticipating = userParticipations.contains(raffle.id);
                      
                      return RaffleCard(
                        raffle: raffle,
                        isParticipating: isParticipating, 
                        onTap: () => 
                          //if (isParticipating) {
                            // Si déjà participant, naviguer vers les détails
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RaffleDetailScreen(raffle: raffle),
                              ),
                            ),
                            onParticipate: isParticipating
                            ? null // Pas de bouton si déjà participant
                            : () => _showParticipateSheet(context, raffle),
                          //} else {
                            // Sinon, ouvrir la sheet de participation
                          //  _showParticipateSheet(context, raffle);
                          //}
                        
                      );
                    },
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

  void _showParticipateSheet(BuildContext context, Raffle raffle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ParticipateSheet(raffle: raffle),
    );
  }
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
  final bool currentHideParticipated;
  final void Function(String? sort, double? min, double? max,
      String? categoryId, String? categoryName, bool hideParticipated,) onApply;
  
  const _FilterSheet({
    required this.currentSort,
    required this.currentMin,
    required this.currentMax,
    required this.onApply,
    required this.onReset,
    this.currentCategoryId,
    required this.currentHideParticipated,
    this.currentCategoryName,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _sort;
  String? _categoryId;
  String? _categoryName;
  bool _hideParticipated = false;
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
    _hideParticipated = widget.currentHideParticipated; 

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
          // ── Masquer participations ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _hideParticipated
                  ? AppTheme.primaryColor.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hideParticipated
                    ? AppTheme.primaryColor.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _hideParticipated ? Icons.visibility_off : Icons.visibility,
                  color: _hideParticipated
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Masquer mes participations',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _hideParticipated
                              ? AppTheme.primaryColor
                              : AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ne montrer que les tombolas disponibles',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _hideParticipated,
                  onChanged: (v) => setState(() => _hideParticipated = v),
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
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
                    _hideParticipated,                     
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

class _ParticipateSheet extends StatefulWidget {
  final Raffle raffle;
  const _ParticipateSheet({required this.raffle});
  @override
  State<_ParticipateSheet> createState() => _ParticipateSheetState();
}

class _ParticipateSheetState extends State<_ParticipateSheet> {
  String _paymentMethod = 'wallet'; // 'wallet' ou 'mobilemoney'
  bool _processing = false;

  Future<void> _participate() async {
    setState(() => _processing = true);
    final prov = context.read<RaffleProvider>();
    
    if (_paymentMethod == 'mobilemoney') {
      _paymentMethod = "mobile_money";
      // TODO: Backend gère le paiement mobile money
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement mobile money bientôt disponible'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
      setState(() => _processing = false);
      return;
    }

    // Paiement par wallet
    final ok = await prov.participate(widget.raffle.id, _paymentMethod);
    
    if (mounted) {
      Navigator.pop(context);
      if (ok) {
        // Refresh solde
        context.read<AuthProvider>().refreshProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Participation confirmée ! Bonne chance !'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(prov.errorMessage ?? 'Erreur de participation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final hasSufficientBalance = user != null && user.balance >= widget.raffle.entryPrice;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 16),

        // Titre
        Row(children: [
          const Icon(Icons.confirmation_number, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          const Text('Participer à la tombola',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        Text(widget.raffle.title,
          style: AppTheme.bodyText,
          maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 20),

        // Prix
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Prix d\'entrée',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text(
                '${widget.raffle.entryPrice.toStringAsFixed(0)} ${AppStrings.currency}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Méthodes de paiement
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Méthode de paiement',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ),
        const SizedBox(height: 12),

        // Wallet
        _paymentMethodCard(
          value: 'wallet',
          icon: Icons.account_balance_wallet,
          title: 'Portefeuille',
          subtitle: user != null
              ? 'Solde: ${user.balance.toStringAsFixed(0)} ${AppStrings.currency}'
              : 'Non connecté',
          available: hasSufficientBalance,
        ),
        const SizedBox(height: 10),

        // Mobile Money
        _paymentMethodCard(
          value: 'mobilemoney',
          icon: Icons.phone_android,
          title: 'Mobile Money',
          subtitle: 'T-Money, Flooz, etc.',
          available: true,
        ),

        const SizedBox(height: 24),

        // Bouton
        ElevatedButton(
          onPressed: (_processing || (_paymentMethod == 'wallet' && !hasSufficientBalance))
              ? null
              : _participate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
          ),
          child: _processing
              ? const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Confirmer la participation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _paymentMethodCard({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool available,
  }) {
    final selected = _paymentMethod == value;
    return GestureDetector(
      onTap: available ? () => setState(() => _paymentMethod = value) : null,
      child: Opacity(
        opacity: available ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : Colors.grey.withOpacity(0.3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primaryColor.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
                  size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? AppTheme.primaryColor : AppTheme.textPrimary)),
                const SizedBox(height: 3),
                Text(subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: available
                        ? AppTheme.textSecondary
                        : Colors.red)),
              ],
            )),
            if (selected)
              const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 22),
          ]),
        ),
      ),
    );
  }
}