import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../raffle/raffles_screen.dart';
import '../store/stores_screen.dart';
import '../raffle/my_raffles_screen.dart';
import '../profile/profile_screen.dart';
import '../../providers/notification_provider.dart';
import '../notifications/notifications_screen.dart';


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
