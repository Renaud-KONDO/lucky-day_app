import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _checkingUsername = false;
  bool _usernameAvailable = false;
  List<String> _suggestions = [];

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _usernameCtrl.dispose(); _passwordCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged() async {
    if (_nameCtrl.text.trim().length < 3) return;
    final auth = context.read<AuthProvider>();
    final suggestions = await auth.getSuggestedUsernames(_nameCtrl.text.trim());
    if (mounted) {
      setState(() => _suggestions = suggestions);
    }
  }

  void _onUsernameChanged(String value) async {
    if (value.length < 3) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = false;
      });
      return;
    }
    setState(() => _checkingUsername = true);
    final auth = context.read<AuthProvider>();
    final available = await auth.checkUsername(value);
    if (mounted) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = available;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_usernameCtrl.text.isNotEmpty && !_usernameAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ce nom d'utilisateur n'est pas disponible"),
          backgroundColor: Colors.red),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      fullName: _nameCtrl.text.trim(),
      email:    _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      phone:    _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      username: _usernameCtrl.text.trim().isEmpty ? null : _usernameCtrl.text.trim(),
    );
    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Erreur'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text("Créer un compte")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(children: [
              const SizedBox(height: 16),
              
              // Nom complet
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => v == null || v.trim().length < 2 ? '2 caractères minimum' : null,
                onChanged: (_) => _onNameChanged(),
              ),
              
              const SizedBox(height: 16),
              
              // Username (optionnel)
              TextFormField(
                controller: _usernameCtrl,
                decoration: InputDecoration(
                  labelText: "Nom d'utilisateur (optionnel)",
                  hintText: 'Laissez vide pour générer automatiquement',
                  prefixIcon: const Icon(Icons.alternate_email),
                  suffixIcon: _usernameCtrl.text.isEmpty
                      ? null
                      : _checkingUsername
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ))
                          : Icon(
                              _usernameAvailable ? Icons.check_circle : Icons.cancel,
                              color: _usernameAvailable ? Colors.green : Colors.red,
                            ),
                ),
                onChanged: _onUsernameChanged,
              ),
              
              // Suggestions
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _suggestions.map((s) => GestureDetector(
                      onTap: () {
                        _usernameCtrl.text = s;
                        _onUsernameChanged(s);
                      },
                      child: Chip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    )).toList(),
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Email
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined)),
                validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null,
              ),
              
              const SizedBox(height: 16),
              
              // Téléphone
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone (optionnel)',
                  prefixIcon: Icon(Icons.phone_outlined)),
              ),
              
              const SizedBox(height: 16),
              
              // Mot de passe
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length < 8) return '8 caractères minimum';
                  if (!v.contains(RegExp(r'[A-Z]'))) return 'Au moins une majuscule';
                  if (!v.contains(RegExp(r'[0-9]'))) return 'Au moins un chiffre';
                  return null;
                },
              ),
              
              const SizedBox(height: 28),
              
              // Bouton inscription
              ElevatedButton(
                onPressed: auth.isLoading ? null : _submit,
                child: auth.isLoading
                    ? const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("S'inscrire",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Déjà un compte ? Se connecter'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}