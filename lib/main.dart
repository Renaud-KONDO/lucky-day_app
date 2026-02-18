import 'package:flutter/material.dart';
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
}