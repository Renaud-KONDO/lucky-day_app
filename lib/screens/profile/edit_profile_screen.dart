import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../data/services/upload_service.dart';
import '../../data/services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Scaffold();

    // Badge couleur selon rôle
    Color roleColor;
    switch (user.role) {
      case 'super_admin': roleColor = Colors.purple; break;
      case 'admin':       roleColor = Colors.red;    break;
      case 'store_owner': roleColor = AppTheme.secondaryColor; break;
      default:            roleColor = AppTheme.blueLight;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Informations'),
            Tab(text: 'Modifier'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _InfoTab(user: user, roleColor: roleColor),
          _EditTab(user: user),
        ],
      ),
    );
  }
}

// ─── Tab : Affichage des infos ────────────────────────────────────────────────
/* class _InfoTab extends StatelessWidget {
  final dynamic user;
  final Color roleColor;
  const _InfoTab({required this.user, required this.roleColor});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Avatar grand format
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            gradient: AppTheme.blueGoldGradient,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Center(child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
          )),
        ),
        const SizedBox(height: 16),
        Text(user.fullName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        // Badge rôle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: roleColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: roleColor.withOpacity(0.5)),
          ),
          child: Text(user.roleLabel,
            style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const SizedBox(height: 28),

        // Infos
        _infoCard(context, [
          _infoRow(Icons.email_outlined, 'Email', user.email),
          if (user.phone != null && user.phone!.isNotEmpty)
            _infoRow(Icons.phone_outlined, 'Téléphone', user.phone!),
          _infoRow(Icons.verified_outlined, 'Email vérifié', user.isVerified ? 'Oui ✓' : 'Non'),
          _infoRow(Icons.calendar_today_outlined, 'Membre depuis',
            '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}'),
        ]),
        const SizedBox(height: 16),

        // Solde
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Solde portefeuille',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('${user.balance.toStringAsFixed(0)} ${AppStrings.currency}',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _infoCard(BuildContext context, List<Widget> children) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
    ),
    child: Column(children: children),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Icon(icon, color: AppTheme.primaryColor, size: 20),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ]),
    ]),
  );
}
 */
class _InfoTab extends StatefulWidget {
  final dynamic user;
  final Color roleColor;
  const _InfoTab({required this.user, required this.roleColor});

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab> {
  bool _uploading = false;
  Key _imageKey = UniqueKey();  


  Future<void> _pickAndUploadAvatar() async {
  final picker = ImagePicker();
  final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
  if (image == null) return;

  setState(() => _uploading = true);
  try {
    /* final authProvider = context.read<AuthProvider>();
    
    // Utilise l'API du provider existant (qui a le token)
    final api = ApiService();
    await api.setToken(await SharedPreferences.getInstance().then((prefs) => prefs.getString('auth_token') ?? ''));
    
    final uploadService = UploadService(api);
    final avatarUrl = await uploadService.uploadAvatar(File(image.path));
    
    print('✅ Avatar uploaded: $avatarUrl');
    
    
    // Refresh profile
    await authProvider.refreshProfile(); */

    final api = ApiService();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      if (token.isEmpty) throw Exception('No auth token');
      
      await api.setToken(token);
      
      final uploadService = UploadService(api);
      final avatarUrl = await uploadService.uploadAvatar(File(image.path));
      
      print('✅ Avatar uploaded: $avatarUrl');
      
      // Refresh profile
      final authProvider = context.read<AuthProvider>();
      await authProvider.refreshProfile();
      
      print('👤 New avatar: ${authProvider.currentUser?.avatar}');
    
    
    if (mounted) {
      // Force rebuild complet
      setState(() {
          _imageKey = UniqueKey();  // ← Nouvelle key pour forcer le rebuild
        });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo mise à jour !'), backgroundColor: Colors.green),
      );
    }
  } catch (e) {
    print('❌ Upload error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }
  setState(() => _uploading = false);
}
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Avatar avec bouton upload
        Stack(
          key: _imageKey,
          children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              gradient: widget.user.avatar != null && widget.user.avatar!.isNotEmpty 
                ? null 
                : AppTheme.blueGoldGradient,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 16, offset: const Offset(0, 6))],
              image: widget.user.avatar != null && widget.user.avatar!.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(
                      '${widget.user.avatar}?t=${DateTime.now().millisecondsSinceEpoch}',
                    ),
                    fit: BoxFit.cover,
                    onError: (exception, stackTrace) {
                      print('❌ Image load error: $exception');
                    },
                  )
                : null,
              ),
            child: widget.user.avatar == null || widget.user.avatar!.isEmpty
              ? Center(
                  child: Text(
                    widget.user.fullName.isNotEmpty 
                        ? widget.user.fullName[0].toUpperCase() 
                        : '?',
                    style: const TextStyle(
                      fontSize: 40, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.white,
                    ),
                  ),
                )
              : null,
          ),
          if (_uploading)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            )
          else
            Positioned(
              bottom: 0, right: 0,
              child: GestureDetector(
                onTap: _pickAndUploadAvatar,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.secondaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                ),
              ),
            ),
        ]),
        
        const SizedBox(height: 16),
        Text(widget.user.fullName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        
        // Badge rôle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: widget.roleColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.roleColor.withOpacity(0.5)),
          ),
          child: Text(widget.user.roleLabel,
            style: TextStyle(color: widget.roleColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const SizedBox(height: 28),

        // Reste inchangé (infos)
        _infoCard(context, [
          _infoRow(Icons.alternate_email, "Nom d'utilisateur", widget.user.username),
          _infoRow(Icons.email_outlined, 'Email', widget.user.email),
          if (widget.user.phone != null && widget.user.phone!.isNotEmpty)
            _infoRow(Icons.phone_outlined, 'Téléphone', widget.user.phone!),
          _infoRow(Icons.verified_outlined, 'Email vérifié', widget.user.isVerified ? 'Oui ✓' : 'Non'),
          _infoRow(Icons.calendar_today_outlined, 'Membre depuis',
            '${widget.user.createdAt.day}/${widget.user.createdAt.month}/${widget.user.createdAt.year}'),
        ]),
        const SizedBox(height: 16),

        // Solde
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Solde portefeuille',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('${widget.user.balance.toStringAsFixed(0)} ${AppStrings.currency}',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _infoCard(BuildContext context, List<Widget> children) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
    ),
    child: Column(children: children),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Icon(icon, color: AppTheme.primaryColor, size: 20),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ]),
    ]),
  );
}

// ─── Tab : Modifier les infos ─────────────────────────────────────────────────
class _EditTab extends StatefulWidget {
  final dynamic user;
  const _EditTab({required this.user});
  @override
  State<_EditTab> createState() => _EditTabState();
}

class _EditTabState extends State<_EditTab> {
  final _formKey   = GlobalKey<FormState>();
  late final _nameCtrl  = TextEditingController(text: widget.user.fullName);
  late final _phoneCtrl = TextEditingController(text: widget.user.phone ?? '');
  // Champ mot de passe
  final _curPassCtrl  = TextEditingController();
  final _newPassCtrl  = TextEditingController();
  final _confPassCtrl = TextEditingController();
  bool _obscureCur = true, _obscureNew = true, _obscureConf = true;

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _curPassCtrl.dispose(); _newPassCtrl.dispose(); _confPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Profil mis à jour !' : auth.errorMessage ?? 'Erreur'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _changePassword() async {
    if (_newPassCtrl.text != _confPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_newPassCtrl.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('8 caractères minimum'), backgroundColor: Colors.red),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.changePassword(
      current: _curPassCtrl.text,
      newPass: _newPassCtrl.text,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Mot de passe modifié !' : auth.errorMessage ?? 'Erreur'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) { _curPassCtrl.clear(); _newPassCtrl.clear(); _confPassCtrl.clear(); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [

        // ─── Section Infos personnelles ─────────────────────────────────────
        _sectionHeader(Icons.person_outline, 'Informations personnelles'),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => v == null || v.trim().length < 2 ? '2 caractères minimum' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: auth.isLoading ? null : _saveProfile,
              icon: auth.isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_outlined),
              label: const Text('Sauvegarder'),
            ),
          ]),
        ),

        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),

        // ─── Section Mot de passe ────────────────────────────────────────────
        _sectionHeader(Icons.lock_outline, 'Changer le mot de passe'),
        const SizedBox(height: 12),
        _passField(_curPassCtrl, 'Mot de passe actuel', _obscureCur,
          () => setState(() => _obscureCur = !_obscureCur)),
        const SizedBox(height: 16),
        _passField(_newPassCtrl, 'Nouveau mot de passe', _obscureNew,
          () => setState(() => _obscureNew = !_obscureNew)),
        const SizedBox(height: 16),
        _passField(_confPassCtrl, 'Confirmer le nouveau mot de passe', _obscureConf,
          () => setState(() => _obscureConf = !_obscureConf)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: auth.isLoading ? null : _changePassword,
          icon: const Icon(Icons.lock_reset),
          label: const Text('Modifier le mot de passe'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _sectionHeader(IconData icon, String title) => Row(children: [
    Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppTheme.primaryColor, size: 20),
    ),
    const SizedBox(width: 12),
    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
  ]);

  Widget _passField(TextEditingController ctrl, String label, bool obscure, VoidCallback toggle) =>
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
