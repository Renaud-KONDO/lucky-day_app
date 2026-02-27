import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  AuthProvider(this._api) {
    _loadUserFromStorage();
  }

  User?  get currentUser    => _user;
  bool   get isAuthenticated => _user != null;
  bool   get isLoading       => _loading;
  String? get errorMessage   => _error;

  Future<void> _loadUserFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.userKey);
    if (raw != null) {
      _user = User.fromJson(jsonDecode(raw));
      notifyListeners();
    }
  }

  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));

  }

  Future<bool> login(String email, String password) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final res = await _api.post(AppConstants.authLogin, data: {'email': email, 'password': password});
      final data = res.data['data'];
      //logger.i("here is the received data from backend : $data");
      await _api.setToken(data['accessToken'] ?? data['token']);
      //logger.i("\n setToken success !!! ");
      //logger.i("\n let's log the returned user. \n returned user : $data['user']");
      _user = User.fromJson(data['user']);
      //logger.i("user var set successfully");
      await _saveUser(_user!);
      //logger.i("user saved successfully");

      // ✅ Enregistrer le token FCM une seule fois après login
      await NotificationService.instance.registerToken();

      _loading = false; notifyListeners();
      return true;
    } catch (e) {
      //_error = 'Email ou mot de passe incorrect';
      //logger.e("error encoutered : $e")
      _loading = false; notifyListeners();

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

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? username,  // ← ajouter
  }) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final body = {
        'email': email,
        'password': password,
        'fullName': fullName,
      };
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;
      if (username != null && username.isNotEmpty) body['username'] = username;  // ← ajouter
      
      final res  = await _api.post(AppConstants.authRegister, data: body);
      final data = res.data['data'];
      await _api.setToken(data['accessToken'] ?? data['token']);
      _user = User.fromJson(data['user']);
      await _saveUser(_user!);
      // ✅ Enregistrer le token FCM une seule fois après login
      await NotificationService.instance.registerToken();

      _loading = false; notifyListeners(); 
      
      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Username already taken')) {
        _error = "Ce nom d'utilisateur est déjà pris";
      } else if (msg.contains('Username')) {
        _error = "Nom d'utilisateur invalide (3-30 caractères, minuscules, _ et chiffres)";
      } else {
        _error = "Erreur lors de l'inscription";
      }
      _loading = false; notifyListeners(); return false;
    }
  }

  // ← Ajouter ces méthodes
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

  Future<List<String>> getSuggestedUsernames(String fullName) async {
    try {
      final res = await _api.post(
        AppConstants.suggestUsernames,
        data: {'fullName': fullName},
      );
      final list = res.data['data']['suggestions'] as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
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
    await NotificationService.instance.unregisterToken();

    await _api.clearToken();
    _user = null;
    notifyListeners();
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
    }
  }

  void clearError() { _error = null; notifyListeners(); }
}
