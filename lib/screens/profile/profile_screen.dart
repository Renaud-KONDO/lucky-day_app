import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucky_day/data/services/sse_service.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/raffle_provider.dart';
import '../../widgets/loading_dialog.dart';
import '../auth/login_screen.dart';
import '../notifications/notifications_screen.dart';
import '../transactions/transactions_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final raffle = context.watch<RaffleProvider>();
    final user  = auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            child: const Text('Se connecter'),
          ),
        ),
      );
    }

    // Badge couleur selon rôle
    Color roleColor;
    switch (user.role) {
      case 'super_admin': roleColor = Colors.purple; break;
      case 'admin':       roleColor = Colors.red;    break;
      case 'store_owner': roleColor = AppTheme.secondaryColor; break;
      default:            roleColor = Colors.black;
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header dégradé bleu-or
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.blueGoldGradient),
                child: SafeArea(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(height: 24),
                   Stack(
                    children: [
                      // Image avec cache-busting
                      user.avatar != null && user.avatar!.isNotEmpty
                        ? CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            backgroundImage: NetworkImage(
                              '${user.avatar}?t=${DateTime.now().millisecondsSinceEpoch}',
                            ),
                            onBackgroundImageError: (exception, stackTrace) {
                              print('❌ Avatar load error: $exception');
                            },
                          )
                        : CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            child: Text(
                              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                      if (user.isVerified)
                        Positioned(bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                            child: const Icon(Icons.check, color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                    Text("${user.fullName} || @${user.username}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(user.email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 1),
                    // Badge rôle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      /* decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.25),
                        //borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: roleColor.withOpacity(0.6)),
                      ), */
                      child: Text("✪ compte " + user.roleLabel,
                        style: TextStyle(color: roleColor, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [

                
                // ✅ Indicateur de connexion SSE
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _SSEStatusIndicator(),
                ),
                const SizedBox(height: 16),
                // Solde
                /* Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppTheme.secondaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
                      const SizedBox(width: 16),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Solde du portefeuille', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(
                          '${user.balance.toStringAsFixed(0)} ${AppStrings.currency}',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ]),
                    ],
                  ),
                ), */
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppTheme.secondaryColor.withOpacity(0.3),
                      blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Solde du portefeuille',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('${user.balance.toStringAsFixed(0)} ${AppStrings.currency}',
                          style: const TextStyle(color: Colors.white, fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      ],
                    )),
                    // ← Bouton recharge
                    GestureDetector(
                      onTap: () => _showTopUpSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('Recharger', style: TextStyle(
                              color: Colors.white, fontSize: 12,
                              fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // Statistiques
                Row(children: [
                  _statCard('Participations', '${raffle.myRaffles.length}', Icons.confirmation_number, AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  _statCard('Gains', '${raffle.myWins.length}', Icons.emoji_events, AppTheme.secondaryColor),
                ]),
                const SizedBox(height: 24),

                _sectionTitle('Compte'),
                _menuItem(context, Icons.person_outline, 'Mon profil', () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
                _menuItem(context, Icons.lock_outline, 'Changer le mot de passe', () =>
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
                //_menuItem(context, Icons.history, 'Historique des transactions', () {}),
                _menuItem(
                  context,
                  Icons.history,
                  'Historique des transactions',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                _sectionTitle('Préférences'),

                Consumer<NotificationProvider>(
                  builder: (context, notificationProvider, _) {
                    return _menuItem(
                      context,
                      Icons.notifications_outlined,
                      'Notifications',
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                      badge: notificationProvider.unreadCount > 0 
                          ? notificationProvider.unreadCount 
                          : null,
                    );
                  },
                ),  

                /* Consumer<NotificationProvider>(
                builder: (context, notificationProvider, _) {
                  final unreadCount = notificationProvider.unreadCount;
                  
                  return ListTile(
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_outlined, color: AppTheme.primaryColor),
                        if (unreadCount > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Center(
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: const Text('Notifications'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  );
                },
              ), */
                //_menuItem(context, Icons.notifications_outlined, 'Notifications', () {}),
                _menuItem(context, Icons.help_outline, 'Aide & Support', () {}),
                _menuItem(context, Icons.info_outline, 'À propos', () {}),

                const SizedBox(height: 8),
                
                _menuItem(
                    context,
                    Icons.logout,
                    'Déconnexion',
                    () => _confirmLogout(context),
                    color: Colors.red,
                  ),

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // ✅ Afficher le loader
    LoadingDialog.show(context, message: 'Déconnexion en cours...');

    try {
      // Déconnexion
      await context.read<AuthProvider>().logout();

      if (context.mounted) {
        // Fermer le loader
        LoadingDialog.hide(context);

        // Rediriger vers la page de connexion
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ Logout error: $e');

      if (context.mounted) {
        // Fermer le loader
        LoadingDialog.hide(context);

        // Afficher l'erreur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la déconnexion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
    child: Text(title, style: const TextStyle(
      fontSize: 12, fontWeight: FontWeight.bold,
      color: AppTheme.textSecondary, letterSpacing: 1.2)),
  );

  Widget _statCard(String label, String value, IconData icon, Color color) =>
    Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: AppTheme.caption, textAlign: TextAlign.center),
      ]),
    ));

  Widget _menuItem(BuildContext context, IconData icon, String label,
      VoidCallback onTap, {Color? color, int? badge}) =>
    ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? AppTheme.primaryColor).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: color ?? AppTheme.primaryColor, size: 20),
            if (badge != null && badge > 0)
              Positioned(
                right: -12,
                top: -14,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    //borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  child: Center(
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      title: Text(label, style: TextStyle(
        color: color ?? AppTheme.textPrimary, fontWeight: FontWeight.w500)),
      trailing: color == null
        ? const Icon(Icons.chevron_right, color: AppTheme.textSecondary)
        : null,
      onTap: onTap,
    );



    void _showTopUpSheet(BuildContext context) {
      final _amountCtrl = TextEditingController();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Row(children: [
              Icon(Icons.account_balance_wallet, color: AppTheme.secondaryColor),
              SizedBox(width: 10),
              Text('Recharger mon compte',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 20),
            // Montants rapides
            const Text('Montant rapide',
              style: TextStyle(fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8,
              children: [5000, 10000, 25000, 50000, 100000].map((amount) =>
                OutlinedButton(
                  onPressed: () => _amountCtrl.text = amount.toString(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  child: Text('$amount XOF',
                    style: const TextStyle(fontSize: 12)),
                )
              ).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ou saisir un montant (XOF)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: appel API wallet/add-money
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fonctionnalité de paiement bientôt disponible'),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                );
              },
              icon: const Icon(Icons.add_card),
              label: const Text('Recharger'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      );
    }
}

class _SSEStatusIndicator extends StatefulWidget {
  const _SSEStatusIndicator();

  @override
  State<_SSEStatusIndicator> createState() => _SSEStatusIndicatorState();
}

class _SSEStatusIndicatorState extends State<_SSEStatusIndicator> {
  Timer? _timer;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    // Vérifier l'état toutes les secondes
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _isConnected = SSEService().isConnected;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Icône animée
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (_isConnected ? Colors.green : Colors.grey).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                _isConnected ? Icons.wifi : Icons.wifi_off,
                color: _isConnected ? Colors.green : Colors.grey,
                size: 20,
              ),
              if (_isConnected)
                Positioned.fill(
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation(
                      Colors.green.withOpacity(0.3),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Texte
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Connexion temps réel',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (_isConnected ? Colors.green : Colors.grey).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isConnected ? 'LIVE' : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _isConnected ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _isConnected
                    ? 'Mises à jour automatiques activées'
                    : 'Hors ligne - Rafraîchir manuellement',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),

        // Bouton d'action
        if (!_isConnected)
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              SSEService().connect();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reconnexion en cours...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Reconnecter',
          ),
      ],
    );
  }
}
