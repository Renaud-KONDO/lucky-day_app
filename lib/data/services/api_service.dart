/* import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class ApiService {
  late final Dio _dio;
  Dio get dio => _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: Duration(seconds: AppConstants.requestTimeout),
      receiveTimeout: Duration(seconds: AppConstants.requestTimeout),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        return handler.next(error);
      },
    ));
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(AppConstants.userKey);
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return await _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }
} */

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class ApiService {
  // Singleton strict
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  late final Dio _dio;
  Dio get dio => _dio;

  //Callback statique pour notifier l'expiration du token
  static Function? _onTokenExpired;

  static void setOnTokenExpired(Function callback) {
    _onTokenExpired = callback;
  }

  //Constructeur privé
  ApiService._internal() {
    print('🔧 Initializing ApiService singleton...');
    
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: Duration(seconds: AppConstants.requestTimeout),
      receiveTimeout: Duration(seconds: AppConstants.requestTimeout),
      headers: {'Content-Type': 'application/json'},
    ));

    //  Ajout intercepteur
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        print('📤 Request: ${options.method} ${options.path}');
        
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        } else {
          print('⚠️ No token found');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      /* onError: (error, handler) async {
        
        // expiration du token (401 Unauthorized)
        if (error.response?.statusCode == 401) {
         
          // Nettoyer les données d'authentification
          await clearToken();

          //  Notifier l'application
          if (_onTokenExpired != null) {
            _onTokenExpired!();
          } else {
            print('⚠️ WARNING: _onTokenExpired callback is NULL!');
          }
        }

        // Passer l'erreur au handler
        return handler.next(error);
      }, */

      onError: (error, handler) async {
        print('🔴🔴🔴 INTERCEPTOR onError TRIGGERED 🔴🔴🔴');
        print('🔴 Error type: ${error.type}');
        print('🔴 Status code: ${error.response?.statusCode}');
        print('🔴 Request path: ${error.requestOptions.path}');
        print('🔴 Error message: ${error.message}');
        
        // ═══════════════════════════════════════════════════════════
        // 1️⃣ ERREURS RÉSEAU (pas de response)
        // ═══════════════════════════════════════════════════════════
        if (error.response == null) {
          print('⚠️ No response - network error');
          
          String friendlyMessage;
          
          switch (error.type) {
            case DioExceptionType.connectionTimeout:
              friendlyMessage = 'Délai de connexion dépassé. Vérifiez votre connexion internet.';
              break;
            case DioExceptionType.sendTimeout:
              friendlyMessage = 'Envoi trop long. Vérifiez votre connexion internet.';
              break;
            case DioExceptionType.receiveTimeout:
              friendlyMessage = 'Réception trop longue. Vérifiez votre connexion internet.';
              break;
            case DioExceptionType.connectionError:
              friendlyMessage = 'Impossible de se connecter au serveur. Vérifiez votre connexion internet.';
              break;
            case DioExceptionType.badCertificate:
              friendlyMessage = 'Certificat de sécurité invalide.';
              break;
            case DioExceptionType.cancel:
              friendlyMessage = 'Requête annulée.';
              break;
            default:
              friendlyMessage = 'Erreur de connexion. Vérifiez votre connexion internet.';
          }
          
          // ✅ Créer une réponse avec un message user-friendly
          return handler.next(DioException(
            requestOptions: error.requestOptions,
            response: Response(
              requestOptions: error.requestOptions,
              statusCode: 0, // Code spécial pour erreur réseau
              data: {'message': friendlyMessage},
            ),
            type: error.type,
            error: error.error,
          ));
        }
        
        // ═══════════════════════════════════════════════════════════
        // 2️⃣ CAS SPÉCIAL : 401 = Token expiré
        // ═══════════════════════════════════════════════════════════
        if (error.response?.statusCode == 401) {
          print('🔴 401 UNAUTHORIZED - Token expired!');
          await clearToken();

          if (_onTokenExpired != null) {
            print('🔴 Calling _onTokenExpired callback NOW');
            _onTokenExpired!();
          }
          
          // Laisser passer l'erreur 401 telle quelle
          return handler.next(error);
        }

        // ═══════════════════════════════════════════════════════════
        // 3️⃣ VÉRIFIER SI LE BACKEND A RETOURNÉ UN MESSAGE
        // ═══════════════════════════════════════════════════════════
        final responseData = error.response?.data;
        
        if (responseData is Map && responseData['message'] != null) {
          final message = responseData['message'];
          
          // ═══════════════════════════════════════════════════════════
          // 4️⃣ CAS SPÉCIAL : Messages structurés (username suggestions, etc.)
          // ═══════════════════════════════════════════════════════════
          if (message is Map) {
            print('✅ Structured message detected, keeping it intact');
            return handler.next(error);
          }
          
          // ═══════════════════════════════════════════════════════════
          // 5️⃣ VÉRIFIER SI C'EST UNE ERREUR TECHNIQUE
          // ═══════════════════════════════════════════════════════════
          if (message is String) {
            final isTechnical = _isTechnicalError(message);
            
            if (isTechnical) {
              print('⚠️ Technical error detected, transforming');
              
              final friendlyMessage = _getFriendlyMessage(error);
              
              return handler.next(DioException(
                requestOptions: error.requestOptions,
                response: Response(
                  requestOptions: error.requestOptions,
                  statusCode: error.response?.statusCode,
                  data: {'message': friendlyMessage},
                ),
                type: error.type,
              ));
            } else {
              print('✅ Message is already user-friendly');
              return handler.next(error);
            }
          }
        }

        // ═══════════════════════════════════════════════════════════
        // 6️⃣ AUTRES CAS : Laisser passer
        // ═══════════════════════════════════════════════════════════
        print('⚠️ Unhandled error case, passing through');
        return handler.next(error);
      },
    ));

    print('✅ ApiService initialized with interceptors');
  }

  // ✅ Détecter si c'est une erreur technique à masquer
  bool _isTechnicalError(String message) {
    final technicalPatterns = [
      'prisma',
      'Prisma',
      //'Invalid',
      'invocation',
      'Unknown field',
      'Unknown argument',
      'include statement',
      'database error',
      'Query failed',
      'at Object.',
      'at async',
      'stack trace',
      'TypeError',
      'ReferenceError',
      'SyntaxError',
      'node_modules',
      'lib/',
      'src/',
      '    at ',
    ];

    return technicalPatterns.any((pattern) => message.contains(pattern));
  }

  // ✅ Obtenir un message user-friendly selon le contexte
  String _getFriendlyMessage(DioException error) {
    final statusCode = error.response?.statusCode;
    final path = error.requestOptions.path;

    // Messages personnalisés par route
    if (path.contains('/transactions')) {
      return 'Impossible de charger vos transactions. Veuillez réessayer.';
    }

    if (path.contains('/raffles')) {
      return 'Impossible de charger les tombolas. Veuillez réessayer.';
    }

    if (path.contains('/notifications')) {
      return 'Impossible de charger les notifications. Veuillez réessayer.';
    }

    if (path.contains('/stores')) {
      return 'Impossible de charger les boutiques. Veuillez réessayer.';
    }

    // Messages par code HTTP
    switch (statusCode) {
      case 400:
        return 'Données invalides. Veuillez vérifier vos informations.';
      case 403:
        return 'Vous n\'avez pas la permission d\'effectuer cette action.';
      case 404:
        return 'Ressource introuvable.';
      case 500:
        return 'Erreur serveur. Veuillez réessayer plus tard.';
      case 503:
        return 'Service temporairement indisponible.';
      default:
        return 'Une erreur technique est survenue. Veuillez réessayer.';
    }
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  Future<void> clearToken() async {
    print('🧹 Clearing auth tokens...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(AppConstants.userKey);
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return await _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }
}