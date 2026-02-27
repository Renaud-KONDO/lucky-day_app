import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/models.dart';
import '../../data/services/api_service.dart';
import '../../providers/category_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import 'package:logger/logger.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../data/services/upload_service.dart';
import '../product/product_detail_screen.dart';
import 'edit_product_screen.dart';

class StoreDetailScreen extends StatefulWidget {
  final Store store;
  const StoreDetailScreen({super.key, required this.store});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().fetchStoreProducts(widget.store.id);
    });
  }

  void _showUploadLogoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.store),
          title: const Text('Changer le logo'),
          onTap: () {
            Navigator.pop(context);
            _pickAndUploadLogo(context, false);
          },
        ),
        ListTile(
          leading: const Icon(Icons.panorama),
          title: const Text('Changer la bannière'),
          onTap: () {
            Navigator.pop(context);
            _pickAndUploadLogo(context, true);
          },
        ),
      ]),
    );
  }

  Future<void> _pickAndUploadLogo(BuildContext context, bool isBanner) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;

    try {
      final uploadService = UploadService(ApiService());
      if (isBanner) {
        await uploadService.uploadStoreBanner(widget.store.id, File(image.path));
      } else {
        await uploadService.uploadStoreLogo(widget.store.id, File(image.path));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isBanner ? 'Bannière mise à jour' : 'Logo mis à jour'),
            backgroundColor: Colors.green),
        );
        // Recharger la boutique
        context.read<StoreProvider>().fetchStores();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final prov    = context.watch<StoreProvider>();
    final isOwner = auth.currentUser?.id == widget.store.ownerId
        || (auth.currentUser?.isAdmin ?? false);

        //Logger().i("store detail screen build for store ${widget.store.name} with id ${widget.store.id} and owner id ${widget.store.ownerId} and current user id ${auth.currentUser?.id} and isStoreOwner ${auth.currentUser?.isStoreOwner}");
        //Logger().i("is owner ? $isOwner");

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar avec image/logo ────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            actions: isOwner ? [
              IconButton(
                icon: const Icon(Icons.camera_alt),
                onPressed: () => _showUploadLogoSheet(context),
              ),
            ] : null,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.store.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
              background: widget.store.logoUrl != null
                  ? Image.network(widget.store.logoUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultBg())
                  : _defaultBg(),
            ),
          ),

          // ── Infos boutique ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Status + catégorie
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.store.isActive
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.store.isActive
                            ? Colors.green.withOpacity(0.4)
                            : Colors.grey.withOpacity(0.4),
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle,
                          size: 8,
                          color: widget.store.isActive
                              ? Colors.green
                              : Colors.grey),
                      const SizedBox(width: 6),
                      Text(widget.store.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.store.isActive
                                ? Colors.green
                                : Colors.grey,
                          )),
                    ]),
                  ),
                  const Spacer(),
                  if (widget.store.raffleCount > 0)
                    Row(children: [
                      const Icon(Icons.confirmation_number_outlined,
                          size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.store.raffleCount} tombola${widget.store.raffleCount > 1 ? "s" : ""}',
                        style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ]),
                ]),

                if (widget.store.description != null) ...[
                  const SizedBox(height: 14),
                  Text(widget.store.description!,
                      style: AppTheme.bodyText),
                ],

                if (widget.store.address != null) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(widget.store.address!,
                        style: AppTheme.caption),
                  ]),
                ],

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),

                // ── Titre produits + bouton ajouter (owner) ─────────────
                Row(children: [
                  const Text('Produits',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  const Spacer(),
                  if (isOwner)
                    ElevatedButton.icon(
                      onPressed: () => _showAddProductSheet(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),
              ]),
            ),
          ),

          // ── Liste produits ────────────────────────────────────────────
          prov.isLoading
              ? const SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  )))
              : prov.products.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                          child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 56, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        const Text('Aucun produit pour l\'instant',
                            style: AppTheme.bodyText),
                        if (isOwner) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _showAddProductSheet(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter un produit'),
                          ),
                        ],
                      ]),
                    )))
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _ProductCard(
                            product: prov.products[i],
                            isOwner: isOwner,
                          ),
                          childCount: prov.products.length,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _defaultBg() => Container(
    decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
    child: const Center(
        child: Icon(Icons.store, size: 60, color: Colors.white54)),
  );

  void _showAddProductSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddProductSheet(storeId: widget.store.id),
    );
  }
}

// ─── Card produit ─────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;
  final bool isOwner;
  const _ProductCard({required this.product, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image
          Expanded(
            child: Stack(children: [
              SizedBox(
                width: double.infinity,
                child: product.imageUrls.isNotEmpty
                    ? Image.network(product.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFEFF6FF),
                          child: const Icon(Icons.image_not_supported,
                              color: AppTheme.textSecondary),
                        ))
                    : Container(
                        color: const Color(0xFFEFF6FF),
                        child: const Icon(Icons.inventory_2_outlined,
                            color: AppTheme.primaryColor, size: 36)),
              ),
              // Menu owner (modifier/supprimer)
              if (isOwner)
                Positioned(
                  top: 4,
                  right: 4,
                  child: PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.more_vert,
                          color: Colors.white, size: 16),
                    ),
                    onSelected: (v) {
                      if (v == 'edit') {
                        _editProduct(context, product);
                      } else if (v == 'delete') {
                        _confirmDelete(context);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Modifier'),
                          ])),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Supprimer',
                                style: TextStyle(color: Colors.red)),
                          ])),
                    ],
                  ),
                ),
            ]),
          ),
          // Infos
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text(
                '${product.price.toStringAsFixed(0)} ${AppStrings.currency}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _editProduct(BuildContext context, Product product) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditProductScreen(product: product)),
    );
    
    if (result == true && context.mounted) {
      // Refresh la liste des produits
      context.read<StoreProvider>().fetchStoreProducts(product.storeId!);
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le produit'),
        content: Text('Voulez-vous vraiment supprimer "${product.name}" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(context, product);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

Future<void> _deleteProduct(BuildContext context, Product product) async {
  try {
    var storeId = product.storeId;
    final api = ApiService();
    await api.delete('/products/${product.id}');
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produit supprimé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      // Refresh
      context.read<StoreProvider>().fetchStoreProducts(storeId!);
    }
  } catch (e) {
    String errorMsg = 'Erreur lors de la suppression';
    final errStr = e.toString().toLowerCase();
    
    if (errStr.contains('not found')) {
      errorMsg = 'Produit introuvable';
    } else if (errStr.contains('not authorized')) {
      errorMsg = "Vous n'êtes pas autorisé à supprimer ce produit";
    } else if (errStr.contains('existing raffles')) {
      errorMsg = 'Impossible de supprimer : des tombolas existent pour ce produit. Terminez-les d\'abord.';
    }
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    }
  }
}

// ─── Bottom sheet ajout produit ───────────────────────────────────────────────
class _AddProductSheet extends StatefulWidget {
  final String storeId;
  const _AddProductSheet({required this.storeId});
  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _priceCtrl  = TextEditingController();
  final _stockCtrl  = TextEditingController(text: '0');
  List<File> _selectedImages = [];
  bool _uploading = false;
  bool _loadingCategories = true;
  List<Category> _categories = [];
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      await context.read<CategoryProvider>().fetchProductCategories();
      final cats = context.read<CategoryProvider>().productCategories;
      setState(() {
        _categories = cats;
        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories.first.id;
        }
      });
    } catch (e) {
      print('❌ Error loading categories: $e');
    }
    setState(() => _loadingCategories = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 80);
    if (images.isEmpty) return;
    
    if (_selectedImages.length + images.length > 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 5 images par produit'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    
    setState(() {
      _selectedImages.addAll(images.map((e) => File(e.path)));
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une catégorie'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() => _uploading = true);
    
    try {
      final api = ApiService();
      
      // 1. Créer le produit
      final productData = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text),
        'storeId': widget.storeId,
        'categoryId': _selectedCategoryId,
        'stockQuantity': int.tryParse(_stockCtrl.text) ?? 0,
        'imageUrls': [],  // Vide pour l'instant, on uploadera après
      };
      
      print('📤 Creating product: $productData');
      
      final createRes = await api.post('/products', data: productData);
      final productId = createRes.data['data']['id'];
      
      print('✅ Product created with ID: $productId');
      
      // 2. Upload images si sélectionnées
      if (_selectedImages.isNotEmpty) {
        print('📤 Uploading ${_selectedImages.length} images...');
        final uploadService = UploadService(api);
        await uploadService.uploadProductImages(productId, _selectedImages);
        print('✅ Images uploaded');
      }
      
      if (mounted) {
        Navigator.pop(context);
        
        // Refresh la liste des produits
        context.read<StoreProvider>().fetchStoreProducts(widget.storeId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit créé avec succès !'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('❌ Product creation error: $e');
      
      String errorMsg = 'Erreur lors de la création du produit';
      
      if (e is DioException) {
        final backendMsg = e.response?.data?['message']?.toString() ?? '';
        
        if (backendMsg.contains('Store not found')) {
          errorMsg = 'Boutique introuvable';
        } else if (backendMsg.contains('not authorized')) {
          errorMsg = "Vous n'êtes pas autorisé à créer des produits pour cette boutique";
        } else if (backendMsg.contains('category not found')) {
          errorMsg = 'Catégorie de produit introuvable';
        } else if (backendMsg.isNotEmpty) {
          errorMsg = backendMsg;
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
    
    setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCategories) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.category_outlined, size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          const Text('Aucune catégorie de produit disponible',
            style: AppTheme.bodyText, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ]),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            const Text('Ajouter un produit',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // Images sélectionnées
            if (_selectedImages.isNotEmpty) ...[
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_selectedImages[i],
                        width: 80, height: 80, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2, right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImages.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                            color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Bouton ajouter images
            OutlinedButton.icon(
              onPressed: _selectedImages.length >= 5 ? null : _pickImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(_selectedImages.isEmpty
                ? 'Ajouter des images (max 5)'
                : '${_selectedImages.length}/5 images'),
            ),
            const SizedBox(height: 16),
            
            // Catégorie (dropdown)
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Catégorie *',
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories.map((cat) => DropdownMenuItem(
                value: cat.id,
                child: Text(cat.name),
              )).toList(),
              onChanged: (val) => setState(() => _selectedCategoryId = val),
              validator: (v) => v == null ? 'Catégorie requise' : null,
            ),
            const SizedBox(height: 14),
            
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom du produit *',
                prefixIcon: Icon(Icons.inventory_2_outlined)),
              validator: (v) =>
                v == null || v.trim().length < 2 ? '2 caractères minimum' : null,
            ),
            const SizedBox(height: 14),
            
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Prix (XOF) *',
                    prefixIcon: Icon(Icons.payments_outlined)),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requis';
                    if (double.tryParse(v) == null) return 'Nombre invalide';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stock',
                    prefixIcon: Icon(Icons.inventory)),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description_outlined)),
            ),
            const SizedBox(height: 20),
            
            ElevatedButton.icon(
              onPressed: _uploading ? null : _submit,
              icon: _uploading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.add),
              label: const Text('Ajouter le produit'),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}