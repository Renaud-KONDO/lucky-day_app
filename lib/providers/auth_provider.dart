/* 
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:lucky_day/providers/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/user.dart';
import '../data/services/api_service.dart';
import '../core/constants/app_constants.dart';
import 'package:logger/logger.dart';
import '../data/services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _api;
  User? _user;
  bool _loading = false;
  String? _error;
  var logger = Logger();
  Timer? _notificationTimer;
  
  // ✅ NOUVEAU : Flag explicite pour forcer le rebuild
  bool _isAuthenticatedFlag = false;

  AuthProvider(this._api) {
    _loadUserFromStorage();
  }

  User?  get currentUser    => _user;
  
  // ✅ MODIFIÉ : Utiliser le flag explicite
  bool get isAuthenticated {
    final result = _user != null;
    print('🔍 [AuthProvider] isAuthenticated getter called: $result (flag: $_isAuthenticatedFlag)');
    return result;
  }
  
  bool   get isLoading       => _loading;
  String? get errorMessage   => _error;

  Future<void> _loadUserFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.userKey);
    if (raw != null) {
      _user = User.fromJson(jsonDecode(raw));
      _isAuthenticatedFlag = true;
      notifyListeners();
    }
  }

  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
  }

  Future<bool> login(String email, String password) async {
    _loading = true; 
    _error = null; 
    notifyListeners();
    
    try {
      final res = await _api.post(AppConstants.authLogin, data: {'email': email, 'password': password});
      final data = res.data['data'];
      
      await _api.setToken(data['accessToken'] ?? data['token']);
      
      _user = User.fromJson(data['user']);
      await _saveUser(_user!);

      // ✅ Enregistrer le token FCM
      await NotificationService.instance.registerToken();

      _startNotificationPolling();

      _loading = false;
      _isAuthenticatedFlag = true; // ✅ NOUVEAU
      
      print('✅ [AuthProvider] Login successful, user set: ${_user?.email}');
      print('✅ [AuthProvider] isAuthenticated: ${_user != null}');
      print('✅ [AuthProvider] Calling notifyListeners()...');
      
      notifyListeners();
      
      print('✅ [AuthProvider] notifyListeners() called');
      
      // ✅ Attendre que les listeners se rebuild
      await Future.delayed(const Duration(milliseconds: 150));
      
      print('✅ [AuthProvider] Login complete');
      
      return true;
    } catch (e) {
      _loading = false; 
      notifyListeners();

      if (e is DioException) {
        final responseData = e.response?.data;
        if (responseData is Map<String, dynamic>) {
          if(responseData['message'] == "Invalid email or password"){
            _error = "Nom d'utilisateur et/ou mot de passe invalide(s).";
          }else if(responseData['message'] == "Your IP has been temporarily blocked due to suspicious activity. Please try again later or contact support."){
             _error = "Votre adresse IP a été temporairement bloquée en raison d'une activité suspecte. Veuillez réessayer plus tard ou contactez le support.";
          }else{
            _error = "Une erreur est survenue. veillez réessayer plus tard.";
          }
        } else {
          _error = "Une erreur est survenue. veillez réessayer plus tard.";
        }
      } else {
        _error = "Une erreur est survenue. veillez réessayer plus tard.";
      }
      return false;
    }
  }

   void _startNotificationPolling() {
    _notificationTimer?.cancel();
    
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        try {
          // Polling logic
        } catch (e) {
          print('Error polling notifications: $e');
        }
      },
    );
  }
  
  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? username, 
  }) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final body = {
        'email': email,
        'password': password,
        'fullName': fullName,
      };
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;
      if (username != null && username.isNotEmpty) body['username'] = username;
      
      final res  = await _api.post(AppConstants.authRegister, data: body);
      final data = res.data['data'];
      await _api.setToken(data['accessToken'] ?? data['token']);
      _user = User.fromJson(data['user']);
      await _saveUser(_user!);
      
      await NotificationService.instance.registerToken();

      _loading = false;
      _isAuthenticatedFlag = true;
      notifyListeners(); 
      
      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Username is already taken')) {
        _error = "Ce nom d'utilisateur est déjà pris";
      } else if (msg.contains('Username')) {
        _error = "Nom d'utilisateur invalide (3-30 caractères, minuscules, _ et chiffres)";
      } else {
        _error = "Erreur lors de l'inscription";
      }
      _loading = false; notifyListeners(); return false;
    }
  }

  
  Future<bool> checkUsername(String username) async {
    try {
      final res = await _api.get(
        '${AppConstants.checkUsername}/$username',
      );
      return res.data['data']['available'] == true;
    } catch (_) {
      return false;
    }
  }

  List<String>? usernameSuggestions; 

  Future<bool> changeUsername(String newUsername) async {
    _error = null;
    usernameSuggestions = null;
    notifyListeners();

    try {
      final res = await _api.post('${AppConstants.changeUsername}/$newUsername');
      
      await refreshProfile();
      
      _error = null;
      usernameSuggestions = null;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Change username error: $e');
      
      if (e is DioException) {
        print('Error changing Username ${e.response?.data}');
        final data = e.response?.data;
        final messageObj = data?['message'];

        if (messageObj is Map) {
        final errorText = messageObj['message']?.toString() ?? 'Nom d\'utilisateur non disponible';
        
        _error = errorText;
        if (errorText.contains('already taken')) {
          _error = "Ce nom d'utilisateur est déjà pris";
        } else if (errorText.contains('invalid')) {
          _error = "Nom d'utilisateur invalide (3-30 caractères, minuscules, _ et chiffres)";
        }else{
          _error = "Nom d'utilisateur non disponible";
        }

        if (messageObj['suggestions'] != null && messageObj['suggestions'] is List) {
            usernameSuggestions = (messageObj['suggestions'] as List)
                .map((s) => s.toString())
                .toList();
            
            print("✅ Username Suggestions parsed: $usernameSuggestions");
          }
        } else {
          _error = messageObj?.toString() ?? 'Nom d\'utilisateur non disponible';
        }
      } else {
        _error = 'Erreur de connexion';
      }
      
      notifyListeners();
      return false;
    }
  }

  void clearUsernameError() {
    _error = null;
    usernameSuggestions = null;
    notifyListeners();
  }

  void setUsernameError(String error) {
    _error = error;
    usernameSuggestions = null;
    notifyListeners();
  }

  Future<List<String>> getSuggestedUsernames(String fullName) async {
    try {
      final res = await _api.post(
        AppConstants.suggestUsernames,
        data: {'fullName': fullName},
      );
      
      if (res.data['data']['suggestions'] != null) {
        final list = res.data['data']['suggestions'] as List;
        return list.map((e) => e.toString()).toList();
      } else if (res.data['data']['username'] != null) {
        final username = res.data['data']['username'].toString();
        return [username];
      }
      return [];
    } catch (e) {
      debugPrint('Error getting username suggestions: $e');
      return [];
    }
  }

  Future<bool> updateProfile({required String fullName, String? phone}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final body = <String, dynamic>{'fullName': fullName};
      if (phone != null) body['phone'] = phone;
      final res = await _api.put(AppConstants.authProfile, data: body);
      _user = User.fromJson(res.data['data']);
      await _saveUser(_user!);
      _loading = false; notifyListeners(); return true;
    } catch (e) {
      _error = 'Erreur de mise à jour';
      _loading = false; notifyListeners(); return false;
    }
  }

  Future<bool> changePassword({required String current, required String newPass}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      await _api.post(AppConstants.authChangePassword,
        data: {'currentPassword': current, 'newPassword': newPass});
      _loading = false; notifyListeners(); return true;
    } catch (e) {
      _error = 'Mot de passe actuel incorrect';
      _loading = false; notifyListeners(); return false;
    }
  }  

  Future<void> logout() async {
    print('🔴 [AuthProvider] Starting logout...');
    
    await NotificationService.instance.unregisterToken();
    await _api.clearToken();
    
    _user = null;
    _isAuthenticatedFlag = false; // ✅ NOUVEAU
    
    print('✅ [AuthProvider] User cleared, calling notifyListeners()...');
    notifyListeners();
    
    print('✅ [AuthProvider] Logout complete');
  }

  Future<void> refreshProfile() async {
    try {
      final res = await _api.get(AppConstants.authProfile);
      final userData = res.data['data'];
      _user = User.fromJson(userData);
      await _saveUser(_user!);
      notifyListeners();
      
      print('✅ Profile refreshed successfully');
      print('👤 New user data: ${_user?.toJson()}');
    } catch (e) {
      print('❌ Error refreshing profile: $e');
      rethrow;
    }
  }

  void clearError() { _error = null; notifyListeners(); }
} */


import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:lucky_day/providers/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/user.dart';
import '../data/services/api_service.dart';
import '../core/constants/app_constants.dart';
import 'package:logger/logger.dart';
import '../data/services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _api;
  User? _user;
  bool _loading = false;
  String? _error;
  var logger = Logger();
  Timer? _notificationTimer;
  
  // ✅ NOUVEAU : Flag explicite pour forcer le rebuild
  bool _isAuthenticatedFlag = false;

  AuthProvider(this._api) {
    _loadUserFromStorage();
  }

  User?  get currentUser    => _user;
  
  // ✅ MODIFIÉ : Utiliser le flag explicite
  bool get isAuthenticated {
    final result = _user != null;
    print('🔍 [AuthProvider] isAuthenticated getter called: $result (flag: $_isAuthenticatedFlag)');
    return result;
  }
  
  bool   get isLoading       => _loading;
  String? get errorMessage   => _error;

  Future<void> _loadUserFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.userKey);
    if (raw != null) {
      _user = User.fromJson(jsonDecode(raw));
      _isAuthenticatedFlag = true;
      notifyListeners();
    }
  }

  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
  }

  Future<bool> login(String email, String password) async {
    _loading = true; 
    _error = null; 
    notifyListeners();
    
    try {
      final res = await _api.post(AppConstants.authLogin, data: {'email': email, 'password': password});
      final data = res.data['data'];
      
      await _api.setToken(data['accessToken'] ?? data['token']);
      
      _user = User.fromJson(data['user']);
      await _saveUser(_user!);

      // ✅ Enregistrer le token FCM
      await NotificationService.instance.registerToken();

      _startNotificationPolling();

      _loading = false;
      _isAuthenticatedFlag = true; // ✅ NOUVEAU
      
      print('✅ [AuthProvider] Login successful, user set: ${_user?.email}');
      print('✅ [AuthProvider] isAuthenticated: ${_user != null}');
      print('✅ [AuthProvider] Calling notifyListeners()...');
      
      notifyListeners();
      
      print('✅ [AuthProvider] notifyListeners() called');
      
      // ✅ Attendre que les listeners se rebuild
      await Future.delayed(const Duration(milliseconds: 150));
      
      print('✅ [AuthProvider] Login complete');
      
      return true;
    } catch (e) {
      _loading = false; 
      notifyListeners();

      if (e is DioException) {
        final responseData = e.response?.data;
        if (responseData is Map<String, dynamic>) {
          if(responseData['message'] == "Invalid email or password"){
            _error = "Nom d'utilisateur et/ou mot de passe invalide(s).";
          }else if(responseData['message'] == "Your IP has been temporarily blocked due to suspicious activity. Please try again later or contact support."){
             _error = "Votre adresse IP a été temporairement bloquée en raison d'une activité suspecte. Veuillez réessayer plus tard ou contactez le support.";
          }else{
            _error = "Une erreur est survenue. veillez réessayer plus tard.";
          }
        } else {
          _error = "Une erreur est survenue. veillez réessayer plus tard.";
        }
      } else {
        _error = "Une erreur est survenue. veillez réessayer plus tard.";
      }
      return false;
    }
  }

   void _startNotificationPolling() {
    _notificationTimer?.cancel();
    
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        try {
          // Polling logic
        } catch (e) {
          print('Error polling notifications: $e');
        }
      },
    );
  }
  
  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String country,
    String? username, 
  }) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final body = {
        'email': email,
        'password': password,
        'fullName': fullName,
        'phone': phone,
        'country': country,
      };
      if (username != null && username.isNotEmpty) body['username'] = username;
      
      final res  = await _api.post(AppConstants.authRegister, data: body);
      final data = res.data['data'];
      await _api.setToken(data['accessToken'] ?? data['token']);
      _user = User.fromJson(data['user']);
      await _saveUser(_user!);
      
      await NotificationService.instance.registerToken();

      _startNotificationPolling();

      _loading = false;
      _isAuthenticatedFlag = true;
      notifyListeners(); 
      
      await Future.delayed(const Duration(milliseconds: 150));

      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Username is already taken')) {
        _error = "Ce nom d'utilisateur est déjà pris";
      } else if (msg.contains('Username')) {
        _error = "Nom d'utilisateur invalide (3-30 caractères, minuscules, _ et chiffres)";
      } else {
        _error = "Erreur lors de l'inscription";
      }
      _loading = false; notifyListeners(); return false;
    }
  }

  
  Future<bool> checkUsername(String username) async {
    try {
      final res = await _api.get(
        '${AppConstants.checkUsername}/$username',
      );
      return res.data['data']['available'] == true;
    } catch (_) {
      return false;
    }
  }

  List<String>? usernameSuggestions; 

  Future<bool> changeUsername(String newUsername) async {
    _error = null;
    usernameSuggestions = null;
    notifyListeners();

    try {
      final res = await _api.post('${AppConstants.changeUsername}/$newUsername');
      
      await refreshProfile();
      
      _error = null;
      usernameSuggestions = null;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Change username error: $e');
      
      if (e is DioException) {
        print('Error changing Username ${e.response?.data}');
        final data = e.response?.data;
        final messageObj = data?['message'];

        if (messageObj is Map) {
        final errorText = messageObj['message']?.toString() ?? 'Nom d\'utilisateur non disponible';
        
        _error = errorText;
        if (errorText.contains('already taken')) {
          _error = "Ce nom d'utilisateur est déjà pris";
        } else if (errorText.contains('invalid')) {
          _error = "Nom d'utilisateur invalide (3-30 caractères, minuscules, _ et chiffres)";
        }else{
          _error = "Nom d'utilisateur non disponible";
        }

        if (messageObj['suggestions'] != null && messageObj['suggestions'] is List) {
            usernameSuggestions = (messageObj['suggestions'] as List)
                .map((s) => s.toString())
                .toList();
            
            print("✅ Username Suggestions parsed: $usernameSuggestions");
          }
        } else {
          _error = messageObj?.toString() ?? 'Nom d\'utilisateur non disponible';
        }
      } else {
        _error = 'Erreur de connexion';
      }
      
      notifyListeners();
      return false;
    }
  }

  void clearUsernameError() {
    _error = null;
    usernameSuggestions = null;
    notifyListeners();
  }

  void setUsernameError(String error) {
    _error = error;
    usernameSuggestions = null;
    notifyListeners();
  }

  Future<List<String>> getSuggestedUsernames(String fullName) async {
    try {
      final res = await _api.post(
        AppConstants.suggestUsernames,
        data: {'fullName': fullName},
      );
      
      if (res.data['data']['suggestions'] != null) {
        final list = res.data['data']['suggestions'] as List;
        return list.map((e) => e.toString()).toList();
      } else if (res.data['data']['username'] != null) {
        final username = res.data['data']['username'].toString();
        return [username];
      }
      return [];
    } catch (e) {
      debugPrint('Error getting username suggestions: $e');
      return [];
    }
  }

  Future<bool> updateProfile({required String fullName, String? phone}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final body = <String, dynamic>{'fullName': fullName};
      if (phone != null) body['phone'] = phone;
      final res = await _api.put(AppConstants.authProfile, data: body);
      _user = User.fromJson(res.data['data']);
      await _saveUser(_user!);
      _loading = false; notifyListeners(); return true;
    } catch (e) {
      _error = 'Erreur de mise à jour';
      _loading = false; notifyListeners(); return false;
    }
  }

  Future<bool> changePassword({required String current, required String newPass}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      await _api.post(AppConstants.authChangePassword,
        data: {'currentPassword': current, 'newPassword': newPass});
      _loading = false; notifyListeners(); return true;
    } catch (e) {
      _error = 'Mot de passe actuel incorrect';
      _loading = false; notifyListeners(); return false;
    }
  }  

  Future<void> logout() async {
    print('🔴 [AuthProvider] Starting logout...');
    
    // ✅ Try-catch pour éviter que unregisterToken déclenche un autre logout
    try {
      await NotificationService.instance.unregisterToken();
    } catch (e) {
      print('⚠️ [AuthProvider] Failed to unregister token (expected if token expired): $e');
      // Ignorer l'erreur - le token est déjà invalide de toute façon
    }
    
    await _api.clearToken();
    
    _user = null;
    _isAuthenticatedFlag = false; // ✅ NOUVEAU
    
    print('✅ [AuthProvider] User cleared, calling notifyListeners()...');
    notifyListeners();
    
    print('✅ [AuthProvider] Logout complete');
  }

  Future<void> refreshProfile() async {
    try {
      final res = await _api.get(AppConstants.authProfile);
      final userData = res.data['data'];
      _user = User.fromJson(userData);
      await _saveUser(_user!);
      notifyListeners();
      
      print('✅ Profile refreshed successfully');
      print('👤 New user data: ${_user?.toJson()}');
    } catch (e) {
      print('❌ Error refreshing profile: $e');
      rethrow;
    }
  }

  void clearError() { _error = null; notifyListeners(); }
}