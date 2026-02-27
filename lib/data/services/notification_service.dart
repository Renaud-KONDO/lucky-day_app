import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';
import '../../core/constants/app_constants.dart';


// Handler pour les messages en background (doit être top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📬 Background message: ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  bool _isRegistered = false;

  Future<void> initialize() async {
    _fcm.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _isRegistered = false;  
      registerToken();
    });
    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('❌ Notification permission denied');
      return;
    }

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    await _localNotif.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const channel = AndroidNotificationChannel(
      'lucky_day_channel',
      'Lucky Day Notifications',
      description: 'Notifications pour Lucky Day',
      importance: Importance.high,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Get FCM token
    _fcmToken = await _fcm.getToken();
    print('📱 FCM Token: $_fcmToken');

    // Listen to token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      registerToken();
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);
    
    // Check if app was opened from a notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessageTap(initialMessage);
    }
  }

  Future<void> registerToken() async {
    // ✅ Ne rien faire si déjà enregistré
    if (_isRegistered) {
      print('⏭️  Token already registered, skipping');
      return;
    }
    
    if (_fcmToken == null) {
      print('⚠️  No FCM token available');
      return;
    }

    try {
      final api = ApiService();
      await api.post(
        '/notifications/register',
        data: {
          'token': _fcmToken,
          'deviceType': 'android',
          'deviceName': 'Flutter App',
        },
      );
      print('✅ Yay ! FCM token registered');
      _isRegistered = true;  
      print('✅ FCM token registered');
    } catch (e) {
      print('❌ Failed to register FCM token: $e');
    }
  }

  Future<void> unregisterToken() async {
    if (_fcmToken == null) return;
    try {
      final api = ApiService();
      await api.post(
        '/notifications/unregister',
        data: {'token': _fcmToken},
      );

      _isRegistered = false;
      print('✅ FCM token unregistered');
    } catch (e) {
      print('❌ Failed to unregister FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📬 Foreground notification: ${message.notification?.title}');
    
    // Show local notification
    _localNotif.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'lucky_day_channel',
          'Lucky Day Notifications',
          channelDescription: 'Notifications pour Lucky Day',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['screen'],
    );
  }

  void _handleBackgroundMessageTap(RemoteMessage message) {
    print('👆 Tapped background notification: ${message.data}');
    _navigateToScreen(message.data['screen']);
  }

  void _onNotificationTapped(NotificationResponse details) {
    print('👆 Tapped local notification: ${details.payload}');
    _navigateToScreen(details.payload);
  }

  void _navigateToScreen(String? screen) {
    if (screen == null) return;
    // TODO: Implement navigation logic
    // NavigatorKey.currentState?.pushNamed(screen);
  }
}