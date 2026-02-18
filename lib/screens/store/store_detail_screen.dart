import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/models.dart';
import '../../providers/store_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import 'package:logger/logger.dart';

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Image
        Expanded(
          child: Stack(children: [
            SizedBox(
              width: double.infinity,
              child: product.imageUrl != null
                  ? Image.network(product.imageUrl!, fit: BoxFit.cover,
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
                top: 4, right: 4,
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
                      // TODO: ouvrir feuille d'édition
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
    );
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
              // TODO: appel API delete
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
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
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
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
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
                labelText: 'Nom du produit *',
                prefixIcon: Icon(Icons.inventory_2_outlined)),
            validator: (v) =>
                v == null || v.trim().length < 2 ? '2 caractères minimum' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
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
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // TODO: appel API create product
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Ajouter le produit'),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}