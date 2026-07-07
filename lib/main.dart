/* 
import 'package:flutter/material.dart';
import 'package:lucky_day/data/repositories/notification_repository.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lucky_day/data/services/sse_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_constants.dart';

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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 APP STARTING');

  final apiService = ApiService();
  print('✅ ApiService singleton initialized');

  ApiService.setOnTokenExpired(() {
    print('🔴 TOKEN EXPIRED CALLBACK TRIGGERED');

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

  await Firebase.initializeApp();
  print('✅ Firebase initialized');

  await NotificationService.instance.initialize();
  print('✅ NotificationService initialized');

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

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool _sseInitialized = false;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    
    // Monitor app lifecycle (background/foreground)
    WidgetsBinding.instance.addObserver(this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('🔔 Registering callbacks...');
      
      NotificationService.setOnNotificationTap((data) {
        print('🔔 Notification tapped with data: $data');
        _handleNotificationNavigation(data);
      });
      
      await _checkAndInitializeSSE();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    print('📱 App lifecycle state: $state');
    
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - reconnect SSE
      print('📱 App resumed, reconnecting SSE...');
      _reconnectSSE();
    } else if (state == AppLifecycleState.paused) {
      // App went to background - disconnect SSE
      print('📱 App paused, disconnecting SSE...');
      SSEService().disconnect();
      _sseInitialized = false;
    }
  }

  Future<void> _checkAndInitializeSSE() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    
    print('🔐 Token check: ${token != null ? "Present" : "Missing"}');
    
    if (token != null && mounted && !_sseInitialized) {
      print('✅ Token found, initializing services');
      
      final auth = context.read<AuthProvider>();
      
      // Refresh profile
      try {
        await auth.refreshProfile();
      } catch (e) {
        print('❌ Profile refresh failed (token may be expired): $e');
        _isInitializing = false;
        return;  // ← ABORT if token expired
      }
      
      // Wait a bit for profile to load
      //await Future.delayed(const Duration(milliseconds: 300));
      
      if (auth.isAuthenticated && mounted) {
        _initializeSSE();

        await _waitForSSEConnection();
        _sseInitialized = true;
        
        print('✅ [AuthWrapper] SSE initialization complete');

        // Fetch created raffles if owner
        if (auth.currentUser?.isStoreOwner ?? false) {
          context.read<RaffleProvider>().fetchMyCreatedRaffles(auth.currentUser!.id);
        }
      }
    } else if (token == null) {
      print('⚠️ No token found, skipping SSE initialization');
    }
  }

  Future<void> _waitForSSEConnection() async {
    final sse = SSEService();
    int attempts = 0;
    const maxAttempts = 10;
    
    while (!sse.isConnected && attempts < maxAttempts) {
      print('⏳ [AuthWrapper] Waiting for SSE connection... (${attempts + 1}/$maxAttempts)');
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
    
    if (sse.isConnected) {
      print('✅ [AuthWrapper] SSE is connected');
    } else {
      print('⚠️ [AuthWrapper] SSE connection timeout after ${attempts * 500}ms');
    }
  }


  Future<void> _reconnectSSE() async {
    if (_sseInitialized) {
      print('⚠️ SSE already initialized');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    
    if (token != null && mounted) {
      print('🔄 Reconnecting SSE...');
      _initializeSSE();
      _sseInitialized = true;
      
      // Resubscribe to raffles that are currently loaded
      await _resubscribeToRaffles();
    }
  }

  Future<void> _resubscribeToRaffles() async {
    print('🔄 Resubscribing to raffles...');
    
    final raffleProvider = context.read<RaffleProvider>();
    
    // Get all currently loaded raffles
    final allRaffleIds = raffleProvider.allRaffles.map((r) => r.id).toList();
    
    print('   Found ${allRaffleIds.length} raffles to subscribe to');
    
    if (allRaffleIds.isNotEmpty) {
      final sse = SSEService();
      
      // Wait a bit for SSE to be connected
      await Future.delayed(const Duration(seconds: 2));
      
      if (sse.isConnected) {
        await sse.subscribeToAll(
          raffleIds: allRaffleIds,
          notifications: true,
          wallet: true,
        );
        print('✅ Resubscribed to ${allRaffleIds.length} raffles');
      }
    }
  }

/*   void _initializeSSE() {
    print('⚡ [AuthWrapper] Initializing SSE...');
    
    final sse = SSEService();
    
    // Register SSE callbacks FIRST
    _registerSSECallbacks();
    
    // Connect to SSE stream
    sse.connect().then((_) {
      print('✅ [AuthWrapper] SSE connection initiated');
      
      // Wait for connection to be established
      Future.delayed(const Duration(seconds: 2), () {
        if (sse.isConnected) {
          print('✅ [AuthWrapper] SSE is connected, subscribing...');
          _performSubscriptions();
        } else {
          print('⚠️ [AuthWrapper] SSE not connected yet, retrying...');
          Future.delayed(const Duration(seconds: 2), () {
            if (sse.isConnected) {
              _performSubscriptions();
            }
          });
        }
      });
    });
  }
 */

  Future<void> _initializeSSE() async {
    print('⚡ [AuthWrapper] Initializing SSE...');
    
    final sse = SSEService();
    
    // Register SSE callbacks FIRST
    _registerSSECallbacks();
    
    // ✅ Connect to SSE stream et ATTENDRE
    await sse.connect();
    
    print('✅ [AuthWrapper] SSE connection initiated');
    
    // ✅ Attendre un peu pour laisser le temps à la connexion de s'établir
    await Future.delayed(const Duration(seconds: 2));
    
    if (sse.isConnected) {
      print('✅ [AuthWrapper] SSE is connected, subscribing...');
      await _performSubscriptions();
    } else {
      print('⚠️ [AuthWrapper] SSE not connected yet, will retry...');
      
      // Retry after delay
      await Future.delayed(const Duration(seconds: 2));
      
      if (sse.isConnected) {
        await _performSubscriptions();
      } else {
        print('❌ [AuthWrapper] SSE connection failed');
      }
    }
  }

  Future<void> _performSubscriptions() async {
    print('📊 [AuthWrapper] Performing subscriptions...');
    
    // Subscribe to notifications and wallet (without raffles for now)
    final success = await SSEService().subscribeToAll(raffleIds: []);
    
    if (success) {
      print('✅ [AuthWrapper] Subscribed to notifications + wallet');
    } else {
      print('❌ [AuthWrapper] Failed to subscribe');
    }
  }

  void _registerSSECallbacks() {
    print('📡 [AuthWrapper] Registering SSE callbacks...');
    
    final sse = SSEService();

    // ═══════════════════════════════════════════════════════════
    // RAFFLE CALLBACKS
    // ═══════════════════════════════════════════════════════════

    sse.onRaffleUpdate = (data) {
      if (!mounted) return;
      
      final eventData = data['data'] as Map<String, dynamic>? ?? data;
      
      print('🎲 [AuthWrapper] Raffle updated: $eventData');
      
      final raffleId = eventData['raffleId'] as String?;
      final currentParticipants = eventData['currentParticipants'] as int?;
      final maxParticipants = eventData['maxParticipants'] as int?;
      
      print('   Raffle ID: $raffleId');
      print('   Participants: $currentParticipants/$maxParticipants');
      
      context.read<RaffleProvider>().updateRaffleLocally(eventData);
    };

    sse.onNewParticipant = (data) {
      if (!mounted) return;
      
      final eventData = data['data'] as Map<String, dynamic>? ?? data;
      
      print('👤 [AuthWrapper] New participant: $eventData');
      
      final raffleId = eventData['raffleId'] as String?;
      final participantName = eventData['participantName'] as String?;
      final currentCount = eventData['currentParticipants'] as int?;
      final maxCount = eventData['maxParticipants'] as int?;
      
      context.read<RaffleProvider>().updateRaffleLocally(eventData);
      
      final auth = context.read<AuthProvider>();
      final myUserId = auth.currentUser?.id;
      final participantId = eventData['participantId'] as String?;
      
      if (participantId != null && participantId != myUserId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '👤 ${participantName ?? "Un participant"} a rejoint ($currentCount/$maxCount)'
            ),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    };

    sse.onRaffleStatusChange = (data) {
      if (!mounted) return;
      
      final eventData = data['data'] as Map<String, dynamic>? ?? data;
      
      print('📊 [AuthWrapper] Raffle status changed: $eventData');
      
      final raffleId = eventData['raffleId'] as String?;
      final raffleTitle = eventData['raffleTitle'] as String?;
      final newStatus = eventData['newStatus'] as String?;
      final oldStatus = eventData['oldStatus'] as String?;
      
      if (raffleId != null && newStatus != null) {
        context.read<RaffleProvider>().updateRaffleStatusLocally(raffleId, newStatus);
      }
      
      if (newStatus == 'full' && oldStatus != 'full') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${raffleTitle ?? "Une tombola"} est complète !'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };

    sse.onWinnerDrawn = (data) {
      if (!mounted) return;
      
      final eventData = data['data'] as Map<String, dynamic>? ?? data;
      
      print('🏆 [AuthWrapper] Winner drawn: $eventData');
      
      final raffleId = eventData['raffleId'] as String?;
      final winnerId = eventData['winnerId'] as String?;
      final winnerName = eventData['winnerName'] as String?;
      final raffleTitle = eventData['raffleTitle'] as String?;
      final productName = eventData['productName'] as String?;
      final auth = context.read<AuthProvider>();
      
      context.read<RaffleProvider>().fetchMine();
      context.read<RaffleProvider>().fetchWins();
      
      if (winnerId == auth.currentUser?.id) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: Column(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                const SizedBox(height: 16),
                const Text(
                  '🎉 FÉLICITATIONS ! 🎉',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Vous avez gagné :',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    productName ?? raffleTitle ?? 'Votre lot',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Rendez-vous dans "Mes Gains" pour réclamer votre prix !',
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
                  // TODO: Navigate to "Mes Gains"
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Voir mes gains'),
              ),
            ],
          ),
        );
      }
      else if (auth.currentUser?.isStoreOwner ?? false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Gagnant tiré : ${winnerName ?? "Participant"}'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🏆 ${winnerName ?? "Le gagnant"} a remporté : ${raffleTitle ?? "la tombola"}'),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };

    sse.onRaffleCancelled = (data) {
      if (!mounted) return;
      
      final eventData = data['data'] as Map<String, dynamic>? ?? data;
      
      print('❌ [AuthWrapper] Raffle cancelled: $eventData');
      
      final raffleId = eventData['raffleId'] as String?;
      final raffleTitle = eventData['raffleTitle'] as String?;
      final reason = eventData['reason'] as String?;
      
      if (raffleId != null) {
        context.read<RaffleProvider>().removeRaffleLocally(raffleId);
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cancel, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Tombola annulée'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                raffleTitle ?? 'Une tombola a été annulée',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (reason != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Raison : $reason',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Votre paiement sera remboursé automatiquement.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    };

    sse.onRaffleCompleted = (data) {
      if (!mounted) return;
      
      print('✅ [AuthWrapper] Raffle completed: $data');
      
      context.read<RaffleProvider>().fetchMine();
    };

    // ═══════════════════════════════════════════════════════════
    // NOTIFICATION CALLBACKS
    // ═══════════════════════════════════════════════════════════

    sse.onNewNotification = (data) {
      if (!mounted) return;
      
      final eventData = data['data'] as Map<String, dynamic>? ?? data;
      
      print('🔔 [AuthWrapper] New notification: $eventData');
      
      final title = eventData['title'] as String?;
      final message = eventData['message'] as String?;
      
      context.read<NotificationProvider>().fetchUnreadCount();
      
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
              // TODO: Navigate to notifications
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    };

    sse.onUnreadCountUpdate = (count) {
      if (!mounted) return;
      print('🔔 [AuthWrapper] Unread count: $count');
      
      context.read<NotificationProvider>().updateUnreadCountLocally(count);
    };

    // ═══════════════════════════════════════════════════════════
    // WALLET CALLBACKS
    // ═══════════════════════════════════════════════════════════

    sse.onWalletUpdate = (data) {
      if (!mounted) return;
      
      final eventData = data['data'] as Map<String, dynamic>? ?? data;
      
      print('💰 [AuthWrapper] Wallet updated: $eventData');
      
      final change = eventData['change'];
      final reason = eventData['reason'] as String?;
      final type = eventData['type'] as String?;
      
      context.read<AuthProvider>().refreshProfile();

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

    print('✅ [AuthWrapper] SSE callbacks registered');
  }
  
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
    WidgetsBinding.instance.removeObserver(this);
    print('🔴 AuthWrapper disposing, disconnecting SSE...');
    SSEService().disconnect();
    _sseInitialized = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        if (auth.isAuthenticated) {
          NotificationService.instance.registerToken();
          
          // Reconnect SSE if authenticated but not initialized
          /* if (!_sseInitialized) {
            Future.microtask(() => _checkAndInitializeSSE());
          } */
          if (!_sseInitialized && !_isInitializing) {
            _isInitializing = true;
            
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await _checkAndInitializeSSE();
              _isInitializing = false;
            });
          }
        } else {
          // Disconnect SSE if logged out
          if (_sseInitialized) {
            SSEService().disconnect();
            _sseInitialized = false;
            _isInitializing = false;
          }
          //return const LoginScreen();
        }

        // ✅ Afficher un loading pendant l'initialisation SSE
        if (auth.isAuthenticated && !_sseInitialized) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Etablissement de la connection...'),
                ],
              ),
            ),
          );
        }
        
        return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
      },
    );
  }
} */

import 'package:flutter/material.dart';
import 'package:lucky_day/data/repositories/notification_repository.dart';
import 'package:lucky_day/data/repositories/payment_repository.dart';
import 'package:lucky_day/providers/payment_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lucky_day/data/services/sse_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_constants.dart';

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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ✅ Flag global pour éviter les logouts multiples
bool _isLoggingOut = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 APP STARTING');

  final apiService = ApiService();
  print('✅ ApiService singleton initialized');

  ApiService.setOnTokenExpired(() {
    print('🔴 TOKEN EXPIRED CALLBACK TRIGGERED');

    // ✅ Éviter les logouts multiples
    if (_isLoggingOut) {
      print('⚠️ Logout already in progress, skipping...');
      return;
    }

    final context = navigatorKey.currentContext;

    if (context != null) {
      print('✅ Context available, showing snackbar');

      _isLoggingOut = true; // ✅ Marquer le logout en cours

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏱️ Votre session a expiré. Veuillez vous reconnecter.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );

      // ✅ NE PAS naviguer ! Juste déclencher un logout
      // AuthWrapper va automatiquement afficher LoginScreen
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.logout().then((_) {
        // ✅ Réinitialiser le flag après le logout
        _isLoggingOut = false;
        print('✅ Logout flag reset');
      });
    } else {
      print('⚠️ Context is null, cannot show UI');
    }
  });

  await Firebase.initializeApp();
  print('✅ Firebase initialized');

  await NotificationService.instance.initialize();
  print('✅ NotificationService initialized');

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
    final paymentRepo = PaymentRepository(api);

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
        ChangeNotifierProvider(create: (_) => PaymentProvider(paymentRepo)),
      ],
      child: MaterialApp(
        title: 'Lucky Day',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
        // ✅ SUPPRIMÉ : Ne plus utiliser de routes nommées
        // AuthWrapper gère tout automatiquement
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool _sseInitialized = false;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    
    // Monitor app lifecycle (background/foreground)
    WidgetsBinding.instance.addObserver(this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('🔔 Registering callbacks...');
      
      NotificationService.setOnNotificationTap((data) {
        print('🔔 Notification tapped with data: $data');
        _handleNotificationNavigation(data);
      });
      
      print('✅ Notification tap callback registered');
      
      // ✅ NOUVEAU : Vérifier si l'utilisateur est déjà authentifié au démarrage
      final auth = context.read<AuthProvider>();
      print('🔍 [AuthWrapper] initState: isAuthenticated = ${auth.isAuthenticated}');
      
      if (auth.isAuthenticated && !_sseInitialized && !_isInitializing) {
        print('🔄 [AuthWrapper] User already authenticated at startup, initializing SSE...');
        await _checkAndInitializeSSE();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    print('📱 App lifecycle state: $state');
    
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - reconnect SSE
      print('📱 App resumed, reconnecting SSE...');
      _reconnectSSE();
    } else if (state == AppLifecycleState.paused) {
      // App went to background - disconnect SSE
      print('📱 App paused, disconnecting SSE...');
      SSEService().disconnect();
      _sseInitialized = false;
    }
  }

  Future<void> _checkAndInitializeSSE() async {
    if (_isInitializing) {
      print('⚠️ [AuthWrapper] Already initializing SSE, skipping...');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    
    print('🔐 Token check: ${token != null ? "Present" : "Missing"}');
    
    if (token == null) {
      print('⚠️ No token found, skipping SSE initialization');
      return;
    }

    if (!mounted || _sseInitialized) {
      print('⚠️ Not mounted or already initialized');
      return;
    }

    _isInitializing = true;

    try {
      print('✅ Token found, initializing services');
      
      final auth = context.read<AuthProvider>();
      
      // ✅ IMPORTANT : Refresh profile UNIQUEMENT si token valide
      try {
        await auth.refreshProfile();
      } catch (e) {
        print('❌ Profile refresh failed (token may be expired): $e');
        _isInitializing = false;
        return;
      }
      
      if (!auth.isAuthenticated || !mounted) {
        print('⚠️ User not authenticated after refresh, aborting SSE init');
        _isInitializing = false;
        return;
      }

      // ✅ Initialiser SSE et ATTENDRE la connexion
      await _initializeSSE();
      
      _sseInitialized = true;
      
      print('✅ [AuthWrapper] SSE initialization complete');
      
      // Fetch created raffles if owner
      if (auth.currentUser?.isStoreOwner ?? false) {
        context.read<RaffleProvider>().fetchMyCreatedRaffles(auth.currentUser!.id);
      }
    } catch (e) {
      print('❌ Error during SSE initialization: $e');
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _reconnectSSE() async {
    if (_sseInitialized) {
      print('⚠️ SSE already initialized');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    
    if (token != null && mounted) {
      print('🔄 Reconnecting SSE...');
      await _checkAndInitializeSSE();
      
      // Resubscribe to raffles that are currently loaded
      if (_sseInitialized) {
        await _resubscribeToRaffles();
      }
    }
  }

  Future<void> _resubscribeToRaffles() async {
    print('🔄 Resubscribing to raffles...');
    
    final raffleProvider = context.read<RaffleProvider>();
    
    // Get all currently loaded raffles
    final allRaffleIds = raffleProvider.allRaffles.map((r) => r.id).toList();
    
    print('   Found ${allRaffleIds.length} raffles to subscribe to');
    
    if (allRaffleIds.isNotEmpty) {
      final sse = SSEService();
      
      // Wait a bit for SSE to be connected
      await Future.delayed(const Duration(seconds: 2));
      
      if (sse.isConnected) {
        await sse.subscribeToAll(
          raffleIds: allRaffleIds,
          notifications: true,
          wallet: true,
        );
        print('✅ Resubscribed to ${allRaffleIds.length} raffles');
      }
    }
  }

  Future<void> _initializeSSE() async {
    print('⚡ [AuthWrapper] Initializing SSE...');
    
    final sse = SSEService();
    
    // Register SSE callbacks FIRST
    _registerSSECallbacks();
    
    // ✅ Connect to SSE stream et ATTENDRE
    await sse.connect();
    
    print('✅ [AuthWrapper] SSE connection initiated');
    
    // ✅ Attendre que SSE soit connecté
    await _waitForSSEConnection();
    
    if (sse.isConnected) {
      print('✅ [AuthWrapper] SSE is connected, subscribing...');
      await _performSubscriptions();
    } else {
      print('⚠️ [AuthWrapper] SSE not connected yet, will retry...');
      
      // Retry after delay
      await Future.delayed(const Duration(seconds: 2));
      
      if (sse.isConnected) {
        await _performSubscriptions();
      } else {
        print('❌ [AuthWrapper] SSE connection failed');
      }
    }
  }

  /// ✅ NOUVELLE MÉTHODE : Attendre que SSE soit connecté
  Future<void> _waitForSSEConnection() async {
    final sse = SSEService();
    int attempts = 0;
    const maxAttempts = 10;
    
    while (!sse.isConnected && attempts < maxAttempts) {
      print('⏳ [AuthWrapper] Waiting for SSE connection... (${attempts + 1}/$maxAttempts)');
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
    
    if (sse.isConnected) {
      print('✅ [AuthWrapper] SSE is connected');
    } else {
      print('⚠️ [AuthWrapper] SSE connection timeout after ${attempts * 500}ms');
    }
  }

  Future<void> _performSubscriptions() async {
    print('📊 [AuthWrapper] Performing subscriptions...');
    
    // Subscribe to notifications and wallet (without raffles for now)
    final success = await SSEService().subscribeToAll(raffleIds: []);
    
    if (success) {
      print('✅ [AuthWrapper] Subscribed to notifications + wallet');
    } else {
      print('❌ [AuthWrapper] Failed to subscribe');
    }
  }

  void _registerSSECallbacks() {
    print('📡 [AuthWrapper] Registering SSE callbacks...');
    
    final sse = SSEService();

    // ═══════════════════════════════════════════════════════════
    // RAFFLE CALLBACKS
    // ═══════════════════════════════════════════════════════════

    sse.onRaffleUpdate = (data) {
      if (!mounted) return;
      
      final eventData = data['data'] as Map<String, dynamic>? ?? data;
      
      print('🎲 [AuthWrapper] Raffle updated: $eventData');
      
      final raffleId = eventData['raffleId'] as String?;
      final currentParticipants = eventData['currentParticipants'] as int?;
      final maxParticipants = eventData['maxParticipants'] as int?;
      
      print('   Raffle ID: $raffleId');
      print('   Participants: $currentParticipants/$maxParticipants');
      
      context.read<RaffleProvider>().updateRaffleLocally(eventData);
    };

    sse.onNewParticipant = (data) {
      if (!mounted) return;
      
      final eventData = data['data'] as Map<String, dynamic>? ?? data;
      
      print('👤 [AuthWrapper] New participant: $eventData');
      
      final raffleId = eventData['raffleId'] as String?;
      final participantName = eventData['participantName'] as String?;
      final currentCount = eventData['currentParticipants'] as int?;
      final maxCount = eventData['maxParticipants'] as int?;
      
      context.read<RaffleProvider>().updateRaffleLocally(eventData);
      
      final auth = context.read<AuthProvider>();
      final myUserId = auth.currentUser?.id;
      final participantId = eventData['participantId'] as String?;
      
      if (participantId != null && participantId != myUserId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '👤 ${participantName ?? "Un participant"} a rejoint ($currentCount/$maxCount)'
            ),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    };

    sse.onRaffleStatusChange = (data) {
      if (!mounted) return;
      
      final eventData = data['data'] as Map<String, dynamic>? ?? data;
      
      print('📊 [AuthWrapper] Raffle status changed: $eventData');
      
      final raffleId = eventData['raffleId'] as String?;
      final raffleTitle = eventData['raffleTitle'] as String?;
      final newStatus = eventData['newStatus'] as String?;
      final oldStatus = eventData['oldStatus'] as String?;
      
      if (raffleId != null && newStatus != null) {
        context.read<RaffleProvider>().updateRaffleStatusLocally(raffleId, newStatus);
      }
      
      if (newStatus == 'full' && oldStatus != 'full') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${raffleTitle ?? "Une tombola"} est complète !'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };

    sse.onWinnerDrawn = (data) {
      if (!mounted) return;
      
      final eventData = data['data'] as Map<String, dynamic>? ?? data;
      
      print('🏆 [AuthWrapper] Winner drawn: $eventData');
      
      final raffleId = eventData['raffleId'] as String?;
      final winnerId = eventData['winnerId'] as String?;
      final winnerName = eventData['winnerName'] as String?;
      final raffleTitle = eventData['raffleTitle'] as String?;
      final productName = eventData['productName'] as String?;
      final auth = context.read<AuthProvider>();
      
      context.read<RaffleProvider>().fetchMine();
      context.read<RaffleProvider>().fetchWins();
      
      if (winnerId == auth.currentUser?.id) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: Column(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                const SizedBox(height: 16),
                const Text(
                  '🎉 FÉLICITATIONS ! 🎉',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Vous avez gagné :',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    productName ?? raffleTitle ?? 'Votre lot',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Rendez-vous dans "Mes Gains" pour réclamer votre prix !',
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
                  // TODO: Navigate to "Mes Gains"
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Voir mes gains'),
              ),
            ],
          ),
        );
      }
      else if (auth.currentUser?.isStoreOwner ?? false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Gagnant tiré : ${winnerName ?? "Participant"}'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🏆 ${winnerName ?? "Le gagnant"} a remporté : ${raffleTitle ?? "la tombola"}'),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };

    sse.onRaffleCancelled = (data) {
      if (!mounted) return;
      
      final eventData = data['data'] as Map<String, dynamic>? ?? data;
      
      print('❌ [AuthWrapper] Raffle cancelled: $eventData');
      
      final raffleId = eventData['raffleId'] as String?;
      final raffleTitle = eventData['raffleTitle'] as String?;
      final reason = eventData['reason'] as String?;
      
      if (raffleId != null) {
        context.read<RaffleProvider>().removeRaffleLocally(raffleId);
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cancel, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Tombola annulée'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                raffleTitle ?? 'Une tombola a été annulée',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (reason != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Raison : $reason',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Votre paiement sera remboursé automatiquement.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    };

    sse.onRaffleCompleted = (data) {
      if (!mounted) return;
      
      print('✅ [AuthWrapper] Raffle completed: $data');
      
      context.read<RaffleProvider>().fetchMine();
    };

    // ═══════════════════════════════════════════════════════════
    // NOTIFICATION CALLBACKS
    // ═══════════════════════════════════════════════════════════

    sse.onNewNotification = (data) {
      if (!mounted) return;
      
      final eventData = data['data'] as Map<String, dynamic>? ?? data;
      
      print('🔔 [AuthWrapper] New notification: $eventData');
      
      final title = eventData['title'] as String?;
      final message = eventData['message'] as String?;
      
      context.read<NotificationProvider>().fetchUnreadCount();
      
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
              // TODO: Navigate to notifications
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    };

    sse.onUnreadCountUpdate = (count) {
      if (!mounted) return;
      print('🔔 [AuthWrapper] Unread count: $count');
      
      context.read<NotificationProvider>().updateUnreadCountLocally(count);
    };

    // ═══════════════════════════════════════════════════════════
    // WALLET CALLBACKS
    // ═══════════════════════════════════════════════════════════

    sse.onWalletUpdate = (data) {
      if (!mounted) return;
      
      final eventData = data['data'] as Map<String, dynamic>? ?? data;
      
      print('💰 [AuthWrapper] Wallet updated: $eventData');
      
      final change = eventData['change'];
      final reason = eventData['reason'] as String?;
      final type = eventData['type'] as String?;
      
      context.read<AuthProvider>().refreshProfile();

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

    print('✅ [AuthWrapper] SSE callbacks registered');
  }
  
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
    WidgetsBinding.instance.removeObserver(this);
    print('🔴 AuthWrapper disposing, disconnecting SSE...');
    SSEService().disconnect();
    _sseInitialized = false;
    _isInitializing = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, __) {
        final isAuth = auth.isAuthenticated;
        print('🔄 [AuthWrapper] Consumer builder called!');
        print('   isAuthenticated: $isAuth');
        print('   currentUser: ${auth.currentUser?.email ?? "null"}');
        print('   _sseInitialized: $_sseInitialized');
        print('   _isInitializing: $_isInitializing');
        
        // ✅ SI AUTHENTIFIÉ
        if (isAuth) {
          print('   → Rendering authenticated state');
          
          NotificationService.instance.registerToken();
          
          // ✅ Si SSE n'est pas initialisé, l'initialiser ET afficher un écran de chargement
          if (!_sseInitialized && !_isInitializing) {
            print('🔄 [AuthWrapper] User authenticated, initializing SSE...');
            
            // ✅ Lancer l'initialisation SSE
            // NOTE: _checkAndInitializeSSE() met _isInitializing = true lui-même
            _checkAndInitializeSSE().then((_) {
              if (mounted) {
                setState(() {
                  print('✅ [AuthWrapper] SSE initialized, triggering rebuild');
                });
              }
            });
            
            // ✅ AFFICHER UN ÉCRAN DE CHARGEMENT pendant l'initialisation
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Connexion en cours...',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // ✅ Si SSE est initialisé, afficher HomeScreen
          print('   → Returning HomeScreen');
          return const HomeScreen();
        } 
        // ✅ SI NON AUTHENTIFIÉ (logout ou session expirée)
        else {
          print('   → Rendering unauthenticated state');
          
          // ✅ IMPORTANT : Reset les flags SSE lors du logout
          if (_sseInitialized || _isInitializing) {
            print('🔴 [AuthWrapper] Disconnecting SSE and resetting flags...');
            SSEService().disconnect();
            
            // ✅ CRITIQUE : Utiliser setState pour forcer le rebuild avec les flags resetés
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _sseInitialized = false;
                  _isInitializing = false;
                  print('✅ [AuthWrapper] Flags reset: _sseInitialized=false, _isInitializing=false');
                });
              }
            });
          }
          
          print('   → Returning LoginScreen');
          return const LoginScreen();
        }
      },
    );
  }
}