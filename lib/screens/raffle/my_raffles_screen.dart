import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucky_day/screens/raffle/raffle_detail_screen.dart';
import 'package:provider/provider.dart';
import '../../data/services/location_service.dart';
import '../../providers/raffle_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/raffle_card.dart';
import '../../data/models/models.dart';
import 'package:latlong2/latlong.dart';

import 'create_raffle_screen.dart';
import 'map_picker_screen.dart';

class MyRafflesScreen extends StatefulWidget {
  const MyRafflesScreen({super.key});
  @override
  State<MyRafflesScreen> createState() => _MyRafflesScreenState();
}

class _MyRafflesScreenState extends State<MyRafflesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _currentTabIndex = 0;
  bool _hasLoadedCreated = false;

  // ✅ Filtres et recherche
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _statusFilter;
  String _sortBy = 'date_desc'; // date_desc, date_asc, price_desc, price_asc

  @override
  void initState() {
    super.initState();
    // Déterminer le nombre de tabs selon le rôle
    final auth = context.read<AuthProvider>();
    final isOwner = auth.currentUser?.isStoreOwner ?? false;
    
    _tab = TabController(length: isOwner ? 3 : 2, vsync: this);  // ← 3 tabs si owner
    
    // ✅ Écouter les changements de tab
    _tab.addListener(() {
      if (_tab.indexIsChanging) return;
      setState(() {
        _currentTabIndex = _tab.index;
      });

      if (isOwner && _currentTabIndex == 2 && !_hasLoadedCreated) {
        _hasLoadedCreated = true;
        context.read<RaffleProvider>().fetchMyCreatedRaffles(auth.currentUser!.id);
      }
    });

    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<RaffleProvider>();
      p.fetchMine();
      p.fetchWins();
      
      // Fetch les tombolas créées si owner. désactivé car fait que l'appel se fait juste après le login
      /* if (isOwner) {
        p.fetchMyCreatedRaffles();
      } */
    });
  }

  @override
  void dispose() { _tab.dispose(); _searchCtrl.dispose(); super.dispose(); }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FilterSheet(
        currentStatus: _statusFilter,
        currentSort: _sortBy,
        onApply: (status, sort) {
          setState(() {
            _statusFilter = status;
            _sortBy = sort;
          });
        },
      ),
    );
  }

  //@override
 /*  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isOwner = auth.currentUser?.isStoreOwner ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Tombolas'),
        actions: [
          Text('Filtrer', style: TextStyle(color: Colors.white70)),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_statusFilter != null || _sortBy != 'date_desc')
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.secondaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final p = context.read<RaffleProvider>();
              p.fetchMine();
              p.fetchWins();

              // ✅ Refresh les tombolas créées si owner
              if (isOwner) {
                p.fetchMyCreatedRaffles(auth.currentUser!.id);
              }
            },
          ),
        ],
        bottom: 
        PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // Barre de recherche
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 200, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une tombola...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              TabBar(
                controller: _tab,
                indicatorColor: AppTheme.accentColor,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: [
                  const Tab(text: 'Participations'),
                  const Tab(text: '🏆 Gagnées'),
                  if (isOwner) const Tab(text: '📝 Mes Tombolas'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Consumer<RaffleProvider>(
        builder: (_, prov, __) => TabBarView(
          controller: _tab,
          children: [
            _ParticipationsTab(
              raffles: prov.myRaffles,
              onRefresh: prov.fetchMine,
              searchQuery: _searchQuery,
              statusFilter: _statusFilter,
              sortBy: _sortBy,
            ),
            _WinsTab(
              raffles: prov.myWins,
              onRefresh: prov.fetchWins,
              searchQuery: _searchQuery,
              sortBy: _sortBy,
            ),
            if (isOwner)
              _CreatedRafflesTab(
                raffles: prov.myCreatedRaffles,
                onRefresh: () => prov.fetchMyCreatedRaffles(auth.currentUser!.id),
                searchQuery: _searchQuery,
                statusFilter: _statusFilter,
                sortBy: _sortBy,
              ),
          ],
        ),
      ),
      // FAB simplifié - juste vérifier si owner
      floatingActionButton: isOwner && _currentTabIndex == 2
        ? FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CreateRaffleScreen(), // ← Sans paramètre
              ),
            ).then((_) {
              // Refresh après création
              context.read<RaffleProvider>().fetchMyCreatedRaffles(auth.currentUser!.id);
              context.read<RaffleProvider>().fetchAll();
            }),
            icon: const Icon(Icons.add),
            label: const Text('Créer une tombola'),
            backgroundColor: AppTheme.secondaryColor,
          )
        : null,
    );
  }
 */
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isOwner = auth.currentUser?.isStoreOwner ?? false;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withOpacity(0.8),
              ],
            ),
          ),
        ),
        title: const Text('Mes Tombolas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final p = context.read<RaffleProvider>();
              p.fetchMine();
              p.fetchWins();
              if (isOwner) {
                p.fetchMyCreatedRaffles(auth.currentUser!.id);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Barre de recherche + filtre avec glassmorphisme
          Container(
            padding: const EdgeInsets.fromLTRB(16, 105, 14, 14),
            color: AppTheme.primaryColor,
            child: Row(
              children: [
                // Barre de recherche avec glassmorphisme
                Expanded(
                  child: Container(
                    height: 44, 
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.black, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Rechercher...',
                        hintStyle: TextStyle(color: Colors.black.withOpacity(0.7), fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.black, size: 20,),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.black, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                Text("Filtrer et trier", style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500),),
                const SizedBox(width: 8),

                // Bouton filtre avec glassmorphisme
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showFilterSheet,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.tune, color: Colors.white, size: 20),
                            if (_statusFilter != null || _sortBy != 'date_desc')
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 1),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: AppTheme.primaryColor.withOpacity(0.05),
            child: TabBar(
              controller: _tab,
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorWeight: 3,
              tabs: [
                const Tab(text: 'Mes Participations'),
                const Tab(text: '🏆 Tombolas Gagnées'),
                if (isOwner) const Tab(text: '📝 Tombolas Créées'),
              ],
            ),
          ),

          // Body
          Expanded(
            child: Consumer<RaffleProvider>(
              builder: (_, prov, __) => TabBarView(
                controller: _tab,
                children: [
                  _ParticipationsTab(
                    raffles: prov.myRaffles,
                    onRefresh: prov.fetchMine,
                    searchQuery: _searchQuery,
                    statusFilter: _statusFilter,
                    sortBy: _sortBy,
                  ),
                  _WinsTab(
                    raffles: prov.myWins,
                    onRefresh: prov.fetchWins,
                    searchQuery: _searchQuery,
                    sortBy: _sortBy,
                  ),
                  if (isOwner)
                    _CreatedRafflesTab(
                      raffles: prov.myCreatedRaffles,
                      onRefresh: () =>
                          prov.fetchMyCreatedRaffles(auth.currentUser!.id),
                      searchQuery: _searchQuery,
                      statusFilter: _statusFilter,
                      sortBy: _sortBy,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isOwner && _currentTabIndex == 2
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRaffleScreen()),
              ).then((_) {
                context.read<RaffleProvider>().fetchMyCreatedRaffles(
                    auth.currentUser!.id);
                context.read<RaffleProvider>().fetchAll();
              }),
              icon: const Icon(Icons.add),
              label: const Text('Créer'),
              backgroundColor: AppTheme.secondaryColor,
            )
          : null,
    );
  }

}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET : FILTRES
// ═══════════════════════════════════════════════════════════════════════════════

class _FilterSheet extends StatefulWidget {
  final String? currentStatus;
  final String currentSort;
  final Function(String?, String) onApply;

  const _FilterSheet({
    required this.currentStatus,
    required this.currentSort,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _selectedStatus;
  String _selectedSort = 'date_desc';

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
    _selectedSort = widget.currentSort;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Titre
          const Text('Filtres et tri',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Statut
          const Text('Statut',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _filterChip('Tous', null),
            _filterChip('Ouvert', 'open'),
            _filterChip('Complet', 'full'),
            _filterChip('Terminé', 'completed'),
            _filterChip('Annulé', 'cancelled'),
          ]),
          const SizedBox(height: 20),

          // Tri
          const Text('Trier par',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _sortChip('Plus récent', 'date_desc', Icons.arrow_downward),
            _sortChip('Plus ancien', 'date_asc', Icons.arrow_upward),
            _sortChip('Prix décroissant', 'price_desc', Icons.arrow_downward),
            _sortChip('Prix croissant', 'price_asc', Icons.arrow_upward),
          ]),
          const SizedBox(height: 24),

          // Boutons
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedStatus = null;
                    _selectedSort = 'date_desc';
                  });
                },
                child: const Text('Réinitialiser'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_selectedStatus, _selectedSort);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor),
                child: const Text('Appliquer'),
              ),
            ),
          ]),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) => setState(() => _selectedStatus = value),
      selectedColor: AppTheme.primaryColor.withOpacity(0.3),
    );
  }

  Widget _sortChip(String label, String value, IconData icon) {
    final selected = _selectedSort == value;
    return ChoiceChip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label),
        const SizedBox(width: 4),
        Icon(icon, size: 14),
      ]),
      selected: selected,
      onSelected: (v) => setState(() => _selectedSort = value),
      selectedColor: AppTheme.secondaryColor.withOpacity(0.3),
    );
  }
}


// ─── Toutes les participations ────────────────────────────────────────────────
class _ParticipationsTab extends StatelessWidget {
  final List<Raffle> raffles;
  final Future<void> Function() onRefresh;
  final String searchQuery;
  final String? statusFilter;
  final String sortBy;
  const _ParticipationsTab({required this.raffles, required this.onRefresh,required this.searchQuery, required this.statusFilter, required this.sortBy,});

  List<Raffle> _applyFilters(List<Raffle> list) {
    var filtered = list;

    // Recherche
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where((r) =>
              r.title.toLowerCase().contains(searchQuery) ||
              (r.product?.name.toLowerCase().contains(searchQuery) ?? false))
          .toList();
    }

    // Filtre par statut
    if (statusFilter != null) {
      filtered = filtered.where((r) => r.status == statusFilter).toList();
    }

    // Tri
    switch (sortBy) {
      case 'date_asc':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'date_desc':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'price_asc':
        filtered.sort((a, b) => a.entryPrice.compareTo(b.entryPrice));
        break;
      case 'price_desc':
        filtered.sort((a, b) => b.entryPrice.compareTo(a.entryPrice));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredRaffles = _applyFilters(raffles);

   /*  if (raffles.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: AppTheme.textSecondary),
          SizedBox(height: 12),
          Text('Aucune participation', style: AppTheme.bodyText),
          SizedBox(height: 6),
          Text('Participez à des tombolas pour les voir ici',
              style: AppTheme.caption, textAlign: TextAlign.center),
        ],
      ));
    }
 */

  if (raffles.isEmpty) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: AppTheme.textSecondary),
          SizedBox(height: 12),
          Text('Aucune participation',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          SizedBox(height: 6),
          Text('Participez à des tombolas pour les voir ici',
              style: AppTheme.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  if (filteredRaffles.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          const Text('Aucun résultat',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Text(
            searchQuery.isNotEmpty
                ? 'Aucune tombola ne correspond à "$searchQuery"'
                : 'Aucune tombola avec ces filtres',
            style: AppTheme.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

    // Grouper par statut
    /* final open      = raffles.where((r) => r.status == 'open' || r.status == 'full').toList();
    final lost      = raffles.where((r) => r.status == 'completed' && r.winnerId != null).toList();
    final cancelled = raffles.where((r) => r.status == 'cancelled').toList();
 */

    final open = filteredRaffles
        .where((r) => r.status == 'open' || r.status == 'full')
        .toList();
    final lost = filteredRaffles
        .where((r) => r.status == 'completed' && r.winnerId != null)
        .toList();
    final cancelled = filteredRaffles.where((r) => r.status == 'cancelled').toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (open.isNotEmpty) ...[
            _sectionTitle('En cours (${open.length})', AppTheme.primaryColor),
            ...open.map((r) =>RaffleCard(
                raffle: r,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => RaffleDetailScreen(raffle: r)),
                ),
                isParticipating: true,
              )
            ),
          ],
          if (lost.isNotEmpty) ...[
            _sectionTitle('Perdues (${lost.length})', AppTheme.textSecondary),
            ...lost.map((r) => RaffleCard(raffle: r, 
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => RaffleDetailScreen(raffle: r)),
                  ),
                label: 'PERDU', labelColor: Colors.grey)),
          ],
          if (cancelled.isNotEmpty) ...[
            _sectionTitle('Annulées (${cancelled.length})', Colors.orange),
            ...cancelled.map((r) => RaffleCard(raffle: r, 
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => RaffleDetailScreen(raffle: r)),
                  ),
                label: 'ANNULÉ', labelColor: Colors.orange)),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String t, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
    child: Row(children: [
      Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(t,
          style: TextStyle(
              fontWeight: FontWeight.bold, color: color, fontSize: 14)),
    ]),
  );
}

// ─── Tombolas gagnées ─────────────────────────────────────────────────────────
class _WinsTab extends StatelessWidget {
  final List<Raffle> raffles;
  final Future<void> Function() onRefresh;
  final String searchQuery;
  final String sortBy;
  const _WinsTab({
    required this.raffles,
    required this.onRefresh,
    required this.searchQuery,
    required this.sortBy,
  });


  List<Raffle> _applyFilters(List<Raffle> list) {
    var filtered = list;

    // Recherche
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where((r) =>
              r.title.toLowerCase().contains(searchQuery) ||
              (r.product?.name.toLowerCase().contains(searchQuery) ?? false))
          .toList();
    }

    // Tri
    switch (sortBy) {
      case 'date_asc':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'date_desc':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'price_asc':
        filtered.sort((a, b) => a.entryPrice.compareTo(b.entryPrice));
        break;
      case 'price_desc':
        filtered.sort((a, b) => b.entryPrice.compareTo(a.entryPrice));
        break;
    }

    return filtered;
  }


  @override
  Widget build(BuildContext context) {
    final filteredRaffles = _applyFilters(raffles);

    if (raffles.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, size: 64, color: AppTheme.textSecondary),
          SizedBox(height: 12),
          Text("Vous n'avez encore rien gagné", style: AppTheme.bodyText),
          SizedBox(height: 6),
          Text('Bonne chance pour vos prochaines tombolas !',
              style: AppTheme.caption, textAlign: TextAlign.center),
        ],
      ));
    }

    if (filteredRaffles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text('Aucun résultat',
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }


    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredRaffles.length,
        itemBuilder: (_, i) {
          final r = filteredRaffles[i];
          final claimed = r.status == 'claimed';
          return Column(children: [
            RaffleCard(
              raffle: r,
              isWon: true,
              isParticipating: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RaffleDetailScreen(raffle: r),
                ),
              ),
            ),
            if (!claimed)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: ElevatedButton.icon(
                  onPressed: () => _openClaimSheet(context, r),
                  icon: const Icon(Icons.redeem, size: 18),
                  label: const Text('Réclamer mon prix'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    minimumSize: const Size(double.infinity, 46),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text('Réclamation en cours de traitement',
                          style: TextStyle(color: Colors.green,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }

  void _openClaimSheet(BuildContext context, Raffle raffle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ClaimSheet(raffle: raffle),
    );
  }
}

// ─── Bottom Sheet Claim ───────────────────────────────────────────────────────
class _ClaimSheet extends StatefulWidget {
  final Raffle raffle;
  const _ClaimSheet({required this.raffle});
  @override
  State<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends State<_ClaimSheet> {
  String? _option;
  bool _useCurrentLocation = true;
  bool _fetchingLocation = false;
  
  // Données de localisation
  LatLng? _selectedPosition;
  String? _detectedCity;
  String? _detectedCountry;
  
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Si l'utilisateur choisit "Ma position" par défaut, on la récupère
    if (_useCurrentLocation) {
      _fetchCurrentLocation();
    }
  }

  /// Récupère la position GPS actuelle
  Future<void> _fetchCurrentLocation() async {
    setState(() => _fetchingLocation = true);

    final locationService = LocationService.instance;
    final position = await locationService.getCurrentPosition();

    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Impossible d\'obtenir votre position. Vérifiez vos paramètres.'),
            action: SnackBarAction(
              label: 'Paramètres',
              onPressed: () => locationService.openLocationSettings(),
            ),
          ),
        );
      }
      setState(() => _fetchingLocation = false);
      return;
    }

    // Récupérer ville et pays
    final location = await locationService.getCityAndCountry(
      position.latitude,
      position.longitude,
    );

    setState(() {
      _selectedPosition = LatLng(position.latitude, position.longitude);
      _detectedCity = location['city'];
      _detectedCountry = location['country'];
      _fetchingLocation = false;
    });
  }

  /// Ouvre la carte pour sélectionner une position
  Future<void> _openMapPicker() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );

    if (result != null) {
      setState(() => _fetchingLocation = true);

      final locationService = LocationService.instance;
      final location = await locationService.getCityAndCountry(
        result.latitude,
        result.longitude,
      );

      setState(() {
        _selectedPosition = result;
        _detectedCity = location['city'];
        _detectedCountry = location['country'];
        _fetchingLocation = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_option == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une option')));
      return;
    }

    // Validation pour la livraison
    if (_option == 'delivery') {
      if (_selectedPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez sélectionner une position de livraison')));
        return;
      }
    }

    setState(() => _submitting = true);
    final prov = context.read<RaffleProvider>();

    // Construire les options
    final options = <String, dynamic>{
      'claimOption': _option!,
    };

    if (_option == 'delivery' && _selectedPosition != null) {
      // Format : coordonnées GPS dans addressLine1 et addressLine2
      final coords = '${_selectedPosition!.latitude},${_selectedPosition!.longitude}';
      
      options['deliveryAddress'] = {
        'addressLine1': coords,  // Coordonnées GPS
        'addressLine2': coords,  // Répétées pour le livreur
        'city': _detectedCity ?? 'Ville inconnue',
        'postalCode': '0',
        'country': _detectedCountry ?? 'Pays inconnu',
      };
    }

    final ok = await prov.claimPrize(widget.raffle.id, options);

    setState(() => _submitting = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? '🎉 Réclamation soumise ! Le livreur sera redirigé vers votre position.'
            : prov.errorMessage ?? 'Erreur'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(
              child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),

          // Titre
          Row(children: [
            const Icon(Icons.emoji_events, color: AppTheme.secondaryColor),
            const SizedBox(width: 10),
            const Text('Réclamer votre prix',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Text(widget.raffle.title,
              style: AppTheme.bodyText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 20),

          // Options
          if (widget.raffle.cashOptionAvailable) ...[
            _optionCard(
              value: 'cash',
              icon: Icons.payments_outlined,
              title: 'Encaisser le montant',
              subtitle:
                  '${widget.raffle.cashAmount?.toStringAsFixed(0) ?? "—"} ${AppStrings.currency}',
              color: AppTheme.secondaryColor,
            ),
            const SizedBox(height: 12),
          ],

          _optionCard(
            value: 'delivery',
            icon: Icons.local_shipping_outlined,
            title: 'Recevoir le produit',
            subtitle: 'Livraison à votre position GPS',
            color: AppTheme.primaryColor,
          ),

          // Position de livraison
          if (_option == 'delivery') ...[
            const SizedBox(height: 20),
            const Text('Position de livraison',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),

            // Toggle
            Row(children: [
              Expanded(
                child: _locationChoice(
                  icon: Icons.my_location,
                  label: 'Ma position actuelle',
                  selected: _useCurrentLocation,
                  onTap: () {
                    setState(() => _useCurrentLocation = true);
                    if (_selectedPosition == null) {
                      _fetchCurrentLocation();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _locationChoice(
                  icon: Icons.map_outlined,
                  label: 'Autre position',
                  selected: !_useCurrentLocation,
                  onTap: () {
                    setState(() => _useCurrentLocation = false);
                    _openMapPicker();
                  },
                ),
              ),
            ]),

            const SizedBox(height: 12),

            // Affichage de la position
            if (_fetchingLocation)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Récupération de la position...',
                      style: TextStyle(fontSize: 13)),
                ]),
              )
            else if (_selectedPosition != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.location_on,
                          size: 20, color: Colors.green),
                      const SizedBox(width: 10),
                      const Text('Position sélectionnée',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: _useCurrentLocation
                            ? _fetchCurrentLocation
                            : _openMapPicker,
                        tooltip: 'Modifier',
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      'GPS: ${_selectedPosition!.latitude.toStringAsFixed(6)}, '
                      '${_selectedPosition!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (_detectedCity != null && _detectedCountry != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$_detectedCity, $_detectedCountry',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _useCurrentLocation
                    ? _fetchCurrentLocation
                    : _openMapPicker,
                icon: Icon(
                    _useCurrentLocation ? Icons.my_location : Icons.map,
                    size: 18),
                label: Text(_useCurrentLocation
                    ? 'Obtenir ma position'
                    : 'Sélectionner sur la carte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
              ),

            const SizedBox(height: 12),

            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline,
                    size: 16, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                  'Le livreur utilisera vos coordonnées GPS pour vous localiser précisément.',
                  style: TextStyle(fontSize: 12, color: AppTheme.primaryColor),
                )),
              ]),
            ),
          ],

          const SizedBox(height: 24),

          // Bouton
          ElevatedButton(
            onPressed: (_option == null || _submitting) ? null : _submit,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor),
            child: _submitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Confirmer la réclamation',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _optionCard({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final selected = _option == value;
    return GestureDetector(
      onTap: () => setState(() => _option = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.grey.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected
                  ? color.withOpacity(0.15)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: selected ? color : AppTheme.textSecondary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? color : AppTheme.textPrimary)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
          )),
          if (selected) Icon(Icons.check_circle, color: color, size: 22),
        ]),
      ),
    );
  }

  Widget _locationChoice({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor
                : Colors.grey.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon,
              color: selected
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary,
              size: 22),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3 : TOMBOLAS CRÉÉES (STORE OWNERS ONLY)
// ═══════════════════════════════════════════════════════════════════════════════

class _CreatedRafflesTab extends StatelessWidget {
  final List<Raffle> raffles;
  final Future<void> Function() onRefresh;
  final String searchQuery;
  final String? statusFilter;
  final String sortBy;
  
  const _CreatedRafflesTab({
    required this.raffles,
    required this.onRefresh,
    required this.searchQuery,
    required this.statusFilter,
    required this.sortBy,
  });

  List<Raffle> _applyFilters(List<Raffle> list) {
    var filtered = list;

    // Recherche
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where((r) =>
              r.title.toLowerCase().contains(searchQuery) ||
              (r.product?.name.toLowerCase().contains(searchQuery) ?? false))
          .toList();
    }

    // Filtre par statut
    if (statusFilter != null) {
      filtered = filtered.where((r) => r.status == statusFilter).toList();
    }

    // Tri
    switch (sortBy) {
      case 'date_asc':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'date_desc':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'price_asc':
        filtered.sort((a, b) => a.entryPrice.compareTo(b.entryPrice));
        break;
      case 'price_desc':
        filtered.sort((a, b) => b.entryPrice.compareTo(a.entryPrice));
        break;
    }

    return filtered;
  }


  //@override
  /* Widget build(BuildContext context) {
    final filteredRaffles = _applyFilters(raffles);

    if (raffles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            const Text("Vous n'avez créé aucune tombola",
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            const Text('Appuyez sur + pour en créer une',
                style: AppTheme.caption),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredRaffles.length,
        itemBuilder: (_, i) => _MyRaffleCard(raffle: filteredRaffles[i]),
      ),
    );
  } */

  @override
  Widget build(BuildContext context) {
    final filteredRaffles = _applyFilters(raffles);

    if (raffles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            const Text("Vous n'avez créé aucune tombola",
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            const Text('Appuyez sur + pour en créer une',
                style: AppTheme.caption),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.05),
              Colors.white.withOpacity(0.1),
            ],
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredRaffles.length,
            itemBuilder: (_, i) => _MyRaffleCardGlass(raffle: filteredRaffles[i]),
          ),
        ),
      ),
    );
  }
}

// ─── Card pour les tombolas créées ─────────────────────────────────────────────
/* class _MyRaffleCard extends StatelessWidget {
  final Raffle raffle;
  const _MyRaffleCard({required this.raffle});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RaffleDetailScreen(raffle: raffle)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre + status badge
              Row(children: [
                Expanded(
                  child: Text(
                    raffle.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _statusBadge(raffle.status),
              ]),
              const SizedBox(height: 10),

              // Stats
              Row(children: [
                const Icon(Icons.people_outline, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text('${raffle.currentParticipants}/${raffle.maxParticipants}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(width: 16),
                const Icon(Icons.payments_outlined, size: 16, color: AppTheme.secondaryColor),
                const SizedBox(width: 6),
                Text('${raffle.entryPrice.toStringAsFixed(0)} ${AppStrings.currency}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryColor)),
                const Spacer(),
                if (raffle.autoDrawEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.auto_mode, size: 12, color: AppTheme.primaryColor),
                      SizedBox(width: 4),
                      Text('Auto', style: TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 10),

              // Barre de progression
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: raffle.fillPercentage,
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(AppTheme.getProbabilityColor(raffle.probabilityType)),
                ),
              ),
              const SizedBox(height: 12),

              // Actions
              Row(children: [
                // Bouton tirer au sort (si full et status open)
                if (raffle.isFull && raffle.status == 'open')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _drawWinner(context, raffle),
                      icon: const Icon(Icons.shuffle, size: 16),
                      label: const Text('Tirer au sort'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.highProbabilityColor,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                if (raffle.isFull && raffle.status == 'open') const SizedBox(width: 8),

                // Bouton annuler (si status open)
                if (raffle.status == 'open')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmCancel(context, raffle),
                      icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                      label: const Text('Annuler cette tombola', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        //backgroundColor: Colors.red.withOpacity(0.9),
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }



  Widget _statusBadge(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'open':
        color = Colors.green;
        label = 'Ouvert';
        icon = Icons.check_circle;
        break;
      case 'full':
        color = Colors.orange;
        label = 'Complet';
        icon = Icons.lock;
        break;
      case 'completed':
        color = Colors.blue;
        label = 'Terminé';
        icon = Icons.done_all;
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Annulé';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        label = status;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  void _confirmCancel(BuildContext context, Raffle raffle) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la tombola'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Voulez-vous vraiment annuler cette tombola ?'),
          if (raffle.currentParticipants > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                  '${raffle.currentParticipants} participant${raffle.currentParticipants > 1 ? "s" : ""} '
                  'ser${raffle.currentParticipants > 1 ? "ont" : "a"} remboursé${raffle.currentParticipants > 1 ? "s" : ""}',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                )),
              ]),
            ),
          ],
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelRaffle(context, raffle);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRaffle(BuildContext context, Raffle raffle) async {
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUser?.id;
      if (userId == null) return;
      
      final prov = context.read<RaffleProvider>();
      final ok = await prov.cancelRaffle(raffle.id, userId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Tombola annulée avec succès' : prov.errorMessage ?? 'Erreur'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));

        if (ok) {
          prov.fetchMyCreatedRaffles(userId);
          prov.fetchAll();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _drawWinner(BuildContext context, Raffle raffle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tirer au sort'),
        content: const Text(
            'Voulez-vous lancer le tirage au sort maintenant ?\n\n'
            'Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
            child: const Text('Tirer au sort'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUser?.id;
      if (userId == null) return;
      
      final prov = context.read<RaffleProvider>();
      final ok = await prov.drawWinner(raffle.id, userId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '🎉 Gagnant tiré au sort avec succès !' : prov.errorMessage ?? 'Erreur'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));

        if (ok) {
          prov.fetchMyCreatedRaffles(userId);
          prov.fetchAll();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
 */

class _MyRaffleCardGlass extends StatelessWidget {
  final Raffle raffle;
  const _MyRaffleCardGlass({required this.raffle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RaffleDetailScreen(raffle: raffle)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre + status badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              raffle.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.primaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusBadge(raffle.status),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Stats
                      Row(
                        children: [
                          // Participants
                          Row(
                            children: [
                              const Icon(Icons.people_outline,
                                  size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 6),
                              Text(
                                '${raffle.currentParticipants}/${raffle.maxParticipants}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),

                          // Prix d'entrée
                          Row(
                            children: [
                              const Icon(Icons.payments_outlined,
                                  size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 6),
                              Text(
                                '${raffle.entryPrice.toStringAsFixed(0)} ${AppStrings.currency}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),

                          // Badge Auto
                          if (raffle.autoDrawEnabled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_mode, size: 12, color: AppTheme.primaryColor),
                                  SizedBox(width: 4),
                                  Text('AUTO',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Barre de progression + probabilité
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Barre de progression
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.08)),
                                borderRadius: BorderRadius.circular(6),
                                color: Colors.white.withOpacity(0.2),
                              ),
                              child: LinearProgressIndicator(
                                value: raffle.fillPercentage,
                                minHeight: 8,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.getProbabilityColor(raffle.probabilityType),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Légende de probabilité
                          Row(
                            children: [
                              Icon(
                                _getProbabilityIcon(raffle.probabilityType),
                                size: 14,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getProbabilityLabel(raffle.probabilityType),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${(raffle.fillPercentage * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Actions
                      if (raffle.isFull && raffle.status == 'open' || raffle.status == 'open')
                        Stack(
                          children: [
                            // Bouton "Tirer au sort" (en bas à gauche)
                            if (raffle.isFull && raffle.status == 'open')
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Padding(
                                  padding: const EdgeInsets.all(0.1),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: AppTheme.getProbabilityColor(raffle.probabilityType).withOpacity(0.6) != null
                                          ? Border.all(color: AppTheme.getProbabilityColor(raffle.probabilityType).withOpacity(0.6))
                                          : null,
                                      color: Colors.white.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: TextButton.icon(
                                      onPressed: () => _drawWinner(context, raffle),
                                      icon: Icon(Icons.shuffle, size: 16, color: AppTheme.primaryColor),
                                      label: Text('Tirer au sort',
                                          style: TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // Bouton "Annuler" (en bas à droite - ton code existant)
                            if (raffle.status == 'open')
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(0.1),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Colors.redAccent.withOpacity(0.6) != null
                                          ? Border.all(color: Colors.redAccent.withOpacity(0.6))
                                          : null,
                                      color: Colors.white.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: TextButton.icon(
                                      onPressed: () => _confirmCancel(context, raffle),
                                      icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
                                      label: const Text('Annuler cette tombola',
                                          style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
   Widget _statusBadge(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'open':
        color = Colors.greenAccent;
        label = 'OUVERT';
        icon = Icons.check_circle;
        break;
      case 'full':
        color = Colors.orangeAccent;
        label = 'COMPLET';
        icon = Icons.lock;
        break;
      case 'completed':
        color = Colors.blueAccent;
        label = 'TIRÉ';
        icon = Icons.done_all;
        break;
      case 'cancelled':
        color = Colors.redAccent;
        label = 'ANNULÉ';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        label = status.toUpperCase();
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              )),
        ],
      ),
    );
  }

  IconData _getProbabilityIcon(String type) {
    switch (type) {
      case 'high':
        return Icons.star;
      case 'medium':
        return Icons.adjust;
      default:
        return Icons.casino;
    }
  }

  String _getProbabilityLabel(String type) {
    switch (type) {
      case 'high':
        return 'FORTE CHANCE';
      case 'medium':
        return 'CHANCE MOYENNE';
      default:
        return 'FAIBLE CHANCE';
    }
  }

  void _confirmCancel(BuildContext context, Raffle raffle) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la tombola'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Voulez-vous vraiment annuler cette tombola ?'),
          if (raffle.currentParticipants > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                  '${raffle.currentParticipants} participant${raffle.currentParticipants > 1 ? "s" : ""} '
                  'ser${raffle.currentParticipants > 1 ? "ont" : "a"} remboursé${raffle.currentParticipants > 1 ? "s" : ""}',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                )),
              ]),
            ),
          ],
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelRaffle(context, raffle);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRaffle(BuildContext context, Raffle raffle) async {
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUser?.id;
      if (userId == null) return;
      
      final prov = context.read<RaffleProvider>();
      final ok = await prov.cancelRaffle(raffle.id, userId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Tombola annulée avec succès' : prov.errorMessage ?? 'Erreur'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));

        if (ok) {
          prov.fetchMyCreatedRaffles(userId);
          prov.fetchAll();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _drawWinner(BuildContext context, Raffle raffle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tirer au sort'),
        content: const Text(
            'Voulez-vous lancer le tirage au sort maintenant ?\n\n'
            'Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
            child: const Text('Tirer au sort'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUser?.id;
      if (userId == null) return;
      
      final prov = context.read<RaffleProvider>();
      final ok = await prov.drawWinner(raffle.id, userId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '🎉 Gagnant tiré au sort avec succès !' : prov.errorMessage ?? 'Erreur'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));

        if (ok) {
          prov.fetchMyCreatedRaffles(userId);
          prov.fetchAll();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}