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
      onError: (error, handler) async {
        
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
      },
    ));

    print('✅ ApiService initialized with interceptors');
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