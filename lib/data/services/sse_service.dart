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
  
  // Callbacks pour différents types d'événements
  Function(Map<String, dynamic>)? onRaffleUpdate;
  Function(Map<String, dynamic>)? onRaffleStatusChange;
  Function(Map<String, dynamic>)? onNewParticipant;
  Function(Map<String, dynamic>)? onWinnerDrawn;
  Function(Map<String, dynamic>)? onRaffleCancelled;
  Function(Map<String, dynamic>)? onNewNotification;
  Function(Map<String, dynamic>)? onBalanceUpdate;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;

  /// Initialiser la connexion SSE
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

      // ✅ Correct endpoint selon le guide
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

        // ✅ Écouter le stream
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

  String _currentEvent = '';
  String _currentData = '';
  String _currentId = '';

  /// Gérer chaque ligne du stream SSE
  void _handleLine(String line) {
    // Ligne vide = fin d'un événement
    if (line.isEmpty) {
      if (_currentEvent.isNotEmpty || _currentData.isNotEmpty) {
        _processEvent(_currentEvent, _currentData, _currentId);
        _currentEvent = '';
        _currentData = '';
        _currentId = '';
      }
      return;
    }

    // Parser les champs SSE
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
      // Commentaire (heartbeat), ignorer
      return;
    }
  }

  /// Traiter un événement SSE complet
  void _processEvent(String event, String data, String id) {
    print('⚡ SSE Event: $event');
    print('⚡ ID: $id');
    print('⚡ Data: $data');

    try {
      final parsedData = jsonDecode(data) as Map<String, dynamic>;

      switch (event) {
        case 'raffle:update':
          print('🎲 Raffle update event');
          onRaffleUpdate?.call(parsedData);
          break;

        case 'raffle:status_change':
          print('📊 Raffle status change event');
          onRaffleStatusChange?.call(parsedData);
          break;

        case 'raffle:new_participant':
          print('👤 New participant event');
          onNewParticipant?.call(parsedData);
          break;

        case 'raffle:winner_drawn':
          print('🏆 Winner drawn event');
          onWinnerDrawn?.call(parsedData);
          break;

        case 'raffle:cancelled':
          print('❌ Raffle cancelled event');
          onRaffleCancelled?.call(parsedData);
          break;

        case 'notification:new':
          print('🔔 New notification event');
          onNewNotification?.call(parsedData);
          break;

        case 'user:balance_update':
          print('💰 Balance update event');
          onBalanceUpdate?.call(parsedData);
          break;

        case 'heartbeat':
        case 'ping':
          print('💓 Heartbeat received');
          break;

        default:
          print('⚠️ Unknown event type: $event');
      }
    } catch (e) {
      print('❌ Error parsing SSE data: $e');
      print('Raw data: $data');
    }
  }

  /// Gérer les erreurs
  void _handleError(dynamic error) {
    print('❌ SSE error: $error');
    _isConnected = false;
    
    // Tentative de reconnexion avec backoff exponentiel
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

  /// Gérer la fermeture de la connexion
  void _handleDone() {
    print('⚡ SSE connection closed');
    _isConnected = false;
    
    // Tenter de se reconnecter
    _handleError('Connection closed');
  }

  /// Déconnecter SSE
  void disconnect() {
    print('⚡ Disconnecting SSE...');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    
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

  /// Nettoyer les callbacks
  void clearCallbacks() {
    onRaffleUpdate = null;
    onRaffleStatusChange = null;
    onNewParticipant = null;
    onWinnerDrawn = null;
    onRaffleCancelled = null;
    onNewNotification = null;
    onBalanceUpdate = null;
  }
}