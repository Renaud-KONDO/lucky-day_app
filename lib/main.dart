/* import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'data/services/api_service.dart';
import 'data/repositories/lottery_repository.dart';
import 'data/repositories/store_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/raffle_provider.dart';
import 'providers/store_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'data/repositories/category_repository.dart';
import 'providers/category_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LuckyDayApp());
}

class LuckyDayApp extends StatelessWidget {
  const LuckyDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    final raffleRepository = RaffleRepository(apiService);
    final storeRepository = StoreRepository(apiService);
    final productRepository = ProductRepository(apiService);
    final categoryRepo = CategoryRepository(apiService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
        ChangeNotifierProvider(create: (_) => RaffleProvider(raffleRepository)),
        ChangeNotifierProvider(create: (_) => StoreProvider(storeRepository, productRepository)),
        ChangeNotifierProvider(create: (_) => CategoryProvider(categoryRepo)),
        
      ],
      child: MaterialApp(
        title: 'Lucky Day',
        debugShowCheckedModeBanner: false,
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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isAuthenticated) return const HomeScreen();
        return const LoginScreen();
      },
    );
  }
} */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize notification service
  await NotificationService.instance.initialize();
  
  runApp(const LuckyDayApp());
}

class LuckyDayApp extends StatelessWidget {
  const LuckyDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api          = ApiService();
    final raffRepo     = RaffleRepository(api);
    final storeRepo    = StoreRepository(api);
    final productRepo  = ProductRepository(api);
    final categoryRepo = CategoryRepository(api);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(api)),
        ChangeNotifierProvider(create: (_) => RaffleProvider(raffRepo)),
        ChangeNotifierProvider(create: (_) => StoreProvider(storeRepo, productRepo)),
        ChangeNotifierProvider(create: (_) => CategoryProvider(categoryRepo)),
        ChangeNotifierProvider(create: (_) => NotificationProvider(api)),
      
      ],
      child: MaterialApp(
        title: 'Lucky Day',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
        routes: {
          '/login':    (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/home':     (_) => const HomeScreen(),
        },
      ),
    );
  }
}

/* class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        // Register FCM token when authenticated
        /* if (auth.isAuthenticated) {
          NotificationService.instance.registerToken();
        } */ //not good cause it will be called multiple times and cause multiple token registrations, better to call it once after login in auth provider
        return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
      },
    );
  }
} */

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
        
        // ✅ Fetch les tombolas créées SEULEMENT si owner
        if (auth.currentUser?.isStoreOwner ?? false) {
          context.read<RaffleProvider>().fetchMyCreatedRaffles(auth.currentUser!.id);
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