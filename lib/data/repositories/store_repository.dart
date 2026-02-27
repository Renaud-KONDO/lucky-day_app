import 'package:dio/dio.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../../core/constants/app_constants.dart';

class StoreRepository {
  final ApiService _api;
  StoreRepository(this._api);

  Future<List<Store>> getAllStores({String? search, bool? isActive, String? categoryId}) async {
    final params = <String, dynamic>{'limit': AppConstants.pageSize};
    if (search != null) params['search'] = search;
    if (isActive != null) params['isActive'] = isActive;
    if (categoryId != null)  params['categoryId'] = categoryId;  // ← ajouter
    final res = await _api.get(AppConstants.stores, queryParameters: params);
    final list = (res.data['data'] ?? []) as List;
    return list.map((e) => Store.fromJson(e)).toList();
  }

  Future<List<Store>> getMyStores() async {
    final res = await _api.get(AppConstants.myStores);
    final list = (res.data['data'] ?? []) as List;
    return list.map((e) => Store.fromJson(e)).toList();
  }

  Future<Store> getStoreById(String id) async {
    final res = await _api.get('${AppConstants.stores}/$id');
    return Store.fromJson(res.data['data']);
  }

  Future<List<Product>> getStoreProducts(String storeId) async {
    final res = await _api.get('${AppConstants.productsByStore}/$storeId');
    final list = (res.data['data'] ?? []) as List;
    return list.map((e) => Product.fromJson(e)).toList();
  }

  Future<Store> createStore(Map<String, dynamic> data) async {
    final res = await _api.post(AppConstants.stores, data: data);
    return Store.fromJson(res.data['data']);
  }

  Future<Store> updateStore(String id, Map<String, dynamic> data) async {
    final res = await _api.put('${AppConstants.stores}/$id', data: data);
    return Store.fromJson(res.data['data']);
  }

  /// Créer un store et retourner l'objet
  Future<Store> createStoreAndReturn(Map<String, dynamic> data) async {
    print('🔵 Repository: Creating store with data: $data');
    
    try {
      final res = await _api.post('/stores', data: data);
      print('✅ Repository: Store created successfully');
      print('📦 Response data: ${res.data}');
      
      return Store.fromJson(res.data['data']);
    } catch (e) {
      print('❌ Repository error: $e');
      
      if (e is DioException) {
        print('📛 Status: ${e.response?.statusCode}');
        print('📛 Response: ${e.response?.data}');
      }
      
      rethrow;
    }
  }
}

class ProductRepository {
  final ApiService _api;
  ProductRepository(this._api);

  Future<List<Product>> getAllProducts({String? search}) async {
    final params = <String, dynamic>{'limit': AppConstants.pageSize};
    if (search != null) params['search'] = search;
    final res = await _api.get(AppConstants.products, queryParameters: params);
    final list = (res.data['data'] ?? []) as List;
    return list.map((e) => Product.fromJson(e)).toList();
  }

  Future<Product> getProductById(String id) async {
    final res = await _api.get('${AppConstants.products}/$id');
    return Product.fromJson(res.data['data']);
  }

  Future<List<Raffle>> getProductRaffles(String productId) async {
    final res = await _api.get(AppConstants.raffles, queryParameters: {'productId': productId});
    final list = (res.data['data'] ?? []) as List;
    return list.map((e) => Raffle.fromJson(e)).toList();
  }
  
}
