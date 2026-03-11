/* import 'package:flutter/material.dart';
import 'package:lucky_day/data/repositories/notification_repository.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lucky_day/data/services/sse_service.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/services/api_service.dart';
import 'data/repositories/lottery_repository.dart';
import 'data/repositories/store_repository.dart';
import 'data/repositories/category_repository.dart';
import 'data/services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/raffle_provider.dart';
import 'providers/store_provider.dart';
import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/raffle/raffle_detail_screen.dart';
import 'data/models/models.dart';
import 'providers/notification_provider.dart';

// ✅ Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀🚀🚀 APP STARTING 🚀🚀🚀');

  // ✅ Initialiser le singleton ApiService AVANT tout
  final apiService = ApiService();
  print('✅ ApiService singleton initialized');

  // ✅ Configurer le callback d'expiration
  ApiService.setOnTokenExpired(() {
    print('🔴🔴🔴 TOKEN EXPIRED CALLBACK TRIGGERED 🔴🔴🔴');

    final context = navigatorKey.currentContext;

    if (context != null) {
      print('✅ Context available, showing snackbar and redirecting');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏱️ Votre session a expiré. Veuillez vous reconnecter.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      print('⚠️ Context is null, cannot show UI');
    }
  });

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize notification service
  await NotificationService.instance.initialize();

  // Configurer timeago en français
  timeago.setLocaleMessages('fr', timeago.FrMessages());

  print('✅ App initialization complete, launching LuckyDayApp');

  runApp(const LuckyDayApp());
}

class LuckyDayApp extends StatelessWidget {
  const LuckyDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();
    final raffRepo = RaffleRepository(api);
    final storeRepo = StoreRepository(api);
    final productRepo = ProductRepository(api);
    final categoryRepo = CategoryRepository(api);
    final notifRepo = NotificationRepository(api);
    final transactionRepo = TransactionRepository(api);

    print('✅ All repositories initialized with ApiService singleton');

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(api)),
        ChangeNotifierProvider(create: (_) => RaffleProvider(raffRepo)),
        ChangeNotifierProvider(create: (_) => StoreProvider(storeRepo, productRepo)),
        ChangeNotifierProvider(create: (_) => CategoryProvider(categoryRepo)),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(notifRepo)..fetchUnreadCount(),
        ),
        ChangeNotifierProvider(create: (_) => TransactionProvider(transactionRepo)),

      ],
      child: MaterialApp(
        title: 'Lucky Day',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/home': (_) => const HomeScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    
    // ✅ Enregistrer le callback de notification ICI (après l'init des providers)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔔 Registering notification tap callback...');
      
      NotificationService.setOnNotificationTap((data) {
        print('🔔 Notification tapped with data: $data');
        _handleNotificationNavigation(data);
      });
      
      final auth = context.read<AuthProvider>();

      if (auth.isAuthenticated) {
        // Refresh le profil
        auth.refreshProfile();

        //Initialiser le SSE
        _initializeSSE();

        // Fetch les tombolas créées SEULEMENT si owner
        if (auth.currentUser?.isStoreOwner ?? false) {
          context
              .read<RaffleProvider>()
              .fetchMyCreatedRaffles(auth.currentUser!.id);
        }
      }
    });
  }

  void _initializeSSE() {
    final sse = SSEService();
    
    // Connecter
    sse.connect();

    // ✅ Callback pour les mises à jour de tombola
    sse.onRaffleUpdate = (data) {
      print('🎲 Raffle updated: $data');
      
      // Rafraîchir les listes de tombolas
      context.read<RaffleProvider>().fetchAll();
      
      final auth = context.read<AuthProvider>();
      if (auth.currentUser?.isStoreOwner ?? false) {
        context.read<RaffleProvider>().fetchMyCreatedRaffles(auth.currentUser!.id);
      }
    };

    // ✅ Callback pour les nouvelles notifications
    sse.onNewNotification = (data) {
      print('🔔 New notification: $data');
      
      // Rafraîchir le compteur de notifications
      context.read<NotificationProvider>().fetchUnreadCount();
      
      // Afficher un snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['title']?.toString() ?? 'Nouvelle notification'),
            action: SnackBarAction(
              label: 'Voir',
              onPressed: () {
                // Naviguer vers les notifications
                Navigator.pushNamed(context, '/notifications');
              },
            ),
          ),
        );
      }
    };

    // ✅ Callback pour les mises à jour de solde
    sse.onBalanceUpdate = (data) {
      print('💰 Balance updated: $data');
      
      // Rafraîchir le profil pour obtenir le nouveau solde
      context.read<AuthProvider>().refreshProfile();
    };

    // ✅ Callback pour les gagnants tirés
    sse.onWinnerDrawn = (data) {
      print('🏆 Winner drawn: $data');
      
      final raffleId = data['raffleId'] as String?;
      final winnerId = data['winnerId'] as String?;
      final auth = context.read<AuthProvider>();
      
      // Rafraîchir les listes
      context.read<RaffleProvider>().fetchAll();
      context.read<RaffleProvider>().fetchMine();
      context.read<RaffleProvider>().fetchWins();
      
      // Si je suis le gagnant, afficher une alerte
      if (winnerId == auth.currentUser?.id && mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                SizedBox(width: 12),
                Text('🎉 Félicitations !'),
              ],
            ),
            content: Text(data['title']?.toString() ?? 'Vous avez gagné une tombola !'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Super !'),
              ),
            ],
          ),
        );
      }
    };

    // ✅ Callback pour les tombolas annulées
    sse.onRaffleCancelled = (data) {
      print('❌ Raffle cancelled: $data');
      
      // Rafraîchir les listes
      context.read<RaffleProvider>().fetchAll();
      context.read<RaffleProvider>().fetchMine();
      
      final auth = context.read<AuthProvider>();
      if (auth.currentUser?.isStoreOwner ?? false) {
        context.read<RaffleProvider>().fetchMyCreatedRaffles(auth.currentUser!.id);
      }
    };
  }

  @override
  void dispose() {
    // Déconnecter SSE lors de la destruction du widget
    SSEService().disconnect();
    super.dispose();
  }
  // Fonction pour gérer la navigation depuis les notifications
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    print('🔔 _handleNotificationNavigation called with data: $data');
    
    final type = data['type'] as String?;
    final raffleId = data['raffleId'] as String?;
    final screen = data['screen'] as String?;

    print('🔔 Parsed: type=$type, raffleId=$raffleId, screen=$screen');

    if (screen == 'raffle_detail_screen' && raffleId != null) {
      print('🔔 Navigating to RaffleDetailScreen for raffle $raffleId');
      
      // ✅ Utiliser navigatorKey.currentContext au lieu de context
      final context = navigatorKey.currentContext;
      
      if (context == null) {
        print('⚠️ navigatorKey.currentContext is null, cannot navigate');
        return;
      }

      // ✅ Récupérer le raffle depuis le provider
      final raffleProvider = context.read<RaffleProvider>();
      
      // Chercher le raffle dans les listes
      Raffle? raffle;
      
      try {
        raffle = raffleProvider.allRaffles.firstWhere((r) => r.id == raffleId);
        print('✅ Found raffle in allRaffles');

      } catch (_) {
        try {
          raffle = raffleProvider.myRaffles.firstWhere((r) => r.id == raffleId);
          print('✅ Found raffle in myRaffles');
        } catch (_) {
          try {
            raffle = raffleProvider.myWins.firstWhere((r) => r.id == raffleId);
            print('✅ Found raffle in myWins');
          } catch (_) {
            try {
              raffle = raffleProvider.myCreatedRaffles.firstWhere((r) => r.id == raffleId);
              print('✅ Found raffle in myCreatedRaffles');
            } catch (_) {
              print('⚠️ Raffle $raffleId not found in any list, creating minimal raffle');
              
              // ✅ Créer un raffle minimal pour pouvoir naviguer
              raffle = Raffle(
                id: raffleId,
                title: 'Chargement...',
                description: '',
                entryPrice: 0,
                maxParticipants: 0,
                currentParticipants: 0,
                status: 'open',
                probabilityType: 'medium',
                autoDrawEnabled: false,
                cashOptionAvailable: false,
                createdAt: DateTime.now(),
                storeId: '',
                product: null,
              );
            }
          }
        }
      }

      // ✅ Naviguer vers RaffleDetailScreen
      if (raffle != null) {
        print('🔔 Pushing RaffleDetailScreen to navigator...');
        
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => RaffleDetailScreen(raffle: raffle!),
          ),
        ).then((_) {
          print('✅ Navigation completed');
        }).catchError((error) {
          print('❌ Navigation error: $error');
        });
      } else {
        print('❌ Raffle is null, cannot navigate');
      }
    } else {
      print('⚠️ Unknown notification type or missing data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        if (auth.isAuthenticated) {
          NotificationService.instance.registerToken();
        }else {
          // Déconnecter SSE si déconnecté
          SSEService().disconnect();
        }
        return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
      },
    );
  }
} */

import 'package:flutter/material.dart';
import 'package:lucky_day/data/repositories/notification_repository.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lucky_day/data/services/sse_service.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/services/api_service.dart';
import 'data/repositories/lottery_repository.dart';
import 'data/repositories/store_repository.dart';
import 'data/repositories/category_repository.dart';
import 'data/services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/raffle_provider.dart';
import 'providers/store_provider.dart';
import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/raffle/raffle_detail_screen.dart';
import 'data/models/models.dart';
import 'providers/notification_provider.dart';

// ✅ Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀🚀🚀 APP STARTING 🚀🚀🚀');

  // ✅ Initialiser le singleton ApiService
  final apiService = ApiService();
  print('✅ ApiService singleton initialized');

  // ✅ Configurer le callback d'expiration du token
  ApiService.setOnTokenExpired(() {
    print('🔴🔴🔴 TOKEN EXPIRED CALLBACK TRIGGERED 🔴🔴🔴');

    final context = navigatorKey.currentContext;

    if (context != null) {
      print('✅ Context available, showing snackbar and redirecting');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏱️ Votre session a expiré. Veuillez vous reconnecter.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      print('⚠️ Context is null, cannot show UI');
    }
  });

  // ✅ Initialize Firebase
  await Firebase.initializeApp();
  print('✅ Firebase initialized');

  // ✅ Initialize notification service
  await NotificationService.instance.initialize();
  print('✅ NotificationService initialized');

  // ✅ Configurer timeago en français
  timeago.setLocaleMessages('fr', timeago.FrMessages());

  print('✅ App initialization complete, launching LuckyDayApp');

  runApp(const LuckyDayApp());
}

class LuckyDayApp extends StatelessWidget {
  const LuckyDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Utiliser le singleton partout
    final api = ApiService();
    
    // ✅ Créer les repositories
    final raffRepo = RaffleRepository(api);
    final storeRepo = StoreRepository(api);
    final productRepo = ProductRepository(api);
    final categoryRepo = CategoryRepository(api);
    final notifRepo = NotificationRepository(api);
    final transactionRepo = TransactionRepository(api);

    print('✅ All repositories initialized with ApiService singleton');

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(api)),
        ChangeNotifierProvider(create: (_) => RaffleProvider(raffRepo)),
        ChangeNotifierProvider(create: (_) => StoreProvider(storeRepo, productRepo)),
        ChangeNotifierProvider(create: (_) => CategoryProvider(categoryRepo)),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(notifRepo)..fetchUnreadCount(),
        ),
        ChangeNotifierProvider(create: (_) => TransactionProvider(transactionRepo)),
      ],
      child: MaterialApp(
        title: 'Lucky Day',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/home': (_) => const HomeScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔔 Registering callbacks...');
      
      // ✅ Enregistrer le callback de notification
      NotificationService.setOnNotificationTap((data) {
        print('🔔 Notification tapped with data: $data');
        _handleNotificationNavigation(data);
      });
      
      final auth = context.read<AuthProvider>();

      if (auth.isAuthenticated) {
        print('✅ User is authenticated, initializing services');
        
        // Refresh le profil
        auth.refreshProfile();

        // ✅ Initialiser le SSE
        _initializeSSE();

        // Fetch les tombolas créées si owner
        if (auth.currentUser?.isStoreOwner ?? false) {
          context.read<RaffleProvider>().fetchMyCreatedRaffles(auth.currentUser!.id);
        }
      } else {
        print('⚠️ User not authenticated, skipping SSE initialization');
      }
    });
  }

  /// ✅ Initialiser SSE et ses callbacks
  void _initializeSSE() {
    print('⚡ Initializing SSE...');
    
    final sse = SSEService();
    
    // Connecter
    sse.connect();

    // ✅ Callback pour raffle:update (mise à jour générale)
    sse.onRaffleUpdate = (data) {
      if (!mounted) return;
      
      print('🎲 Raffle updated: $data');
      
      // Rafraîchir les listes de tombolas
      context.read<RaffleProvider>().fetchAll();
    };

    // ✅ Callback pour raffle:status_change (open -> full -> completed)
    sse.onRaffleStatusChange = (data) {
      if (!mounted) return;
      
      print('📊 Raffle status changed: $data');
      
      final raffleId = data['raffleId'] as String?;
      final newStatus = data['newStatus'] as String?;
      final oldStatus = data['oldStatus'] as String?;
      
      print('Raffle $raffleId: $oldStatus -> $newStatus');
      
      // Rafraîchir toutes les listes
      context.read<RaffleProvider>().fetchAll();
      context.read<RaffleProvider>().fetchMine();
      
      final auth = context.read<AuthProvider>();
      if (auth.currentUser?.isStoreOwner ?? false) {
        context.read<RaffleProvider>().fetchMyCreatedRaffles(auth.currentUser!.id);
      }

      // Notifier l'utilisateur si c'est une de ses participations
      if (newStatus == 'full') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']?.toString() ?? 'Une tombola est maintenant complète !'),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };

    // ✅ Callback pour raffle:new_participant
    sse.onNewParticipant = (data) {
      if (!mounted) return;
      
      print('👤 New participant: $data');
      
      // Rafraîchir les listes pour mettre à jour le compteur
      context.read<RaffleProvider>().fetchAll();
      
      final auth = context.read<AuthProvider>();
      if (auth.currentUser?.isStoreOwner ?? false) {
        context.read<RaffleProvider>().fetchMyCreatedRaffles(auth.currentUser!.id);
      }
    };

    // ✅ Callback pour raffle:winner_drawn
    sse.onWinnerDrawn = (data) {
      if (!mounted) return;
      
      print('🏆 Winner drawn: $data');
      
      final raffleId = data['raffleId'] as String?;
      final winnerId = data['winnerId'] as String?;
      final winnerName = data['winnerName'] as String?;
      final raffleTitle = data['raffleTitle'] as String?;
      final auth = context.read<AuthProvider>();
      
      // Rafraîchir les listes
      context.read<RaffleProvider>().fetchAll();
      context.read<RaffleProvider>().fetchMine();
      context.read<RaffleProvider>().fetchWins();
      
      if (auth.currentUser?.isStoreOwner ?? false) {
        context.read<RaffleProvider>().fetchMyCreatedRaffles(auth.currentUser!.id);
      }
      
      // Si je suis le gagnant
      if (winnerId == auth.currentUser?.id) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                SizedBox(width: 12),
                Expanded(child: Text('🎉 Félicitations !', style: TextStyle(fontSize: 18))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Vous avez gagné la tombola :',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  raffleTitle ?? 'Tombola gagnée !',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Rendez-vous dans "Tombolas Gagnées" pour réclamer votre prix !',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Plus tard'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigation vers mes gains
                  // Navigator.pushNamed(context, '/my-raffles'); // À adapter
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                child: const Text('Voir mes gains'),
              ),
            ],
          ),
        );
      }
      // Si je suis le propriétaire de la tombola
      else if (auth.currentUser?.isStoreOwner ?? false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🏆 Gagnant tiré : ${winnerName ?? "Participant"}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    };

    // ✅ Callback pour raffle:cancelled
    sse.onRaffleCancelled = (data) {
      if (!mounted) return;
      
      print('❌ Raffle cancelled: $data');
      
      final raffleTitle = data['raffleTitle'] as String?;
      final reason = data['reason'] as String?;
      
      // Rafraîchir les listes
      context.read<RaffleProvider>().fetchAll();
      context.read<RaffleProvider>().fetchMine();
      
      final auth = context.read<AuthProvider>();
      if (auth.currentUser?.isStoreOwner ?? false) {
        context.read<RaffleProvider>().fetchMyCreatedRaffles(auth.currentUser!.id);
      }

      // Afficher une notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('❌ Tombola annulée : ${raffleTitle ?? ""}'),
              if (reason != null) ...[
                const SizedBox(height: 4),
                Text(reason, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    };

    // ✅ Callback pour notification:new
    sse.onNewNotification = (data) {
      if (!mounted) return;
      
      print('🔔 New notification: $data');
      
      final title = data['title'] as String?;
      final message = data['message'] as String?;
      
      // Rafraîchir le compteur de notifications
      context.read<NotificationProvider>().fetchUnreadCount();
      
      // Afficher un snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title ?? 'Nouvelle notification', 
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (message != null) ...[
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
              // Navigation vers les notifications
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    };

    // ✅ Callback pour user:balance_update
    sse.onBalanceUpdate = (data) {
      if (!mounted) return;
      
      print('💰 Balance updated: $data');
      
      final newBalance = data['newBalance'];
      final change = data['change'];
      final reason = data['reason'] as String?;
      
      // Rafraîchir le profil pour obtenir le nouveau solde
      context.read<AuthProvider>().refreshProfile();

      // Afficher une notification si changement significatif
      if (change != null) {
        final changeValue = change is num ? change.toDouble() : double.tryParse(change.toString()) ?? 0;
        if (changeValue.abs() > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                reason ?? 
                '💰 Solde ${changeValue > 0 ? "crédité" : "débité"} : ${changeValue.abs()} XOF'
              ),
              backgroundColor: changeValue > 0 ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    };
  }
  
  /// ✅ Gérer la navigation depuis les notifications
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    print('🔔 _handleNotificationNavigation called with data: $data');
    
    final type = data['type'] as String?;
    final raffleId = data['raffleId'] as String?;
    final screen = data['screen'] as String?;

    print('🔔 Parsed: type=$type, raffleId=$raffleId, screen=$screen');

    if (screen == 'raffle_detail_screen' && raffleId != null) {
      print('🔔 Navigating to RaffleDetailScreen for raffle $raffleId');
      
      final context = navigatorKey.currentContext;
      
      if (context == null) {
        print('⚠️ navigatorKey.currentContext is null, cannot navigate');
        return;
      }

      final raffleProvider = Provider.of<RaffleProvider>(context, listen: false);
      
      // Chercher le raffle dans les listes
      Raffle? raffle;
      
      try {
        raffle = raffleProvider.allRaffles.firstWhere((r) => r.id == raffleId);
        print('✅ Found raffle in allRaffles');
      } catch (_) {
        try {
          raffle = raffleProvider.myRaffles.firstWhere((r) => r.id == raffleId);
          print('✅ Found raffle in myRaffles');
        } catch (_) {
          try {
            raffle = raffleProvider.myWins.firstWhere((r) => r.id == raffleId);
            print('✅ Found raffle in myWins');
          } catch (_) {
            try {
              raffle = raffleProvider.myCreatedRaffles.firstWhere((r) => r.id == raffleId);
              print('✅ Found raffle in myCreatedRaffles');
            } catch (_) {
              print('⚠️ Raffle $raffleId not found, creating minimal raffle');
              
              raffle = Raffle(
                id: raffleId,
                title: 'Chargement...',
                description: '',
                entryPrice: 0,
                maxParticipants: 0,
                currentParticipants: 0,
                status: 'open',
                probabilityType: 'medium',
                autoDrawEnabled: false,
                cashOptionAvailable: false,
                createdAt: DateTime.now(),
                //updatedAt: DateTime.now(),
                storeId: '',
                product: null,
              );
            }
          }
        }
      }

      if (raffle != null) {
        print('🔔 Pushing RaffleDetailScreen...');
        
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => RaffleDetailScreen(raffle: raffle!),
          ),
        ).then((_) {
          print('✅ Navigation completed');
        }).catchError((error) {
          print('❌ Navigation error: $error');
        });
      }
    } else {
      print('⚠️ Unknown notification type or missing data');
    }
  }

  @override
  void dispose() {
    print('🔴 AuthWrapper disposing, disconnecting SSE...');
    SSEService().disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        if (auth.isAuthenticated) {
          NotificationService.instance.registerToken();
        } else {
          // Déconnecter SSE si déconnecté
          SSEService().disconnect();
        }
        
        return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}