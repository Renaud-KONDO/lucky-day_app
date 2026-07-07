import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class SSEService {
  static final SSEService _instance = SSEService._internal();
  factory SSEService() => _instance;
  SSEService._internal();

  http.Client? _client;
  StreamSubscription? _subscription;
  
  // ═══════════════════════════════════════════════════════════
  // CALLBACKS
  // ═══════════════════════════════════════════════════════════
  
  // Raffles
  Function(Map<String, dynamic>)? onRaffleUpdate;
  Function(Map<String, dynamic>)? onRaffleStatusChange;
  Function(Map<String, dynamic>)? onNewParticipant;
  Function(Map<String, dynamic>)? onWinnerDrawn;
  Function(Map<String, dynamic>)? onRaffleCancelled;
  Function(Map<String, dynamic>)? onRaffleCompleted;
  
  // Notifications
  Function(Map<String, dynamic>)? onNewNotification;
  Function(int count)? onUnreadCountUpdate;
  
  // Wallet
  Function(Map<String, dynamic>)? onWalletUpdate;

  // ═══════════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════════
  
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;

  final Set<String> _subscribedRaffles = {};
  bool _subscribedToNotifications = false;
  bool _subscribedToWallet = false;

  Set<String> get subscribedRaffles => Set.unmodifiable(_subscribedRaffles);
  bool get subscribedToNotifications => _subscribedToNotifications;
  bool get subscribedToWallet => _subscribedToWallet;

  

  // ═══════════════════════════════════════════════════════════
  // CONNEXION SSE
  // ═══════════════════════════════════════════════════════════

  Future<void> connect() async {
    if (_isConnected) {
      print('⚡ SSE already connected');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);

      if (token == null) {
        print('⚠️ No token available for SSE connection');
        return;
      }

      final url = Uri.parse('${AppConstants.baseUrl}/events/stream');
      
      print('⚡ Connecting to SSE: $url');

      _client = http.Client();
      
      final request = http.Request('GET', url);
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      });

      final response = await _client!.send(request);
      if (response.statusCode == 200) {
        _isConnected = true;
        _reconnectAttempts = 0;
        print('✅ SSE connected (${response.statusCode})');

        _subscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              _handleLine,
              onError: _handleError,
              onDone: _handleDone,
              cancelOnError: false,
            );
      } else {
        print('❌ SSE connection failed: ${response.statusCode}');
        _isConnected = false;
        _handleError('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ SSE connection error: $e');
      _isConnected = false;
      _handleError(e);
    }
  }

  Future<void> _reconnect() async {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      print('❌ Max reconnection attempts reached');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: 2 * _reconnectAttempts);
    
    print('🔄 Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$maxReconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      await connect();
    });
  }

  String _currentEvent = '';
  String _currentData = '';
  String _currentId = '';

  void _handleLine(String line) {
    if (line.isEmpty) {
      if (_currentEvent.isNotEmpty || _currentData.isNotEmpty) {
        _processEvent(_currentEvent, _currentData, _currentId);
        _currentEvent = '';
        _currentData = '';
        _currentId = '';
      }
      return;
    }

    if (line.startsWith('event:')) {
      _currentEvent = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      if (_currentData.isNotEmpty) {
        _currentData += '\n';
      }
      _currentData += line.substring(5).trim();
    } else if (line.startsWith('id:')) {
      _currentId = line.substring(3).trim();
    } else if (line.startsWith(':')) {
      // Commentaire (heartbeat)
      return;
    }
  }

  void _processEvent(String event, String data, String id) {
    print('⚡ SSE Event: $event');
    if (id.isNotEmpty) print('⚡ ID: $id');
    print('⚡ Data: $data');

    try {
      final parsedData = jsonDecode(data) as Map<String, dynamic>;

      switch (event) {
        // ═══════════════════════════════════════════════════════════
        // RAFFLE EVENTS
        // ═══════════════════════════════════════════════════════════
        case 'connected':
          print('✅ SSE connected event received');
          break;

        case 'raffle_updated':
          print('🎲 Raffle updated');
          onRaffleUpdate?.call(parsedData);
          break;

        case 'raffle_status_changed':
          print('📊 Raffle status changed');
          onRaffleStatusChange?.call(parsedData);
          break;

        case 'raffle_participant_added':
          print('👤 New participant added');
          onNewParticipant?.call(parsedData);
          break;

        case 'raffle_winner_drawn':
          print('🏆 Winner drawn');
          onWinnerDrawn?.call(parsedData);
          break;

        case 'raffle_cancelled':
          print('❌ Raffle cancelled');
          onRaffleCancelled?.call(parsedData);
          break;

        case 'raffle:completed':
        case 'raffle_completed':
          print('✅ Raffle completed');
          onRaffleCompleted?.call(parsedData);
          break;

        // ═══════════════════════════════════════════════════════════
        // NOTIFICATION EVENTS
        // ═══════════════════════════════════════════════════════════
        
        case 'notification_received':
          print('🔔 Notification received');
          onNewNotification?.call(parsedData);
          break;

        case 'unread_count_updated':
          print('🔔 Unread count updated');
          final count = parsedData['count'] as int? ?? 0;
          onUnreadCountUpdate?.call(count);
          break;

        // ═══════════════════════════════════════════════════════════
        // WALLET EVENTS unread_count_updated
        // ═══════════════════════════════════════════════════════════
        
        case 'wallet_updated':
        case 'wallet_update':
          print('💰 Wallet updated');
          onWalletUpdate?.call(parsedData);
          break;

        // ═══════════════════════════════════════════════════════════
        // HEARTBEAT
        // ═══════════════════════════════════════════════════════════
        
        case 'heartbeat':
          print('💓 Heartbeat received');
          break;

        // ═══════════════════════════════════════════════════════════
        // UNKNOWN
        // ═══════════════════════════════════════════════════════════
        
        default:
          print('⚠️ Unknown event type: $event');
          print('⚠️ Data: ${jsonEncode(parsedData)}');
      }
    } catch (e) {
      print('❌ Error parsing SSE data: $e');
      print('Raw data: $data');
    }
  }

  void _handleError(dynamic error) {
    print('❌ SSE error: $error');
    _isConnected = false;
    
    if (_reconnectAttempts < maxReconnectAttempts) {
      _reconnectAttempts++;
      final delay = Duration(seconds: 2 * _reconnectAttempts);
      
      print('🔄 Reconnect attempt $_reconnectAttempts/$maxReconnectAttempts in ${delay.inSeconds}s');
      
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () {
        if (!_isConnected) {
          connect();
        }
      });
    } else {
      print('❌ Max reconnect attempts reached');
    }
  }

  void _handleDone() {
    print('⚡ SSE connection closed');
    _isConnected = false;
    _handleError('Connection closed');
  }

  // ═══════════════════════════════════════════════════════════
  // SUBSCRIPTION API
  // ═══════════════════════════════════════════════════════════

  /// ✅ S'abonner à tout (raffles + notifications + wallet)
  Future<bool> subscribeToAll({List<String>? raffleIds= const [],
    bool notifications = true,
    bool wallet = true,}) async {
      if (!_isConnected) {
        print('⚠️ Cannot subscribe: SSE not connected');
        return false;
      }


    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);

      if (token == null) {
        print('⚠️ No token for subscription');
        return false;
      }

      final url = '${AppConstants.baseUrl}/events/subscribe-all';
      
      print('⚡ Subscribing to all updates...');
      if (raffleIds != null && raffleIds.isNotEmpty) {
        print('   - Raffles: ${raffleIds.length}');
      }
      print('   - Notifications: YES');
      print('   - Wallet: YES');

      final body = <String, dynamic>{
        'includeNotifications': notifications,
        'includeWallet': wallet,
      };
      
      if (raffleIds != null && raffleIds.isNotEmpty) {
        body['raffleIds'] = raffleIds;
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final subscriptions = data['data']['subscriptions'] as Map<String, dynamic>?;
        
        if (raffleIds != null && raffleIds.isNotEmpty) {
          _subscribedRaffles.addAll(raffleIds);
        }
        _subscribedToNotifications = subscriptions?['notifications'] as bool? ?? true;
        _subscribedToWallet = subscriptions?['wallet'] as bool? ?? true;
        
        print('✅ Successfully subscribed to all updates');
        print('   - Raffles: ${subscriptions?['raffles']?['count'] ?? 0}');
        print('   - Notifications: $_subscribedToNotifications');
        print('   - Wallet: $_subscribedToWallet');
        
        return true;
      } else {
        print('❌ Failed to subscribe: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error subscribing to all: $e');
      return false;
    }
  }

  /// ✅ Mettre à jour les abonnements (ajouter de nouvelles raffles)
  Future<bool> updateSubscriptions({
    List<String>? addRaffleIds,
    List<String>? removeRaffleIds,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);

      if (token == null) return false;

      final url = '${AppConstants.baseUrl}/events/raffles/update-subscriptions';
      
      print('⚡ Updating subscriptions...');
      if (addRaffleIds != null && addRaffleIds.isNotEmpty) {
        print('   - Adding raffles: ${addRaffleIds.length}');
      }
      if (removeRaffleIds != null && removeRaffleIds.isNotEmpty) {
        print('   - Removing raffles: ${removeRaffleIds.length}');
      }

      final body = <String, dynamic>{};
      if (addRaffleIds != null && addRaffleIds.isNotEmpty) {
        body['addRaffleIds'] = addRaffleIds;
      }
      if (removeRaffleIds != null && removeRaffleIds.isNotEmpty) {
        body['removeRaffleIds'] = removeRaffleIds;
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (addRaffleIds != null) {
          _subscribedRaffles.addAll(addRaffleIds);
        }
        if (removeRaffleIds != null) {
          _subscribedRaffles.removeAll(removeRaffleIds);
        }
        
        print('✅ Subscriptions updated');
        print('   Total raffles: ${_subscribedRaffles.length}');
        return true;
      } else {
        print('❌ Failed to update subscriptions: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error updating subscriptions: $e');
      return false;
    }
  }

  /// ✅ Se désabonner de tout
  Future<bool> unsubscribeFromAll() async {
    if (_subscribedRaffles.isEmpty && 
        !_subscribedToNotifications && 
        !_subscribedToWallet) {
      print('⚡ No active subscriptions');
      return true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);

      if (token == null) return false;

      final url = '${AppConstants.baseUrl}/events/unsubscribe-all';

      print('⚡ Unsubscribing from all...');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final count = _subscribedRaffles.length;
        _subscribedRaffles.clear();
        _subscribedToNotifications = false;
        _subscribedToWallet = false;
        
        print('✅ Unsubscribed from all ($count raffles)');
        return true;
      } else {
        print('❌ Failed to unsubscribe: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error unsubscribing: $e');
      return false;
    }
  }

  /// ✅ Récupérer les abonnements actifs
  Future<Map<String, dynamic>> getMySubscriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);

      if (token == null) return {};

      final url = '${AppConstants.baseUrl}/events/my-subscriptions';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final subscriptions = data['data'] as Map<String, dynamic>;
        
        final raffles = subscriptions['raffles'] as Map<String, dynamic>;
        final raffleIds = List<String>.from(raffles['ids'] ?? []);
        
        _subscribedRaffles.clear();
        _subscribedRaffles.addAll(raffleIds);
        _subscribedToNotifications = subscriptions['notifications'] as bool? ?? false;
        _subscribedToWallet = subscriptions['wallet'] as bool? ?? false;
        
        print('✅ Fetched active subscriptions:');
        print('   - Raffles: ${raffleIds.length}');
        print('   - Notifications: $_subscribedToNotifications');
        print('   - Wallet: $_subscribedToWallet');
        
        return subscriptions;
      }
    } catch (e) {
      print('❌ Error fetching subscriptions: $e');
    }

    return {};
  }

  // ═══════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════

  void disconnect({bool unsubscribe = true}) async {
    print('⚡ Disconnecting SSE...');
    
    //unsubscribeFromAll();
    
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;

    // Unsubscribe from all events before disconnecting
    if (unsubscribe && _isConnected) {
      await unsubscribeFromAll();
    }
    
    _subscription?.cancel();
    _subscription = null;
    
    _client?.close();
    _client = null;
    
    _currentEvent = '';
    _currentData = '';
    _currentId = '';
    
    _isConnected = false;
    print('✅ SSE disconnected');
  }

  void clearCallbacks() {
    onRaffleUpdate = null;
    onRaffleStatusChange = null;
    onNewParticipant = null;
    onWinnerDrawn = null;
    onRaffleCancelled = null;
    onRaffleCompleted = null;
    onNewNotification = null;
    onUnreadCountUpdate = null;
    onWalletUpdate = null;
  }
}