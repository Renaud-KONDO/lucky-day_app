import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _curCtrl  = TextEditingController();
  final _newCtrl  = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _obscureCur = true, _obscureNew = true, _obscureConf = true;

  @override
  void dispose() {
    _curCtrl.dispose(); _newCtrl.dispose(); _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_curCtrl.text.isEmpty || _newCtrl.text.isEmpty || _confCtrl.text.isEmpty) {
      _snack('Remplissez tous les champs', Colors.red);
      return;
    }
    if (_newCtrl.text != _confCtrl.text) {
      _snack('Les mots de passe ne correspondent pas', Colors.red);
      return;
    }
    if (_newCtrl.text.length < 8) {
      _snack('8 caractères minimum', Colors.red);
      return;
    }
    if (!_newCtrl.text.contains(RegExp(r'[A-Z]'))) {
      _snack('Au moins une majuscule requise', Colors.red);
      return;
    }
    if (!_newCtrl.text.contains(RegExp(r'[0-9]'))) {
      _snack('Au moins un chiffre requis', Colors.red);
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.changePassword(
      current: _curCtrl.text,
      newPass: _newCtrl.text,
    );
    if (mounted) {
      _snack(
        ok ? 'Mot de passe modifié avec succès !' : auth.errorMessage ?? 'Erreur',
        ok ? Colors.green : Colors.red,
      );
      if (ok) Navigator.pop(context);
    }
  }

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Changer le mot de passe')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          // Icône
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.lock_reset, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text('Sécurisez votre compte',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          const SizedBox(height: 32),

          _passField(_curCtrl, 'Mot de passe actuel', _obscureCur,
            () => setState(() => _obscureCur = !_obscureCur)),
          const SizedBox(height: 16),
          _passField(_newCtrl, 'Nouveau mot de passe', _obscureNew,
            () => setState(() => _obscureNew = !_obscureNew)),
          const SizedBox(height: 16),
          _passField(_confCtrl, 'Confirmer le nouveau mot de passe',
            _obscureConf, () => setState(() => _obscureConf = !_obscureConf)),

          const SizedBox(height: 12),
          // Règles
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Le mot de passe doit contenir :',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
                SizedBox(height: 6),
                _Rule('Au moins 8 caractères'),
                _Rule('Au moins une majuscule (A-Z)'),
                _Rule('Au moins un chiffre (0-9)'),
              ],
            ),
          ),

          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: auth.isLoading ? null : _submit,
            child: auth.isLoading
              ? const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Modifier le mot de passe',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  Widget _passField(TextEditingController ctrl, String label,
      bool obscure, VoidCallback toggle) =>
    TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: toggle,
        ),
      ),
    );
}

class _Rule extends StatelessWidget {
  final String text;
  const _Rule(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      const Icon(Icons.check, size: 12, color: AppTheme.primaryColor),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 12,
          color: AppTheme.textSecondary)),
    ]),
  );
}