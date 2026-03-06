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
          _infoRow(Icons.alternate_email, "Nom d'utilisateur", widget.user.username, onEdit: () => _showChangeUsernameDialog(context),),
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

  /* Widget _infoRow(IconData icon, String label, String value) => Padding(
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
  ); */

  Widget _infoRow(IconData icon, String label, String value, {VoidCallback? onEdit}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Icon(icon, color: AppTheme.primaryColor, size: 20),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ]),
      ),
      if (onEdit != null)
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          color: AppTheme.primaryColor,
          onPressed: onEdit,
          tooltip: 'Modifier',
        ),
    ]),
  );

  void _showChangeUsernameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ChangeUsernameDialog(currentUsername: widget.user.username),
    );
  }
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

// ═══════════════════════════════════════════════════════════════════════════════
// DIALOG : CHANGER LE NOM D'UTILISATEUR
// ═══════════════════════════════════════════════════════════════════════════════

/* class _ChangeUsernameDialog extends StatefulWidget {
  final String currentUsername;
  const _ChangeUsernameDialog({required this.currentUsername});

  @override
  State<_ChangeUsernameDialog> createState() => _ChangeUsernameDialogState();
}

class _ChangeUsernameDialogState extends State<_ChangeUsernameDialog> {
  final _usernameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  String? _errorMessage;
  List<String>? _suggestions;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAndChangeUsername() async {
    if (!_formKey.currentState!.validate()) return;

    final newUsername = _usernameCtrl.text.trim();
    if (newUsername == widget.currentUsername) {
      setState(() {
        _errorMessage = 'Ce nom d\'utilisateur est déjà le vôtre';
        _suggestions = null;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
      _suggestions = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final ok = await auth.changeUsername(newUsername);

      if (ok) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Nom d\'utilisateur modifié avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // ✅ Le backend a renvoyé une erreur avec des suggestions
        setState(() {
          _errorMessage = auth.errorMessage ?? 'Nom d\'utilisateur non disponible';
          
          // ✅ Récupérer les suggestions si disponibles
          // (on suppose que le backend renvoie un format spécifique)
          _suggestions = auth.usernameSuggestions;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de connexion';
        _suggestions = null;
      });
    }

    setState(() => _submitting = false);
  }

  void _selectSuggestion(String suggestion) {
    _usernameCtrl.text = suggestion;
    setState(() {
      _errorMessage = null;
      _suggestions = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.alternate_email,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Changer de nom d\'utilisateur',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Actuel : @${widget.currentUsername}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),

              // Champ de saisie
              TextFormField(
                controller: _usernameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nouveau nom d\'utilisateur',
                  hintText: 'Ex: john_doe',
                  prefixText: '@',
                  prefixIcon: const Icon(Icons.person_outline),
                  errorText: _errorMessage,
                  helperText: '3-20 caractères, lettres, chiffres, underscore',
                  helperMaxLines: 2,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Nom d\'utilisateur requis';
                  }
                  if (v.trim().length < 3) {
                    return 'Minimum 3 caractères';
                  }
                  if (v.trim().length > 20) {
                    return 'Maximum 20 caractères';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                    return 'Uniquement lettres, chiffres et underscore';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ✅ Suggestions si le nom est déjà pris
              if (_suggestions != null && _suggestions!.isNotEmpty) ...[
                const Text(
                  'Suggestions disponibles :',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions!.map((suggestion) {
                    return ActionChip(
                      label: Text('@$suggestion'),
                      avatar: const Icon(Icons.check_circle_outline, size: 16),
                      onPressed: () => _selectSuggestion(suggestion),
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                      side: BorderSide(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Votre nom d\'utilisateur sera vérifié avant d\'être changé',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Boutons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _checkAndChangeUsername,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Valider'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
 */
// ═══════════════════════════════════════════════════════════════════════════════
// DIALOG : CHANGER LE NOM D'UTILISATEUR
// ═══════════════════════════════════════════════════════════════════════════════

class _ChangeUsernameDialog extends StatefulWidget {
  final String currentUsername;
  const _ChangeUsernameDialog({required this.currentUsername});

  @override
  State<_ChangeUsernameDialog> createState() => _ChangeUsernameDialogState();
}

class _ChangeUsernameDialogState extends State<_ChangeUsernameDialog> {
  final _usernameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAndChangeUsername() async {
    if (!_formKey.currentState!.validate()) return;

    final newUsername = _usernameCtrl.text.trim();
    
    // ✅ Vérifier si c'est le même username
    if (newUsername == widget.currentUsername) {
      // Mettre à jour manuellement l'erreur dans le provider
      final auth = context.read<AuthProvider>();
      auth.setUsernameError('Ce nom d\'utilisateur est déjà le vôtre');
      return;
    }

    setState(() => _submitting = true);

    try {
      final auth = context.read<AuthProvider>();
      final ok = await auth.changeUsername(newUsername);

      if (ok && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Nom d\'utilisateur modifié avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Dialog error: $e');
    }

    if (mounted) {
      setState(() => _submitting = false);
    }
  }

  void _selectSuggestion(String suggestion) {
    _usernameCtrl.text = suggestion;
    // ✅ Nettoyer l'erreur quand on sélectionne une suggestion
    context.read<AuthProvider>().clearUsernameError();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          // ✅ Écouter les changements du provider
          child: Consumer<AuthProvider>(
            builder: (_, auth, __) {
              final errorMessage = auth.errorMessage;
              final suggestions = auth.usernameSuggestions ?? [];

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.alternate_email,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Changer de nom d\'utilisateur',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Actuel : @${widget.currentUsername}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Champ de saisie
                  TextFormField(
                    controller: _usernameCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Nouveau nom d\'utilisateur',
                      hintText: 'Ex: john_doe',
                      prefixText: '@',
                      prefixIcon: const Icon(Icons.person_outline),
                      // ✅ Afficher l'erreur du provider
                      errorText: errorMessage,
                      errorMaxLines: 2,
                      helperText: '3-20 caractères, lettres, chiffres, underscore',
                      helperMaxLines: 2,
                    ),
                    // ✅ Nettoyer l'erreur quand l'utilisateur tape
                    onChanged: (v) {
                      if (errorMessage != null) {
                        auth.clearUsernameError();
                      }
                    },
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Nom d\'utilisateur requis';
                      }
                      if (v.trim().length < 3) {
                        return 'Minimum 3 caractères';
                      }
                      if (v.trim().length > 20) {
                        return 'Maximum 20 caractères';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                        return 'Uniquement lettres, chiffres et underscore autorisés';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ✅ Suggestions si le nom est déjà pris
                  if (suggestions.isNotEmpty) ...[
                    const Text(
                      'Suggestions disponibles :',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestions.map((suggestion) {
                        return ActionChip(
                          label: Text('@$suggestion'),
                          avatar: const Icon(Icons.check_circle_outline, size: 16),
                          onPressed: () => _selectSuggestion(suggestion),
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                          side: BorderSide(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Votre nom d\'utilisateur sera vérifié avant d\'être changé',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Boutons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _submitting ? null : () => Navigator.pop(context),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _checkAndChangeUsername,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Valider'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}