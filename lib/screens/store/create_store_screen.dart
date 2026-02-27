import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/store_provider.dart';
import '../../providers/category_provider.dart';
import '../../data/models/models.dart';
import '../../data/services/upload_service.dart';
import '../../data/services/api_service.dart';
import '../../core/theme/app_theme.dart';

class CreateStoreScreen extends StatefulWidget {
  const CreateStoreScreen({super.key});

  @override
  State<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends State<CreateStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  
  Category? _selectedCategory;  // ← Changé de StoreCategory à Category
  bool _loadingCategories = true;
  bool _submitting = false;
  List<Category> _categories = [];  // ← Changé

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      await context.read<CategoryProvider>().fetchStoreCategories();
      final cats = context.read<CategoryProvider>().storeCategories;
      setState(() {
        _categories = cats;
        if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }
      });
    } catch (e) {
      print('❌ Error loading categories: $e');
    }
    setState(() => _loadingCategories = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une catégorie'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // Créer le store SANS images
     final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'categoryId': _selectedCategory!.id,
      };

      // ✅ Ajouter seulement si non vide
      if (_descCtrl.text.trim().isNotEmpty) {
        data['description'] = _descCtrl.text.trim();
      }

      if (_addressCtrl.text.trim().isNotEmpty) {
        data['address'] = _addressCtrl.text.trim();
      }

      if (_phoneCtrl.text.trim().isNotEmpty) {
        data['phone'] = _phoneCtrl.text.trim();
      }

      if (_emailCtrl.text.trim().isNotEmpty) {
        data['email'] = _emailCtrl.text.trim();
      }

      print('📤 Sending data to backend: $data'); // ← Pour vérifier


      final prov = context.read<StoreProvider>();
      final store = await prov.createStoreAndReturn(data);

      if (store == null) {
        setState(() => _submitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(prov.errorMessage ?? 'Erreur de création'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() => _submitting = false);

      // Proposer d'ajouter logo et bannière
      if (mounted) {
        final shouldAddImages = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('🎉 Boutique créée !'),
            content: const Text(
              'Voulez-vous ajouter un logo et une bannière maintenant ?\n\n'
              'Vous pourrez toujours le faire plus tard.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Plus tard'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ajouter maintenant'),
              ),
            ],
          ),
        );

        if (shouldAddImages == true) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UploadStoreImagesScreen(store: store),
            ),
          );
        }

        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('❌ Error creating store: $e');
      setState(() => _submitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
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
        title: const Text('Créer une boutique'),
      ),
      body: _loadingCategories
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.category_outlined,
                          size: 64, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      const Text('Aucune catégorie de boutique disponible',
                          style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      const Text(
                          'Contactez l\'administrateur pour créer des catégories',
                          style: AppTheme.caption,
                          textAlign: TextAlign.center),
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
                        // Catégorie
                        const Text('Catégorie de boutique *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<Category>(  // ← Changé
                          value: _selectedCategory,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.category),
                            hintText: 'Sélectionner une catégorie',
                          ),
                          items: _categories.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Row(children: [
                                Text(cat.name),
                              ]),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedCategory = val),
                          validator: (v) =>
                              v == null ? 'Catégorie requise' : null,
                        ),
                        const SizedBox(height: 20),

                        // Nom
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nom de la boutique *',
                            hintText: 'Ex: Tech Paradise',
                            prefixIcon: Icon(Icons.store),
                          ),
                          validator: (v) => v == null || v.trim().length < 2
                              ? 'Minimum 2 caractères'
                              : v.trim().length > 100
                                  ? 'Maximum 100 caractères'
                                  : null,
                        ),
                        const SizedBox(height: 16),

                        // Description
                        TextFormField(
                          controller: _descCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description (optionnel)',
                            hintText:
                                'Décrivez votre boutique et ce que vous vendez',
                            prefixIcon: Icon(Icons.description),
                          ),
                          validator: (v) => v != null && v.trim().length > 1000
                              ? 'Maximum 1000 caractères'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Adresse
                        TextFormField(
                          controller: _addressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Adresse (optionnel)',
                            hintText: 'Ex: 123 Rue du Commerce, Lomé',
                            prefixIcon: Icon(Icons.location_on),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Téléphone
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Téléphone (optionnel)',
                            hintText: 'Ex: +22890123456',
                            prefixIcon: Icon(Icons.phone),
                          ),
                          validator: (v) {
                            if (v != null &&
                                v.isNotEmpty &&
                                (v.length < 8 || v.length > 15)) {
                              return 'Entre 8 et 15 caractères';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email (optionnel)',
                            hintText: 'Ex: contact@techparadise.com',
                            prefixIcon: Icon(Icons.email),
                          ),
                          validator: (v) {
                            if (v != null && v.isNotEmpty) {
                              final emailRegex = RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (!emailRegex.hasMatch(v)) {
                                return 'Email invalide';
                              }
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 32),

                        // Bouton créer
                        ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Créer la boutique',
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
// ÉCRAN D'UPLOAD DES IMAGES (inchangé)
// ═══════════════════════════════════════════════════════════════════════════════

class UploadStoreImagesScreen extends StatefulWidget {
  final Store store;
  const UploadStoreImagesScreen({super.key, required this.store});

  @override
  State<UploadStoreImagesScreen> createState() =>
      _UploadStoreImagesScreenState();
}

class _UploadStoreImagesScreenState extends State<UploadStoreImagesScreen> {
  File? _logoFile;
  File? _bannerFile;
  bool _uploading = false;

  Future<void> _pickImage(bool isLogo) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: isLogo ? 500 : 1200,
        maxHeight: isLogo ? 500 : 600,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          if (isLogo) {
            _logoFile = File(image.path);
          } else {
            _bannerFile = File(image.path);
          }
        });
      }
    } catch (e) {
      print('❌ Error picking image: $e');
    }
  }

  Future<void> _upload() async {
    if (_logoFile == null && _bannerFile == null) {
      Navigator.pop(context);
      return;
    }

    setState(() => _uploading = true);

    try {
      final api = ApiService();
      final uploadService = UploadService(api);

      // Upload logo
      if (_logoFile != null) {
        print('📤 Uploading logo...');
        await uploadService.uploadStoreLogo(widget.store.id, _logoFile!);
        print('✅ Logo uploaded');
      }

      // Upload bannière
      if (_bannerFile != null) {
        print('📤 Uploading banner...');
        await uploadService.uploadStoreBanner(widget.store.id, _bannerFile!);
        print('✅ Banner uploaded');
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Images uploadées avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error uploading images: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter des images'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ajoutez un logo et une bannière pour rendre votre boutique plus attractive',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // Logo
            const Text('Logo de la boutique',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _pickImage(true),
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _logoFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_logoFile!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Appuyez pour ajouter un logo',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade600)),
                        ],
                      ),
              ),
            ),
            if (_logoFile != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _logoFile = null),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text('Supprimer',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Bannière
            const Text('Bannière de la boutique',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _pickImage(false),
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _bannerFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_bannerFile!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Appuyez pour ajouter une bannière',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade600)),
                        ],
                      ),
              ),
            ),
            if (_bannerFile != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _bannerFile = null),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text('Supprimer',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
            ],

            const Spacer(),

            // Boutons
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _uploading ? null : () => Navigator.pop(context),
                  child: const Text('Passer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _uploading ? null : _upload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: _uploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Enregistrer'),
                ),
              ),
            ]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}