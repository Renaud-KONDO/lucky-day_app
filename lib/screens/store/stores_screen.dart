import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/store_card.dart';
import 'create_store_screen.dart';
import 'store_detail_screen.dart';


class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});
  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> with SingleTickerProviderStateMixin  {
  late TabController _tab;
  //final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (_tab.index == 1 && !_tab.indexIsChanging) {
        context.read<StoreProvider>().fetchMyStores();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().fetchStores();
    });
  }

  @override
  void dispose() { super.dispose(); }
  //void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boutiques'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Toutes les boutiques'),
            Tab(text: 'Mes boutiques'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          const _AllStoresTab(),
          const _MyStoresTab(),
        ],
      ),
    );
  }

}

// ─── Tab : Toutes les boutiques ───────────────────────────────────────────────
class _AllStoresTab extends StatefulWidget {
  const _AllStoresTab();
  @override
  State<_AllStoresTab> createState() => _AllStoresTabState();
}

class _AllStoresTabState extends State<_AllStoresTab> {
  final _searchCtrl = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().fetchStoreCategories();
      context.read<StoreProvider>().fetchStores();
    });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _applyFilters() {
    context.read<StoreProvider>().fetchStores(
      search: _searchCtrl.text.isEmpty ? null : _searchCtrl.text,
      categoryId: _selectedCategoryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().storeCategories;

    return Column(children: [
      // Barre recherche
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Rechercher une boutique...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _applyFilters();
                    })
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (_) => _applyFilters(),
        ),
      ),

      // Chips catégories horizontales
      if (categories.isNotEmpty)
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: categories.length + 1, // +1 pour "Toutes"
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final isAll = i == 0;
              final cat = isAll ? null : categories[i - 1];
              final selected = isAll
                  ? _selectedCategoryId == null
                  : _selectedCategoryId == cat!.id;

              return ChoiceChip(
                label: Text(isAll ? 'Toutes' : cat!.name,
                    style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : AppTheme.textPrimary,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal)),
                selected: selected,
                selectedColor: AppTheme.primaryColor,
                backgroundColor: Colors.white,
                side: BorderSide(
                    color: selected
                        ? AppTheme.primaryColor
                        : Colors.grey.withOpacity(0.3)),
                onSelected: (_) {
                  setState(() {
                    _selectedCategoryId = isAll ? null : cat!.id;
                    _selectedCategoryName = isAll ? null : cat!.name;
                  });
                  _applyFilters();
                },
              );
            },
          ),
        ),

      // Chip filtre actif
      if (_selectedCategoryId != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(children: [
            Chip(
              label: Text(_selectedCategoryName ?? '',
                  style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () {
                setState(() { _selectedCategoryId = null; _selectedCategoryName = null; });
                _applyFilters();
              },
              backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
              side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.2)),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() { _selectedCategoryId = null; _selectedCategoryName = null; });
                _searchCtrl.clear();
                _applyFilters();
              },
              child: const Text('Réinitialiser',
                  style: TextStyle(fontSize: 12, color: Colors.red)),
            ),
          ]),
        ),

      // Liste
      Expanded(
        child: Consumer<StoreProvider>(
          builder: (_, prov, __) {
            if (prov.isLoading) return const Center(child: CircularProgressIndicator());
            if (prov.stores.isEmpty) return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.store, size: 64, color: AppTheme.textSecondary),
                SizedBox(height: 12),
                Text('Aucune boutique trouvée', style: AppTheme.bodyText),
              ]),
            );
            return RefreshIndicator(
              onRefresh: () => prov.fetchStores(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: prov.stores.length,
                itemBuilder: (_, i) => StoreCard(
                  store: prov.stores[i],
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                      builder: (_) => StoreDetailScreen(store: prov.stores[i]))),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

/* class _AllStoresTab extends StatelessWidget {
  final TextEditingController searchCtrl;
  const _AllStoresTab({required this.searchCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Barre de recherche
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: searchCtrl,
          decoration: InputDecoration(
            hintText: 'Rechercher une boutique...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchCtrl.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                  searchCtrl.clear();
                  context.read<StoreProvider>().fetchStores();
                })
              : null,
          ),
          onChanged: (v) => context.read<StoreProvider>().fetchStores(search: v.isEmpty ? null : v),
        ),
      ),
      Expanded(
        child: Consumer<StoreProvider>(
          builder: (_, prov, __) {
            if (prov.isLoading) return const Center(child: CircularProgressIndicator());
            if (prov.stores.isEmpty) return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.store, size: 64, color: AppTheme.textSecondary),
                SizedBox(height: 12),
                Text('Aucune boutique trouvée', style: AppTheme.bodyText),
              ]),
            );
            return RefreshIndicator(
              onRefresh: () => prov.fetchStores(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: prov.stores.length,
                itemBuilder: (_, i) => StoreCard(store: prov.stores[i], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreDetailScreen(store: prov.stores[i]))),),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
 */
// ─── Tab : Mes boutiques ──────────────────────────────────────────────────────
class _MyStoresTab extends StatelessWidget {
  const _MyStoresTab();

  void _onCreateTap(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    if (!user.isStoreOwner) {
      // Pas store_owner → demande de rôle
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.lock_outline, color: AppTheme.primaryColor),
            SizedBox(width: 10),
            Text('Accès requis'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'Pour créer une boutique, vous devez être déclaré "businessman".',
              style: AppTheme.bodyText,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Contactez un administrateur pour vous déclarer en tant que businessman .',
                  style: TextStyle(fontSize: 12, color: AppTheme.primaryColor),
                )),
              ]),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
              child: const Text('Faire une demande'),
            ),
          ],
        ),
      );
    } else {
      // Est store_owner → ouvrir le formulaire
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStoreScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StoreProvider>(
      builder: (_, prov, __) {
        if (prov.isLoading) return const Center(child: CircularProgressIndicator());
        return Column(children: [
          // Bouton créer boutique
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _onCreateTap(context),
              icon: const Icon(Icons.add),
              label: const Text('Créer une boutique'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          Expanded(
            child: prov.myStores.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.store_mall_directory_outlined, size: 64, color: AppTheme.textSecondary),
                  SizedBox(height: 12),
                  Text("Vous n'avez pas encore de boutique", style: AppTheme.bodyText),
                  SizedBox(height: 6),
                  Text('Créez votre première boutique !', style: AppTheme.caption),
                ]))
              : RefreshIndicator(
                  onRefresh: () => prov.fetchMyStores(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: prov.myStores.length,
                    itemBuilder: (_, i) => StoreCard(store: prov.myStores[i], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreDetailScreen(store: prov.myStores[i]))),),
                  ),
                ),
          ),
        ]);
      },
    );
  }
}

