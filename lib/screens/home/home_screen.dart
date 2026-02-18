import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../raffle/raffles_screen.dart';
import '../store/stores_screen.dart';
import '../raffle/my_raffles_screen.dart';
import '../profile/profile_screen.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primaryColor.withOpacity(0.1),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: AppTheme.primaryColor), label: AppStrings.home),
          NavigationDestination(icon: Icon(Icons.store_outlined), selectedIcon: Icon(Icons.store, color: AppTheme.primaryColor), label: AppStrings.stores),
          NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), selectedIcon: Icon(Icons.confirmation_number, color: AppTheme.primaryColor), label: AppStrings.myRaffles),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: AppTheme.primaryColor), label: AppStrings.profile),
        ],
      ),
    );
  }
}
