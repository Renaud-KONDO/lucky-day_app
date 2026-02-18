import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/store_provider.dart';
import '../../core/theme/app_theme.dart';

class CreateStoreScreen extends StatefulWidget {
  const CreateStoreScreen({super.key});
  @override
  State<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends State<CreateStoreScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _addressCtrl= TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _emailCtrl  = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _addressCtrl.dispose();
    _phoneCtrl.dispose(); _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final prov = context.read<StoreProvider>();
    final data = <String, dynamic>{'name': _nameCtrl.text.trim()};
    if (_descCtrl.text.isNotEmpty)    data['description'] = _descCtrl.text.trim();
    if (_addressCtrl.text.isNotEmpty) data['address']     = _addressCtrl.text.trim();
    if (_phoneCtrl.text.isNotEmpty)   data['phone']       = _phoneCtrl.text.trim();
    if (_emailCtrl.text.isNotEmpty)   data['email']       = _emailCtrl.text.trim();

    final store = await prov.createStore(data);
    if (store != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Boutique créée avec succès !'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(prov.errorMessage ?? 'Erreur'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<StoreProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Créer une boutique')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(children: [
            // Icône
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: AppTheme.blueGoldGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.store, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nom de la boutique *', prefixIcon: Icon(Icons.store_outlined)),
              validator: (v) => v == null || v.trim().length < 2 ? '2 caractères minimum' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined)),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Adresse', prefixIcon: Icon(Icons.location_on_outlined)),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email de contact', prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) {
                if (v != null && v.isNotEmpty && !v.contains('@')) return 'Email invalide';
                return null;
              },
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: prov.isLoading ? null : _submit,
              child: prov.isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Créer la boutique', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ),
    );
  }
}
