/* import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/raffle_provider.dart';
import '../../providers/store_provider.dart';
import '../../data/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class CreateRaffleScreen extends StatefulWidget {
  const CreateRaffleScreen({super.key});

  @override
  State<CreateRaffleScreen> createState() => _CreateRaffleScreenState();
}

class _CreateRaffleScreenState extends State<CreateRaffleScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _maxParticipantsCtrl = TextEditingController();
  final _cashAmountCtrl = TextEditingController();
  final _storeSearchCtrl = TextEditingController();
  final _productSearchCtrl = TextEditingController();
  
  // Sélections
  Store? _selectedStore;
  Product? _selectedProduct;
  String _probabilityType = 'medium';
  bool _cashOptionAvailable = false;
  bool _autoDrawEnabled = false;
  String _autoDrawType = 'instant';
  DateTime? _autoDrawAt;
  
  // Loading states
  bool _loadingStores = true;
  bool _loadingProducts = false;
  bool _submitting = false;
  
  // Listes
  List<Store> _myStores = [];
  List<Store> _filteredStores = [];
  List<Product> _storeProducts = [];
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _loadMyStores();
    
    // Écouter les changements de recherche
    _storeSearchCtrl.addListener(_filterStores);
    _productSearchCtrl.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _maxParticipantsCtrl.dispose();
    _cashAmountCtrl.dispose();
    _storeSearchCtrl.dispose();
    _productSearchCtrl.dispose();
    super.dispose();
  }

  /// Charge les boutiques de l'utilisateur
  Future<void> _loadMyStores() async {
    setState(() => _loadingStores = true);
    try {
      await context.read<StoreProvider>().fetchMyStores();
      final stores = context.read<StoreProvider>().myStores;
      setState(() {
        _myStores = stores;
        _filteredStores = stores;
      });
    } catch (e) {
      print('❌ Error loading stores: $e');
    }
    setState(() => _loadingStores = false);
  }

  /// Charge les produits d'une boutique
  Future<void> _loadStoreProducts(String storeId) async {
    setState(() => _loadingProducts = true);
    try {
      await context.read<StoreProvider>().fetchStoreProducts(storeId);
      final products = context.read<StoreProvider>().products;
      setState(() {
        _storeProducts = products;
        _filteredProducts = products;
        _selectedProduct = null; // Reset la sélection de produit
      });
    } catch (e) {
      print('❌ Error loading products: $e');
    }
    setState(() => _loadingProducts = false);
  }

  void _filterStores() {
    final query = _storeSearchCtrl.text.toLowerCase();
    setState(() {
      _filteredStores = _myStores
          .where((s) => s.name.toLowerCase().contains(query))
          .toList();
    });
  }

  void _filterProducts() {
    final query = _productSearchCtrl.text.toLowerCase();
    setState(() {
      _filteredProducts = _storeProducts
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
    });
  }

  void _showStoreSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _StoreSelector(
        stores: _filteredStores,
        searchController: _storeSearchCtrl,
        onSelect: (store) {
          setState(() {
            _selectedStore = store;
            _storeSearchCtrl.clear();
          });
          Navigator.pop(context);
          _loadStoreProducts(store.id);
        },
      ),
    );
  }

  void _showProductSelector() {
    if (_selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord sélectionner une boutique')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProductSelector(
        products: _filteredProducts,
        searchController: _productSearchCtrl,
        loading: _loadingProducts,
        onSelect: (product) {
          setState(() {
            _selectedProduct = product;
            _productSearchCtrl.clear();
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _pickAutoDrawDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    if (mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _autoDrawAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une boutique')),
      );
      return;
    }

    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un produit')),
      );
      return;
    }

    if (_cashOptionAvailable && _cashAmountCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer le montant cash')),
      );
      return;
    }

    if (_autoDrawEnabled &&
        _autoDrawType == 'scheduled' &&
        _autoDrawAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner la date du tirage')),
      );
      return;
    }

    setState(() => _submitting = true);

    final auth = context.read<AuthProvider>();
      final userId = auth.currentUser?.id;

    final data = {
      'raffleType': 'product',
      'productId': _selectedProduct!.id,
      'storeId': _selectedStore!.id,
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'probabilityType': _probabilityType,
      'entryPrice': double.parse(_priceCtrl.text),
      'maxParticipants': int.parse(_maxParticipantsCtrl.text),
      'cashOptionAvailable': _cashOptionAvailable,
      if (_cashOptionAvailable)
        'cashAmount': double.parse(_cashAmountCtrl.text),
      'autoDrawEnabled': _autoDrawEnabled,
      if (_autoDrawEnabled) 'autoDrawType': _autoDrawType,
      if (_autoDrawEnabled && _autoDrawType == 'scheduled' && _autoDrawAt != null)
        'autoDrawAt': _autoDrawAt!.toIso8601String(),
      'userId': userId,
    };

    final prov = context.read<RaffleProvider>();
    final ok = await prov.createRaffle(data);

    setState(() => _submitting = false);

    if (mounted) {
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Tombola créée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(prov.errorMessage ?? 'Erreur de création'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une tombola'),
      ),
      body: _loadingStores
          ? const Center(child: CircularProgressIndicator())
          : _myStores.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.store_outlined,
                          size: 64, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      const Text('Vous n\'avez aucune boutique',
                          style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      const Text('Créez une boutique pour commencer',
                          style: AppTheme.caption),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Retour'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ══════════════════════════════════════════════════
                        // SÉLECTION BOUTIQUE
                        // ══════════════════════════════════════════════════
                        const Text('Boutique *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _showStoreSelector,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              const Icon(Icons.store,
                                  color: AppTheme.primaryColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedStore?.name ??
                                      'Sélectionner une boutique',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _selectedStore != null
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ══════════════════════════════════════════════════
                        // SÉLECTION PRODUIT
                        // ══════════════════════════════════════════════════
                        const Text('Produit à gagner *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _showProductSelector,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              const Icon(Icons.card_giftcard,
                                  color: AppTheme.secondaryColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _loadingProducts
                                    ? const Text('Chargement...',
                                        style: TextStyle(fontSize: 15))
                                    : Text(
                                        _selectedProduct?.name ??
                                            'Sélectionner un produit',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: _selectedProduct != null
                                              ? AppTheme.textPrimary
                                              : AppTheme.textSecondary,
                                        ),
                                      ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16),
                            ]),
                          ),
                        ),

                        if (_selectedProduct != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              const Icon(Icons.info_outline,
                                  size: 16, color: AppTheme.secondaryColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Valeur: ${_selectedProduct!.price.toStringAsFixed(0)} ${AppStrings.currency}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.secondaryColor,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // ══════════════════════════════════════════════════
                        // INFORMATIONS TOMBOLA
                        // ══════════════════════════════════════════════════
                        const Text('Informations de la tombola',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 14),

                        // Titre
                        TextFormField(
                          controller: _titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Titre de la tombola *',
                            hintText: 'Ex: iPhone 15 Pro - Tombola Premium',
                            prefixIcon: Icon(Icons.title),
                          ),
                          validator: (v) =>
                              v == null || v.trim().length < 5
                                  ? 'Minimum 5 caractères'
                                  : null,
                        ),
                        const SizedBox(height: 14),

                        // Description
                        TextFormField(
                          controller: _descCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description (optionnel)',
                            hintText: 'Décrivez votre tombola...',
                            prefixIcon: Icon(Icons.description),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Prix d'entrée et Max participants
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Prix d\'entrée (XOF) *',
                                prefixIcon: Icon(Icons.payments),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requis';
                                final price = double.tryParse(v);
                                if (price == null) return 'Nombre invalide';
                                if (price < 100) return 'Min 100 XOF';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _maxParticipantsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Max participants *',
                                prefixIcon: Icon(Icons.people),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requis';
                                final max = int.tryParse(v);
                                if (max == null) return 'Nombre invalide';
                                if (max < 2 || max > 10000)
                                  return '2-10000';
                                return null;
                              },
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),

                        // ══════════════════════════════════════════════════
                        // PROBABILITÉ
                        // ══════════════════════════════════════════════════
                        const Text('Type de probabilité *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 10, children: [
                          ChoiceChip(
                            label: const Text('⭐ Forte'),
                            selected: _probabilityType == 'high',
                            onSelected: (v) =>
                                setState(() => _probabilityType = 'high'),
                            selectedColor: Colors.green.withOpacity(0.3),
                          ),
                          ChoiceChip(
                            label: const Text('🎯 Moyenne'),
                            selected: _probabilityType == 'medium',
                            onSelected: (v) =>
                                setState(() => _probabilityType = 'medium'),
                            selectedColor: Colors.orange.withOpacity(0.3),
                          ),
                          ChoiceChip(
                            label: const Text('🎲 Faible'),
                            selected: _probabilityType == 'low',
                            onSelected: (v) =>
                                setState(() => _probabilityType = 'low'),
                            selectedColor: Colors.red.withOpacity(0.3),
                          ),
                        ]),
                        const SizedBox(height: 20),

                        // ══════════════════════════════════════════════════
                        // OPTION CASH
                        // ══════════════════════════════════════════════════
                        SwitchListTile(
                          title: const Text('Option cash disponible'),
                          subtitle: const Text(
                              'Permettre au gagnant d\'encaisser l\'argent'),
                          value: _cashOptionAvailable,
                          onChanged: (v) =>
                              setState(() => _cashOptionAvailable = v),
                          contentPadding: EdgeInsets.zero,
                        ),

                        if (_cashOptionAvailable) ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _cashAmountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Montant cash (XOF) *',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            validator: (v) {
                              if (_cashOptionAvailable) {
                                if (v == null || v.isEmpty) return 'Requis';
                                if (double.tryParse(v) == null)
                                  return 'Nombre invalide';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 20),

                        // ══════════════════════════════════════════════════
                        // TIRAGE AUTOMATIQUE
                        // ══════════════════════════════════════════════════
                        SwitchListTile(
                          title: const Text('Tirage automatique'),
                          subtitle: const Text(
                              'Tirer au sort automatiquement quand c\'est plein'),
                          value: _autoDrawEnabled,
                          onChanged: (v) =>
                              setState(() => _autoDrawEnabled = v),
                          contentPadding: EdgeInsets.zero,
                        ),

                        if (_autoDrawEnabled) ...[
                          const SizedBox(height: 10),
                          Wrap(spacing: 10, children: [
                            ChoiceChip(
                              label: const Text('Instantané'),
                              selected: _autoDrawType == 'instant',
                              onSelected: (v) =>
                                  setState(() => _autoDrawType = 'instant'),
                            ),
                            ChoiceChip(
                              label: const Text('Programmé'),
                              selected: _autoDrawType == 'scheduled',
                              onSelected: (v) =>
                                  setState(() => _autoDrawType = 'scheduled'),
                            ),
                          ]),

                          if (_autoDrawType == 'scheduled') ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _pickAutoDrawDate,
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: Text(_autoDrawAt == null
                                  ? 'Sélectionner la date du tirage'
                                  : 'Tirage le ${_autoDrawAt!.day}/${_autoDrawAt!.month}/${_autoDrawAt!.year} à ${_autoDrawAt!.hour}h${_autoDrawAt!.minute.toString().padLeft(2, '0')}'),
                            ),
                          ],
                        ],

                        const SizedBox(height: 32),

                        // ══════════════════════════════════════════════════
                        // BOUTON CRÉER
                        // ══════════════════════════════════════════════════
                        ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryColor,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Créer la tombola',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET : SÉLECTION BOUTIQUE
// ═══════════════════════════════════════════════════════════════════════════════

class _StoreSelector extends StatelessWidget {
  final List<Store> stores;
  final TextEditingController searchController;
  final Function(Store) onSelect;

  const _StoreSelector({
    required this.stores,
    required this.searchController,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(
            child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 16),

        // Titre
        const Text('Sélectionner une boutique',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // Recherche
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Rechercher...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),

        // Liste
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: stores.isEmpty
              ? const Center(child: Text('Aucune boutique trouvée'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: stores.length,
                  itemBuilder: (_, i) {
                    final store = stores[i];
                    return ListTile(
                      leading: const Icon(Icons.store,
                          color: AppTheme.primaryColor),
                      title: Text(store.name),
                      subtitle: Text(store.description ?? ''),
                      onTap: () => onSelect(store),
                    );
                  },
                ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET : SÉLECTION PRODUIT
// ═══════════════════════════════════════════════════════════════════════════════

class _ProductSelector extends StatelessWidget {
  final List<Product> products;
  final TextEditingController searchController;
  final bool loading;
  final Function(Product) onSelect;

  const _ProductSelector({
    required this.products,
    required this.searchController,
    required this.loading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(
            child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 16),

        // Titre
        const Text('Sélectionner un produit',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // Recherche
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Rechercher...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),

        // Liste
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : products.isEmpty
                  ? const Center(
                      child: Text('Aucun produit dans cette boutique'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: products.length,
                      itemBuilder: (_, i) {
                        final product = products[i];
                        return ListTile(
                          leading: product.imageUrls.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    product.imageUrls.first,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.image_not_supported),
                                  ),
                                )
                              : const Icon(Icons.inventory_2_outlined),
                          title: Text(product.name),
                          subtitle: Text(
                              '${product.price.toStringAsFixed(0)} ${AppStrings.currency}'),
                          onTap: () => onSelect(product),
                        );
                      },
                    ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
} */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/raffle_provider.dart';
import '../../providers/store_provider.dart';
import '../../data/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class CreateRaffleScreen extends StatefulWidget {
  const CreateRaffleScreen({super.key});

  @override
  State<CreateRaffleScreen> createState() => _CreateRaffleScreenState();
}

class _CreateRaffleScreenState extends State<CreateRaffleScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _maxParticipantsCtrl = TextEditingController();
  final _storeSearchCtrl = TextEditingController();
  final _productSearchCtrl = TextEditingController();
  final _autoDrawDelayCtrl = TextEditingController(text: '0');
  
  // Sélections
  Store? _selectedStore;
  Product? _selectedProduct;
  String _probabilityType = 'medium'; // Calculé automatiquement
  bool _cashOptionAvailable = false;
  bool _autoDrawEnabled = false;
  String _autoDrawType = 'immediate'; // immediate | delay
  
  // Loading states
  bool _loadingStores = true;
  bool _loadingProducts = false;
  bool _submitting = false;
  bool _calculatingPrice = false; // Pour éviter les boucles infinies
  bool _calculatingParticipants = false;
  
  // Listes
  List<Store> _myStores = [];
  List<Store> _filteredStores = [];
  List<Product> _storeProducts = [];
  List<Product> _filteredProducts = [];

  // Commission calculation
  double? _calculatedCommission;
  double? _calculatedRevenue;
  String? _commissionWarning;

  @override
  void initState() {
    super.initState();
    _loadMyStores();
    
    // Écouter les changements de recherche
    _storeSearchCtrl.addListener(_filterStores);
    _productSearchCtrl.addListener(_filterProducts);
    
    // Écouter les changements de prix et participants pour calculer automatiquement
    _priceCtrl.addListener(_onEntryPriceChanged);
    _maxParticipantsCtrl.addListener(_onMaxParticipantsChanged);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _maxParticipantsCtrl.dispose();
    _storeSearchCtrl.dispose();
    _productSearchCtrl.dispose();
    _autoDrawDelayCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CALCULS AUTOMATIQUES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Détermine le % de commission minimum selon le prix du produit
  double _getMinCommissionPercentage(double productPrice) {
    if (productPrice <= 10000) {
      return 50.0; // 50% pour produits ≤ 10,000 XOF
    } else if (productPrice <= 100000) {
      return 30.0; // 30% pour produits entre 10,001 et 100,000 XOF
    } else {
      return 10.0; // 10% pour produits > 100,000 XOF
    }
  }

  /// Calcule le nombre de participants requis quand le prix d'entrée change
  void _onEntryPriceChanged() {
    if (_calculatingPrice || _selectedProduct == null) return;
    
    final entryPriceText = _priceCtrl.text.trim();
    if (entryPriceText.isEmpty) {
      setState(() {
        _calculatedCommission = null;
        _calculatedRevenue = null;
        _commissionWarning = null;
        _probabilityType = 'medium';
      });
      return;
    }

    final entryPrice = double.tryParse(entryPriceText);
    if (entryPrice == null || entryPrice < 100) return;

    final productPrice = _selectedProduct!.price;
    final minCommission = _getMinCommissionPercentage(productPrice);

    // Calculer le nombre de participants requis
    // E × N ≥ P + (P × minCommission%)
    // N ≥ (P × (1 + minCommission%)) / E
    final totalNeeded = productPrice * (1 + minCommission / 100);
    final requiredParticipants = (totalNeeded / entryPrice).ceil();

    // Mettre à jour le champ participants (sans déclencher son listener)
    _calculatingParticipants = true;
    _maxParticipantsCtrl.text = requiredParticipants.toString();
    _calculatingParticipants = false;

    // Calculer la commission et le type de probabilité
    _updateCommissionAndProbability(entryPrice, requiredParticipants.toDouble(), productPrice, minCommission);
  }

  /// Calcule le prix d'entrée requis quand le nombre de participants change
  void _onMaxParticipantsChanged() {
    if (_calculatingParticipants || _selectedProduct == null) return;

    final participantsText = _maxParticipantsCtrl.text.trim();
    if (participantsText.isEmpty) {
      setState(() {
        _calculatedCommission = null;
        _calculatedRevenue = null;
        _commissionWarning = null;
        _probabilityType = 'medium';
      });
      return;
    }

    final maxParticipants = int.tryParse(participantsText);
    if (maxParticipants == null || maxParticipants < 2) return;

    final productPrice = _selectedProduct!.price;
    final minCommission = _getMinCommissionPercentage(productPrice);

    // Calculer le prix d'entrée requis
    // E × N ≥ P × (1 + minCommission%)
    // E ≥ (P × (1 + minCommission%)) / N
    final totalNeeded = productPrice * (1 + minCommission / 100);
    final requiredEntryPrice = (totalNeeded / maxParticipants).ceil().toDouble();

    // Mettre à jour le champ prix (sans déclencher son listener)
    _calculatingPrice = true;
    _priceCtrl.text = requiredEntryPrice.toStringAsFixed(0);
    _calculatingPrice = false;

    // Calculer la commission et le type de probabilité
    _updateCommissionAndProbability(requiredEntryPrice, maxParticipants.toDouble(), productPrice, minCommission);
  }

  /// Met à jour les calculs de commission et détermine le type de probabilité
  void _updateCommissionAndProbability(
    double entryPrice,
    double maxParticipants,
    double productPrice,
    double minCommissionPercentage,
  ) {
    final totalRevenue = entryPrice * maxParticipants;
    final commission = totalRevenue - productPrice;
    final commissionPercentage = (commission / productPrice) * 100;

    // Déterminer le type de probabilité automatiquement
    String newProbabilityType;
    if (entryPrice >= productPrice * 0.20) {
      newProbabilityType = 'high';
    } else if (entryPrice >= productPrice * 0.10) {
      newProbabilityType = 'medium';
    } else {
      newProbabilityType = 'low';
    }

    // Vérifier si la commission est suffisante
    String? warning;
    if (commissionPercentage < minCommissionPercentage) {
      warning = '⚠️ Commission trop faible (${commissionPercentage.toStringAsFixed(1)}%). Minimum requis: ${minCommissionPercentage.toStringAsFixed(0)}%';
    }

    setState(() {
      _calculatedRevenue = totalRevenue;
      _calculatedCommission = commission;
      _commissionWarning = warning;
      _probabilityType = newProbabilityType;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHARGEMENT DONNÉES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadMyStores() async {
    setState(() => _loadingStores = true);
    try {
      await context.read<StoreProvider>().fetchMyStores();
      final stores = context.read<StoreProvider>().myStores;
      setState(() {
        _myStores = stores;
        _filteredStores = stores;
      });
    } catch (e) {
      print('❌ Error loading stores: $e');
    }
    setState(() => _loadingStores = false);
  }

  Future<void> _loadStoreProducts(String storeId) async {
    setState(() => _loadingProducts = true);
    try {
      await context.read<StoreProvider>().fetchStoreProducts(storeId);
      final products = context.read<StoreProvider>().products;
      setState(() {
        _storeProducts = products;
        _filteredProducts = products;
        _selectedProduct = null;
        
        // Reset les champs calculés
        _priceCtrl.clear();
        _maxParticipantsCtrl.clear();
        _calculatedCommission = null;
        _calculatedRevenue = null;
        _commissionWarning = null;
      });
    } catch (e) {
      print('❌ Error loading products: $e');
    }
    setState(() => _loadingProducts = false);
  }

  void _filterStores() {
    final query = _storeSearchCtrl.text.toLowerCase();
    setState(() {
      _filteredStores = _myStores
          .where((s) => s.name.toLowerCase().contains(query))
          .toList();
    });
  }

  void _filterProducts() {
    final query = _productSearchCtrl.text.toLowerCase();
    setState(() {
      _filteredProducts = _storeProducts
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
    });
  }

  void _showStoreSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _StoreSelector(
        stores: _filteredStores,
        searchController: _storeSearchCtrl,
        onSelect: (store) {
          setState(() {
            _selectedStore = store;
            _storeSearchCtrl.clear();
          });
          Navigator.pop(context);
          _loadStoreProducts(store.id);
        },
      ),
    );
  }

  void _showProductSelector() {
    if (_selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord sélectionner une boutique')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProductSelector(
        products: _filteredProducts,
        searchController: _productSearchCtrl,
        loading: _loadingProducts,
        onSelect: (product) {
          setState(() {
            _selectedProduct = product;
            _productSearchCtrl.clear();
            
            // Reset les champs calculés
            _priceCtrl.clear();
            _maxParticipantsCtrl.clear();
            _calculatedCommission = null;
            _calculatedRevenue = null;
            _commissionWarning = null;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SOUMISSION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une boutique')),
      );
      return;
    }

    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un produit')),
      );
      return;
    }

    // Vérifier la commission
    if (_commissionWarning != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Commission insuffisante'),
          content: Text(_commissionWarning!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Modifier'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuer quand même'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _submitting = true);

    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id;

    final entryPrice = double.parse(_priceCtrl.text);
    final maxParticipants = int.parse(_maxParticipantsCtrl.text);
    
    final data = {
      'raffleType': 'product',
      'productId': _selectedProduct!.id,
      'storeId': _selectedStore!.id,
      'title': _titleCtrl.text.trim(),
      'probabilityType': _probabilityType, // Calculé automatiquement
      'entryPrice': entryPrice,
      'maxParticipants': maxParticipants,
      'cashOptionAvailable': _cashOptionAvailable,
      'autoDrawEnabled': _autoDrawEnabled,
      if (_autoDrawEnabled) 'autoDrawType': _autoDrawType,
      if (_autoDrawEnabled && _autoDrawType == 'delay')
        'autoDrawDelayMinutes': int.tryParse(_autoDrawDelayCtrl.text) ?? 0,
    };

    final prov = context.read<RaffleProvider>();
    final ok = await prov.createRaffle(data, userId: userId);

    setState(() => _submitting = false);

    if (mounted) {
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Tombola créée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(prov.errorMessage ?? 'Erreur de création'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD UI
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une tombola'),
      ),
      body: _loadingStores
          ? const Center(child: CircularProgressIndicator())
          : _myStores.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.store_outlined,
                          size: 64, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      const Text('Vous n\'avez aucune boutique',
                          style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      const Text('Créez une boutique pour commencer',
                          style: AppTheme.caption),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Retour'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ══════════════════════════════════════════════════
                        // SÉLECTION BOUTIQUE
                        // ══════════════════════════════════════════════════
                        const Text('Boutique *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _showStoreSelector,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              const Icon(Icons.store,
                                  color: AppTheme.primaryColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedStore?.name ??
                                      'Sélectionner une boutique',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _selectedStore != null
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ══════════════════════════════════════════════════
                        // SÉLECTION PRODUIT
                        // ══════════════════════════════════════════════════
                        const Text('Produit à gagner *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _showProductSelector,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              const Icon(Icons.card_giftcard,
                                  color: AppTheme.secondaryColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _loadingProducts
                                    ? const Text('Chargement...',
                                        style: TextStyle(fontSize: 15))
                                    : Text(
                                        _selectedProduct?.name ??
                                            'Sélectionner un produit',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: _selectedProduct != null
                                              ? AppTheme.textPrimary
                                              : AppTheme.textSecondary,
                                        ),
                                      ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16),
                            ]),
                          ),
                        ),

                        if (_selectedProduct != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.info_outline,
                                      size: 16, color: AppTheme.secondaryColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Valeur: ${_selectedProduct!.price.toStringAsFixed(0)} ${AppStrings.currency}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.secondaryColor,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 6),
                                Text(
                                  'Commission minimum: ${_getMinCommissionPercentage(_selectedProduct!.price).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // ══════════════════════════════════════════════════
                        // INFORMATIONS TOMBOLA
                        // ══════════════════════════════════════════════════
                        const Text('Informations de la tombola',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 14),

                        // Titre
                        TextFormField(
                          controller: _titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Titre de la tombola *',
                            hintText: 'Ex: iPhone 15 Pro - Tombola Premium',
                            prefixIcon: Icon(Icons.title),
                          ),
                          validator: (v) =>
                              v == null || v.trim().length < 5
                                  ? 'Minimum 5 caractères'
                                  : null,
                        ),
                        const SizedBox(height: 14),

                        // Prix d'entrée et Max participants
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceCtrl,
                              keyboardType: TextInputType.number,
                              enabled: _selectedProduct != null,
                              decoration: const InputDecoration(
                                labelText: 'Prix d\'entrée (XOF) *',
                                prefixIcon: Icon(Icons.payments),
                                helperText: 'Rempli automatiquement',
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requis';
                                final price = double.tryParse(v);
                                if (price == null) return 'Nombre invalide';
                                if (price < 100) return 'Min 100 XOF';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _maxParticipantsCtrl,
                              keyboardType: TextInputType.number,
                              enabled: _selectedProduct != null,
                              decoration: const InputDecoration(
                                labelText: 'Max participants *',
                                prefixIcon: Icon(Icons.people),
                                helperText: 'Calculé automatiquement',
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requis';
                                final max = int.tryParse(v);
                                if (max == null) return 'Nombre invalide';
                                if (max < 2 || max > 10000)
                                  return '2-10000';
                                return null;
                              },
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),

                        // Affichage des calculs
                        if (_calculatedRevenue != null && _calculatedCommission != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _commissionWarning != null
                                  ? Colors.red.withOpacity(0.08)
                                  : Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _commissionWarning != null
                                    ? Colors.red.withOpacity(0.3)
                                    : Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Revenu total: ${_calculatedRevenue!.toStringAsFixed(0)} ${AppStrings.currency}',
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Commission: ${_calculatedCommission!.toStringAsFixed(0)} ${AppStrings.currency} (${((_calculatedCommission! / _selectedProduct!.price) * 100).toStringAsFixed(1)}%)',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (_commissionWarning != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _commissionWarning!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // ══════════════════════════════════════════════════
                        // TYPE DE PROBABILITÉ (Affiché, non modifiable)
                        // ══════════════════════════════════════════════════
                        const Text('Type de probabilité (calculé automatiquement)',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getProbabilityColor(_probabilityType).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getProbabilityColor(_probabilityType).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(_getProbabilityIcon(_probabilityType),
                                  color: _getProbabilityColor(_probabilityType)),
                              const SizedBox(width: 10),
                              Text(
                                _getProbabilityLabel(_probabilityType),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _getProbabilityColor(_probabilityType),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ══════════════════════════════════════════════════
                        // OPTION CASH (sans montant)
                        // ══════════════════════════════════════════════════
                        SwitchListTile(
                          title: const Text('Option cash disponible'),
                          subtitle: const Text(
                              'Permettre au gagnant d\'encaisser l\'argent'),
                          value: _cashOptionAvailable,
                          onChanged: (v) =>
                              setState(() => _cashOptionAvailable = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 10),

                        // ══════════════════════════════════════════════════
                        // TIRAGE AUTOMATIQUE
                        // ══════════════════════════════════════════════════
                        SwitchListTile(
                          title: const Text('Tirage automatique'),
                          subtitle: const Text(
                              'Tirer au sort automatiquement quand c\'est plein'),
                          value: _autoDrawEnabled,
                          onChanged: (v) =>
                              setState(() => _autoDrawEnabled = v),
                          contentPadding: EdgeInsets.zero,
                        ),

                        if (_autoDrawEnabled) ...[
                          const SizedBox(height: 10),
                          Wrap(spacing: 10, children: [
                            ChoiceChip(
                              label: const Text('⚡ Immédiat'),
                              selected: _autoDrawType == 'immediate',
                              onSelected: (v) =>
                                  setState(() => _autoDrawType = 'immediate'),
                            ),
                            ChoiceChip(
                              label: const Text('⏱️ Différé'),
                              selected: _autoDrawType == 'delay',
                              onSelected: (v) =>
                                  setState(() => _autoDrawType = 'delay'),
                            ),
                          ]),

                          if (_autoDrawType == 'delay') ...[
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _autoDrawDelayCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Délai en minutes',
                                hintText: 'Ex: 30 (pour 30 minutes)',
                                prefixIcon: Icon(Icons.timer),
                                helperText: 'Minutes après que la tombola soit pleine',
                              ),
                              validator: (v) {
                                if (_autoDrawType == 'delay') {
                                  if (v == null || v.isEmpty) return 'Requis';
                                  final delay = int.tryParse(v);
                                  if (delay == null) return 'Nombre invalide';
                                  if (delay < 0 || delay > 1440)
                                    return '0-1440 min';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],

                        const SizedBox(height: 32),

                        // ══════════════════════════════════════════════════
                        // BOUTON CRÉER
                        // ══════════════════════════════════════════════════
                        ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryColor,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Créer la tombola',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }


  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Color _getProbabilityColor(String type) {
    switch (type) {
      case 'high':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getProbabilityIcon(String type) {
    switch (type) {
      case 'high':
        return Icons.star;
      case 'medium':
        return Icons.adjust;
      case 'low':
        return Icons.casino;
      default:
        return Icons.help;
    }
  }

  String _getProbabilityLabel(String type) {
    switch (type) {
      case 'high':
        return '⭐ Forte probabilité';
      case 'medium':
        return '🎯 Probabilité moyenne';
      case 'low':
        return '🎲 Faible probabilité';
      default:
        return 'Non défini';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEETS (inchangés)
// ═══════════════════════════════════════════════════════════════════════════════

class _StoreSelector extends StatelessWidget {
  final List<Store> stores;
  final TextEditingController searchController;
  final Function(Store) onSelect;

  const _StoreSelector({
    required this.stores,
    required this.searchController,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 16),
        const Text('Sélectionner une boutique',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Rechercher...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: stores.isEmpty
              ? const Center(child: Text('Aucune boutique trouvée'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: stores.length,
                  itemBuilder: (_, i) {
                    final store = stores[i];
                    return ListTile(
                      leading: const Icon(Icons.store,
                          color: AppTheme.primaryColor),
                      title: Text(store.name),
                      subtitle: Text(store.description ?? ''),
                      onTap: () => onSelect(store),
                    );
                  },
                ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}

class _ProductSelector extends StatelessWidget {
  final List<Product> products;
  final TextEditingController searchController;
  final bool loading;
  final Function(Product) onSelect;

  const _ProductSelector({
    required this.products,
    required this.searchController,
    required this.loading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 16),
        const Text('Sélectionner un produit',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Rechercher...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : products.isEmpty
                  ? const Center(
                      child: Text('Aucun produit dans cette boutique'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: products.length,
                      itemBuilder: (_, i) {
                        final product = products[i];
                        return ListTile(
                          leading: product.imageUrls.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    product.imageUrls.first,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.image_not_supported),
                                  ),
                                )
                              : const Icon(Icons.inventory_2_outlined),
                          title: Text(product.name),
                          subtitle: Text(
                              '${product.price.toStringAsFixed(0)} ${AppStrings.currency}'),
                          onTap: () => onSelect(product),
                        );
                      },
                    ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}