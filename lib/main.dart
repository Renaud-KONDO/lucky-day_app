/* import 'package:flutter/material.dart';
import 'package:lucky_day/data/repositories/notification_repository.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'core/theme/app_theme.dart';
import 'data/services/api_service.dart';
import 'data/repositories/lottery_repository.dart';
import 'data/repositories/store_repository.dart';
import 'data/repositories/category_repository.dart';
import 'data/services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/raffle_provider.dart';
import 'providers/store_provider.dart';
import 'providers/category_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'providers/notification_provider.dart';

// ✅ Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀🚀🚀 APP STARTING 🚀🚀🚀');

  // ✅ Initialiser le singleton ApiService AVANT tout
  final apiService = ApiService();
  print('✅ ApiService singleton initialized');

  // ✅ Configurer le callback d'expiration AVANT d'initialiser Firebase
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
    // ✅ Utiliser le singleton partout
    final api = ApiService();

    // ✅ Créer les repositories avec le singleton
    final raffRepo = RaffleRepository(api);
    final storeRepo = StoreRepository(api);
    final productRepo = ProductRepository(api);
    final categoryRepo = CategoryRepository(api);
    final notifRepo = NotificationRepository(api);

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
      final auth = context.read<AuthProvider>();

      if (auth.isAuthenticated) {
        // Refresh le profil
        auth.refreshProfile();

        // Fetch les tombolas créées SEULEMENT si owner
        if (auth.currentUser?.isStoreOwner ?? false) {
          context
              .read<RaffleProvider>()
              .fetchMyCreatedRaffles(auth.currentUser!.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        if (auth.isAuthenticated) {
          NotificationService.instance.registerToken();
        }
        return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
 */

import 'package:flutter/material.dart';
import 'package:lucky_day/data/repositories/notification_repository.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'core/theme/app_theme.dart';
import 'data/services/api_service.dart';
import 'data/repositories/lottery_repository.dart';
import 'data/repositories/store_repository.dart';
import 'data/repositories/category_repository.dart';
import 'data/services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/raffle_provider.dart';
import 'providers/store_provider.dart';
import 'providers/category_provider.dart';
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

        // Fetch les tombolas créées SEULEMENT si owner
        if (auth.currentUser?.isStoreOwner ?? false) {
          context
              .read<RaffleProvider>()
              .fetchMyCreatedRaffles(auth.currentUser!.id);
        }
      }
    });
  }

  // ✅ Fonction pour gérer la navigation depuis les notifications
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
        }
        return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}