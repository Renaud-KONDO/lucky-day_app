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

      // Après login, lance un polling toutes les 30 secondes
      /* Timer.periodic(const Duration(seconds: 30), (_) {
        NotificationProvider.fetchUnreadCount();
      }); */
      _startNotificationPolling();

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

   void _startNotificationPolling() {
    // Annule le timer précédent s'il existe
    _notificationTimer?.cancel();
    
    // Lance un polling toutes les 30 secondes
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        // Ne pas attendre la réponse pour ne pas bloquer
        try {
          // Accède au provider via un contexte global si disponible
          // OU passe le NotificationProvider en paramètre à AuthProvider
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

  /// Changer le nom d'utilisateur
  Future<bool> changeUsername(String newUsername) async {
    _error = null;
    usernameSuggestions = null;
    notifyListeners();

    try {
      final res = await _api.post('${AppConstants.changeUsername}/$newUsername');
      
      // Refresh le profil pour obtenir le nouveau username
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
        //final message = data?['message']['message']?.toString() ?? 'Nom d\'utilisateur non disponible';
        final messageObj = data?['message'];

        // ✅ Récupérer les suggestions du backend
        

        if (messageObj is Map) {
        // Si message est un objet avec message et suggestions
        final errorText = messageObj['message']?.toString() ?? 'Nom d\'utilisateur non disponible';
        
        _error = errorText;
        if (errorText.contains('already taken')) {
          _error = "Ce nom d'utilisateur est déjà pris";
        } else if (errorText.contains('invalid')) {
          _error = "Nom d'utilisateur invalide (3-30 caractères, minuscules, _ et chiffres)";
        }else{
          _error = "Nom d'utilisateur non disponible";
        }
        //print("✅ Error message parsed: $_error");

        // ✅ Récupérer les suggestions correctement
        if (messageObj['suggestions'] != null && messageObj['suggestions'] is List) {
            usernameSuggestions = (messageObj['suggestions'] as List)
                .map((s) => s.toString())
                .toList();
            
            print("✅ Username Suggestions parsed: $usernameSuggestions");
          }
        } else {
          // Si message est juste une string
          _error = messageObj?.toString() ?? 'Nom d\'utilisateur non disponible';
        }
      } else {
        _error = 'Erreur de connexion';
      }
      
      notifyListeners();
      return false;
    }
  }

  /// Nettoyer l'erreur de nom d'utilisateur
  void clearUsernameError() {
    _error = null;
    usernameSuggestions = null;
    notifyListeners();
  }

  /// Définir une erreur personnalisée pour le nom d'utilisateur
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
        // Ancien format (liste)
        final list = res.data['data']['suggestions'] as List;
        return list.map((e) => e.toString()).toList();
      } else if (res.data['data']['username'] != null) {
        // Nouveau format (single username)
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
