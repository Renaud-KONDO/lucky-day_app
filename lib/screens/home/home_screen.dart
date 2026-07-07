/* import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../raffle/raffles_screen.dart';
import '../store/stores_screen.dart';
import '../raffle/my_raffles_screen.dart';
import '../profile/profile_screen.dart';
import '../../providers/notification_provider.dart';
//import '../notifications/notifications_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _screens = const [
    RafflesScreen(),
    StoresScreen(),
    MyRafflesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      context.read<NotificationProvider>().fetchUnreadCount();
    } catch (e) {
      print('❌ Failed to fetch notifications: $e');
    }    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, _) {
          return NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: Colors.white,
            indicatorColor: AppTheme.primaryColor.withOpacity(0.1),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: AppTheme.primaryColor),
                label: AppStrings.home,
              ),
              const NavigationDestination(
                icon: Icon(Icons.store_outlined),
                selectedIcon: Icon(Icons.store, color: AppTheme.primaryColor),
                label: AppStrings.stores,
              ),
              const NavigationDestination(
                icon: Icon(Icons.confirmation_number_outlined),
                selectedIcon: Icon(Icons.confirmation_number, color: AppTheme.primaryColor),
                label: AppStrings.myRaffles,
              ),
              NavigationDestination(
                icon: _buildProfileIcon(
                  Icons.person_outline,
                  notificationProvider.unreadCount,
                  false,
                ),
                selectedIcon: _buildProfileIcon(
                  Icons.person,
                  notificationProvider.unreadCount,
                  true,
                ),
                label: AppStrings.profile,
              ),
            ],
          );
        },
      ),
    );
  }

  /* Widget _buildProfileIcon(IconData icon, int unreadCount, bool isSelected) {
    return Stack(
      children: [
        Icon(icon, color: isSelected ? AppTheme.primaryColor : null),
        if (unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  } */

  Widget _buildProfileIcon(IconData icon, int unreadCount, bool isSelected) {
    return Stack(
      clipBehavior: Clip.none, 
      children: [
        Icon(icon, color: isSelected ? AppTheme.primaryColor : null),
        if (unreadCount > 0)
          Positioned(
            right: -8, 
            top: -4,   
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
 */


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/sse_service.dart';
import '../raffle/raffles_screen.dart';
import '../store/stores_screen.dart';
import '../raffle/my_raffles_screen.dart';
import '../profile/profile_screen.dart';
import '../../providers/notification_provider.dart';
import '../../providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _sseInitialized = false;

  final _screens = const [
    RafflesScreen(),
    StoresScreen(),
    MyRafflesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fetch initial unread count
      try {
        context.read<NotificationProvider>().fetchUnreadCount();
      } catch (e) {
        print('❌ Failed to fetch notifications: $e');
      }
      
      // ✅ Initialiser les abonnements SSE globaux (notifications + wallet)
      if (!_sseInitialized) {
        _initializeGlobalSSE();
        _sseInitialized = true;
      }
    });
  }

  /// ✅ Initialiser les abonnements globaux (Notifications + Wallet uniquement)
  /// Les raffles seront gérées dans RafflesScreen
  Future<void> _initializeGlobalSSE() async {
    print('🏠 HomeScreen: Initializing global SSE subscriptions...');
    
    final sse = SSEService();

    // ═══════════════════════════════════════════════════════════
    // CALLBACK NOTIFICATIONS
    // ═══════════════════════════════════════════════════════════
    
    sse.onNewNotification = (data) {
      if (!mounted) return;
      print('🔔 [HomeScreen] New notification: $data');
      
      final title = data['title'] as String?;
      final message = data['message'] as String?;
      
      // Rafraîchir le compteur
      context.read<NotificationProvider>().fetchUnreadCount();
      
      // Afficher un snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title ?? 'Nouvelle notification',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (message != null && message.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          action: SnackBarAction(
            label: 'Voir',
            textColor: Colors.white,
            onPressed: () {
              // TODO: Navigation vers les notifications
              setState(() => _index = 3); // Profil (où se trouvent les notifications)
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    };

    sse.onUnreadCountUpdate = (count) {
      if (!mounted) return;
      print('🔔 [HomeScreen] Unread count: $count');
      
      // Mettre à jour le badge localement
      context.read<NotificationProvider>().updateUnreadCountLocally(count);
    };

    // ═══════════════════════════════════════════════════════════
    // CALLBACK WALLET
    // ═══════════════════════════════════════════════════════════
    
    sse.onWalletUpdate = (data) {
      if (!mounted) return;
      print('💰 [HomeScreen] Wallet updated: $data');
      
      final newBalance = data['newBalance'];
      final change = data['change'];
      final reason = data['reason'] as String?;
      final type = data['type'] as String?;
      
      // Rafraîchir le profil pour obtenir le nouveau solde
      context.read<AuthProvider>().refreshProfile();

      // Afficher une notification si changement significatif
      if (change != null) {
        final changeValue = change is num 
            ? change.toDouble() 
            : double.tryParse(change.toString()) ?? 0;
        
        if (changeValue.abs() > 0) {
          final isCredit = type == 'credit' || changeValue > 0;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      reason ?? 
                      '${isCredit ? "Crédit" : "Débit"} : ${changeValue.abs().toStringAsFixed(0)} XOF'
                    ),
                  ),
                ],
              ),
              backgroundColor: isCredit ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    };

    // ✅ S'abonner uniquement aux notifications et wallet (pas de raffles ici)
    final success = await sse.subscribeToAll(raffleIds: []);
    
    if (success) {
      print('✅ [HomeScreen] Global SSE subscriptions initialized');
    } else {
      print('❌ [HomeScreen] Failed to initialize global SSE subscriptions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, _) {
          return NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: Colors.white,
            indicatorColor: AppTheme.primaryColor.withOpacity(0.1),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: AppTheme.primaryColor),
                label: AppStrings.home,
              ),
              const NavigationDestination(
                icon: Icon(Icons.store_outlined),
                selectedIcon: Icon(Icons.store, color: AppTheme.primaryColor),
                label: AppStrings.stores,
              ),
              const NavigationDestination(
                icon: Icon(Icons.confirmation_number_outlined),
                selectedIcon: Icon(Icons.confirmation_number, color: AppTheme.primaryColor),
                label: AppStrings.myRaffles,
              ),
              NavigationDestination(
                icon: _buildProfileIcon(
                  Icons.person_outline,
                  notificationProvider.unreadCount,
                  false,
                ),
                selectedIcon: _buildProfileIcon(
                  Icons.person,
                  notificationProvider.unreadCount,
                  true,
                ),
                label: AppStrings.profile,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileIcon(IconData icon, int unreadCount, bool isSelected) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: isSelected ? AppTheme.primaryColor : null),
        if (unreadCount > 0)
          Positioned(
            right: -8,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}