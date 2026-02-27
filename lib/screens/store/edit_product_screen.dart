import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/models/models.dart';
import '../../data/services/api_service.dart';
import '../../data/services/upload_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/category_provider.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;
  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey   = GlobalKey<FormState>();
  late final _nameCtrl  = TextEditingController(text: widget.product.name);
  late final _descCtrl  = TextEditingController(text: widget.product.description ?? '');
  late final _priceCtrl = TextEditingController(text: widget.product.price.toString());
  late final _stockCtrl = TextEditingController(text: '0'); 
  List<String> _existingImages = [];
  List<File> _newImages = [];
  bool _saving = false;
  bool _loadingCategories = true;
  List<Category> _categories = [];
  String? _selectedCategoryId;


  @override
  void initState() {
    super.initState();
    _existingImages = List.from(widget.product.imageUrls);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      await context.read<CategoryProvider>().fetchProductCategories();
      final cats = context.read<CategoryProvider>().productCategories;
      setState(() {
        _categories = cats;
        // Sélectionner la catégorie actuelle du produit (si disponible)
        // Pour l'instant on prend la première, tu peux améliorer ça
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
    super.dispose();
  }

  Future<void> _pickNewImages() async {
    if (_existingImages.length + _newImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 images'), backgroundColor: Colors.red),
      );
      return;
    }

    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 80);
    if (images.isEmpty) return;

    final remaining = 5 - _existingImages.length - _newImages.length;
    final toAdd = images.take(remaining).map((e) => File(e.path)).toList();
    setState(() => _newImages.addAll(toAdd));
  }

  Future<void> _deleteExistingImage(String imageUrl) async {
    try {
      final uploadService = UploadService(ApiService());
      await uploadService.deleteProductImage(widget.product.id, imageUrl);
      setState(() => _existingImages.remove(imageUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image supprimée'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final api = ApiService();
      
      // 1. Update product info
      final updateData = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text),
        'categoryId': _selectedCategoryId,  
        'stockQuantity': int.tryParse(_stockCtrl.text) ?? 0,  
      };
      await api.put('/products/${widget.product.id}', data: updateData);

      // 2. Upload new images if any
      if (_newImages.isNotEmpty) {
        final uploadService = UploadService(api);
        await uploadService.uploadProductImages(widget.product.id, _newImages);
      }

      if (mounted) {
        Navigator.pop(context, true); // true = modifié
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit mis à jour !'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('❌ Product update error: $e');
      
      String errorMsg = 'Erreur lors de la modification';
      
      if (e is DioException) {
        final backendMsg = e.response?.data?['message']?.toString() ?? '';
        
        if (backendMsg.contains('Product not found')) {
          errorMsg = 'Produit introuvable';
        } else if (backendMsg.contains('not authorized to update')) {
          errorMsg = "Vous n'êtes pas autorisé à modifier ce produit";
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

    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCategories) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }


    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le produit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(children: [
            // Images existantes
            if (_existingImages.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Images actuelles',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(_existingImages[i],
                        width: 100, height: 100, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100, height: 100,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image),
                        )),
                    ),
                    Positioned(
                      top: 4, right: 4,
                      child: GestureDetector(
                        onTap: () => _deleteExistingImage(_existingImages[i]),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Nouvelles images
            if (_newImages.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Nouvelles images',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _newImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_newImages[i],
                        width: 100, height: 100, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4, right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _newImages.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Bouton ajouter images
            OutlinedButton.icon(
              onPressed: (_existingImages.length + _newImages.length >= 5)
                  ? null
                  : _pickNewImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(
                '${_existingImages.length + _newImages.length}/5 images',
              ),
            ),
            const SizedBox(height: 24),

            // Dropdown catégorie
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
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom du produit *',
                prefixIcon: Icon(Icons.inventory_2_outlined)),
              validator: (v) =>
                  v == null || v.trim().length < 2 ? '2 caractères minimum' : null,
            ),
            const SizedBox(height: 16),

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
            const SizedBox(height: 16),

            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description_outlined)),
            ),
            const SizedBox(height: 28),

            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save),
              label: const Text('Enregistrer les modifications'),
            ),
          ]),
        ),
      ),
    );
  }
}