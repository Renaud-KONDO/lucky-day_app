/* import 'package:flutter/material.dart';
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
} */


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
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
  final _storeSearchCtrl = TextEditingController();
  final _productSearchCtrl = TextEditingController();
  final _autoDrawDelayCtrl = TextEditingController(text: '0');

  // Sélections
  Store? _selectedStore;
  Product? _selectedProduct;
  String _probabilityType = 'medium';
  bool _cashOptionAvailable = false;
  bool _autoDrawEnabled = false;
  String _autoDrawType = 'immediate';

  // Loading states
  bool _loadingStores = true;
  bool _loadingProducts = false;
  bool _submitting = false;
  bool _calculatingPrice = false;
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
    _storeSearchCtrl.addListener(_filterStores);
    _productSearchCtrl.addListener(_filterProducts);
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

  // ========== MÉTHODES DE CALCUL ==========
  double _getMinCommissionPercentage(double productPrice) {
    if (productPrice <= 10000) return 50.0;
    if (productPrice <= 100000) return 30.0;
    return 10.0;
  }

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
    final totalNeeded = productPrice * (1 + minCommission / 100);
    final requiredParticipants = (totalNeeded / entryPrice).ceil();

    _calculatingParticipants = true;
    _maxParticipantsCtrl.text = requiredParticipants.toString();
    _calculatingParticipants = false;
    _updateCommissionAndProbability(entryPrice, requiredParticipants.toDouble(), productPrice, minCommission);
  }

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
    final totalNeeded = productPrice * (1 + minCommission / 100);
    final requiredEntryPrice = (totalNeeded / maxParticipants).ceil().toDouble();

    _calculatingPrice = true;
    _priceCtrl.text = requiredEntryPrice.toStringAsFixed(0);
    _calculatingPrice = false;
    _updateCommissionAndProbability(requiredEntryPrice, maxParticipants.toDouble(), productPrice, minCommission);
  }

  void _updateCommissionAndProbability(double entryPrice, double maxParticipants, double productPrice, double minCommissionPercentage) {
    final totalRevenue = entryPrice * maxParticipants;
    final commission = totalRevenue - productPrice;
    final commissionPercentage = (commission / productPrice) * 100;

    String newProbabilityType;
    if (entryPrice >= productPrice * 0.20) {
      newProbabilityType = 'high';
    } else if (entryPrice >= productPrice * 0.10) {
      newProbabilityType = 'medium';
    } else {
      newProbabilityType = 'low';
    }

    String? warning;
    if (commissionPercentage < minCommissionPercentage) {
      warning = '⚠️ Commission trop faible (${commissionPercentage.toStringAsFixed(1)}%). Minimum requis: ${minCommissionPercentage.toStringAsFixed(0)}%';
    }

    if (mounted) {
      setState(() {
        _calculatedRevenue = totalRevenue;
        _calculatedCommission = commission;
        _commissionWarning = warning;
        _probabilityType = newProbabilityType;
      });
    }
  }

  // ========== CHARGEMENT DONNÉES ==========
  Future<void> _loadMyStores() async {
    if (!mounted) return;
    setState(() => _loadingStores = true);
    try {
      await context.read<StoreProvider>().fetchMyStores();
      final stores = context.read<StoreProvider>().myStores;
      if (mounted) {
        setState(() {
          _myStores = stores;
          _filteredStores = stores;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading stores: $e');
    }
    if (mounted) setState(() => _loadingStores = false);
  }

  Future<void> _loadStoreProducts(String storeId) async {
    if (!mounted) return;
    setState(() => _loadingProducts = true);
    try {
      await context.read<StoreProvider>().fetchStoreProducts(storeId);
      final products = context.read<StoreProvider>().products;
      if (mounted) {
        setState(() {
          _storeProducts = products;
          _filteredProducts = products;
          _selectedProduct = null;
          _priceCtrl.clear();
          _maxParticipantsCtrl.clear();
          _calculatedCommission = null;
          _calculatedRevenue = null;
          _commissionWarning = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading products: $e');
    }
    if (mounted) setState(() => _loadingProducts = false);
  }

  void _filterStores() {
    final query = _storeSearchCtrl.text.toLowerCase();
    setState(() {
      _filteredStores = _myStores.where((s) => s.name.toLowerCase().contains(query)).toList();
    });
  }

  void _filterProducts() {
    final query = _productSearchCtrl.text.toLowerCase();
    setState(() {
      _filteredProducts = _storeProducts.where((p) => p.name.toLowerCase().contains(query)).toList();
    });
  }

  // ========== SELECTEURS ==========
  void _showStoreSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StoreSelector(
        stores: _filteredStores,
        searchController: _storeSearchCtrl,
        onSelect: (store) {
          if (mounted) {
            setState(() {
              _selectedStore = store;
              _storeSearchCtrl.clear();
            });
          }
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
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductSelector(
        products: _filteredProducts,
        searchController: _productSearchCtrl,
        loading: _loadingProducts,
        onSelect: (product) {
          if (mounted) {
            setState(() {
              _selectedProduct = product;
              _productSearchCtrl.clear();
              _priceCtrl.clear();
              _maxParticipantsCtrl.clear();
              _calculatedCommission = null;
              _calculatedRevenue = null;
              _commissionWarning = null;
            });
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  // ========== SOUMISSION ==========
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

    if (_commissionWarning != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('Commission insuffisante'),
            ],
          ),
          content: Text(_commissionWarning!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Modifier'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    if (!mounted) return;
    setState(() => _submitting = true);

    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id;
    if (userId == null) return;

    final entryPrice = double.parse(_priceCtrl.text);
    final maxParticipants = int.parse(_maxParticipantsCtrl.text);

    final data = {
      'raffleType': 'product',
      'productId': _selectedProduct!.id,
      'storeId': _selectedStore!.id,
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'probabilityType': _probabilityType,
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

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('🎉 Tombola créée avec succès !'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(prov.errorMessage ?? 'Erreur de création')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ========== BUILD UI ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une tombola',
          style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppTheme.primaryColor.withOpacity(0.9),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withOpacity(0.05),
              AppTheme.primaryColor.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: _loadingStores
            ? const Center(child: CircularProgressIndicator())
            : _myStores.isEmpty
                ? _buildEmptyState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Boutique & Produit
                          _buildGlassSection(
                            title: '🏠︎ Boutique & Produit',
                            children: [
                              _buildStoreSelector(),
                              if (_selectedStore != null) ...[
                                const SizedBox(height: 12),
                                _buildProductSelector(),
                                if (_selectedProduct != null) ...[
                                  const SizedBox(height: 12),
                                  _buildProductInfo(),
                                ],
                              ],
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Section Détails
                          _buildGlassSection(
                            title: 'ⓘ Informations de la tombola',
                            children: [
                              _buildTextField(
                                controller: _titleCtrl,
                                label: 'Titre de la tombola *',
                                hint: 'Ex: iPhone 15 Pro - Tombola Premium',
                                icon: Icons.title,
                                validator: (v) => v == null || v.trim().length < 5
                                    ? 'Minimum 5 caractères'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _descCtrl,
                                label: 'Description (optionnelle)',
                                hint: 'Décrivez votre tombola...',
                                icon: Icons.description,
                                maxLines: 3,
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Section Prix
                          _buildGlassSection(
                            title: '⚙️ Configuration des prix',
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _priceCtrl,
                                      label: 'Prix d\'entrée (XOF) *',
                                      icon: Icons.payments,
                                      keyboardType: TextInputType.number,
                                      enabled: _selectedProduct != null,
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return 'Requis';
                                        final price = double.tryParse(v);
                                        if (price == null) return 'Invalide';
                                        if (price < 100) return 'Min 100 XOF';
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _maxParticipantsCtrl,
                                      label: 'Max participants *',
                                      icon: Icons.people,
                                      keyboardType: TextInputType.number,
                                      enabled: _selectedProduct != null,
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return 'Requis';
                                        final max = int.tryParse(v);
                                        if (max == null) return 'Invalide';
                                        if (max < 2 || max > 10000) return '2-10000';
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              if (_calculatedRevenue != null && _calculatedCommission != null) ...[
                                const SizedBox(height: 12),
                                _buildCommissionCard(),
                              ],
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Section Probabilité
                          _buildGlassSection(
                            title: '🎯 Type de probabilité',
                            children: [
                              _buildProbabilityCard(),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Section Options
                          _buildGlassSection(
                            title: '🛠️ Options avancées',
                            children: [
                              _buildSwitchOption(
                                title: 'Option cash disponible',
                                subtitle: 'Permettre au gagnant d\'encaisser',
                                icon: Icons.attach_money,
                                value: _cashOptionAvailable,
                                onChanged: (v) => setState(() => _cashOptionAvailable = v),
                              ),
                              const Divider(height: 16),
                              _buildSwitchOption(
                                title: 'Tirage automatique',
                                subtitle: 'Tirer au sort automatiquement',
                                icon: Icons.auto_awesome,
                                value: _autoDrawEnabled,
                                onChanged: (v) => setState(() => _autoDrawEnabled = v),
                              ),
                              if (_autoDrawEnabled) ...[
                                const SizedBox(height: 12),
                                _buildAutoDrawOptions(),
                              ],
                            ],
                          ),

                          const SizedBox(height: 20),

                          _buildSubmitButton(),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  // ========== WIDGET BUILDERS ==========
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.2),
                  AppTheme.secondaryColor.withOpacity(0.2),
                ],
              ),
            ),
            child: const Icon(Icons.store_outlined, size: 50, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          const Text('Aucune boutique disponible',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Créez une boutique pour commencer',
              style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreSelector() {
    return InkWell(
      onTap: _showStoreSelector,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.store, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedStore?.name ?? 'Sélectionner une boutique',
                style: TextStyle(
                  fontSize: 14,
                  color: _selectedStore != null
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSelector() {
    return InkWell(
      onTap: _showProductSelector,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.card_giftcard, color: AppTheme.secondaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _loadingProducts
                  ? const Text('Chargement...', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary))
                  : Text(
                      _selectedProduct?.name ?? 'Sélectionner un produit',
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedProduct != null
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppTheme.secondaryColor),
              const SizedBox(width: 8),
              Text(
                'Valeur: ${_selectedProduct!.price.toStringAsFixed(0)} ${AppStrings.currency}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          /* const SizedBox(height: 6),
          Text(
            'Commission min: ${_getMinCommissionPercentage(_selectedProduct!.price).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ), */
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    bool enabled = true,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        fillColor: Colors.white.withOpacity(0.9),
        filled: true,
      ),
    );
  }

  Widget _buildCommissionCard() {
    final isWarning = _commissionWarning != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarning ? Colors.red.withOpacity(0.08) : Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWarning ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWarning ? Icons.warning_amber_rounded : Icons.check_circle,
                size: 16,
                color: isWarning ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 8),
              Text(
                'frais réseaux, commissions et taxes inclus',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),/* const SizedBox(width: 8),
              Text(
                'Revenu total: ${_calculatedRevenue!.toStringAsFixed(0)} ${AppStrings.currency}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ), */
            ],
          ),
          /* const SizedBox(height: 6),
          Text(
            'Commission: ${_calculatedCommission!.toStringAsFixed(0)} ${AppStrings.currency} (${((_calculatedCommission! / _selectedProduct!.price) * 100).toStringAsFixed(1)}%)',
            style: const TextStyle(fontSize: 12),
          ), */
          if (_commissionWarning != null) ...[
            const SizedBox(height: 6),
            Text(
              _commissionWarning!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProbabilityCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getProbabilityColor(_probabilityType).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getProbabilityColor(_probabilityType).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getProbabilityColor(_probabilityType).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getProbabilityIcon(_probabilityType),
              color: _getProbabilityColor(_probabilityType),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getProbabilityLabel(_probabilityType),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _getProbabilityColor(_probabilityType),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Automatiquement déterminée',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primaryColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  Widget _buildAutoDrawOptions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildChoiceChip(
                label: 'Immédiat',
                selected: _autoDrawType == 'immediate',
                onTap: () => setState(() => _autoDrawType = 'immediate'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildChoiceChip(
                label: 'Différé',
                selected: _autoDrawType == 'delay',
                onTap: () => setState(() => _autoDrawType = 'delay'),
              ),
            ),
          ],
        ),
        if (_autoDrawType == 'delay') ...[
          const SizedBox(height: 12),
          _buildTextField(
            controller: _autoDrawDelayCtrl,
            label: 'Délai en minutes',
            icon: Icons.timer,
            keyboardType: TextInputType.number,
            hint: 'Ex: 30',
          ),
        ],
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _submitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                '🚀 Créer la tombola',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  // ========== HELPERS ==========
  Color _getProbabilityColor(String type) {
    switch (type) {
      case 'high': return Colors.green;
      case 'medium': return Colors.orange;
      case 'low': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getProbabilityIcon(String type) {
    switch (type) {
      case 'high': return Icons.star;
      case 'medium': return Icons.star_half;
      case 'low': return Icons.casino;
      default: return Icons.help;
    }
  }

  String _getProbabilityLabel(String type) {
    switch (type) {
      case 'high': return 'Forte probabilité';
      case 'medium': return 'Probabilité moyenne';
      case 'low': return 'Faible probabilité';
      default: return 'Non défini';
    }
  }
}

// ========== BOTTOM SHEETS ==========
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const Text('Sélectionner une boutique',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                          leading: const Icon(Icons.store, color: AppTheme.primaryColor),
                          title: Text(store.name),
                          subtitle: Text(store.description ?? ''),
                          onTap: () => onSelect(store),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const Text('Sélectionner un produit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                      ? const Center(child: Text('Aucun produit dans cette boutique'))
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
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.image_not_supported),
                                      ),
                                    )
                                  : const Icon(Icons.inventory_2_outlined),
                              title: Text(product.name),
                              subtitle: Text('${product.price.toStringAsFixed(0)} ${AppStrings.currency}'),
                              onTap: () => onSelect(product),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
