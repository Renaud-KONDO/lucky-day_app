import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../data/models/models.dart';
import '../data/repositories/store_repository.dart';

class StoreProvider with ChangeNotifier {
  final StoreRepository _storeRepo;
  final ProductRepository _productRepo;
  List<Store>   _stores   = [];
  List<Store>   _myStores  = [];
  List<Product> _products = [];
  bool _loading = false;
  String? _error;

  StoreProvider(this._storeRepo, this._productRepo);

  List<Store>   get stores   => _stores;
  List<Store>   get myStores => _myStores;
  List<Product> get products => _products;
  bool   get isLoading    => _loading;
  String? get errorMessage => _error;
  

  /* Future<void> fetchStores({String? search}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      _stores = await _storeRepo.getAllStores(search: search, isActive: true);
    } catch (e) {
      _error = 'Erreur de chargement des boutiques';
    }
    _loading = false; notifyListeners();
  } */

 Future<void> fetchStores({String? search, String? categoryId}) async {
  _loading = true; _error = null; notifyListeners();
  try {
    _stores = await _storeRepo.getAllStores(
      search: search,
      isActive: true,
      categoryId: categoryId,    // ← ajouter
    );
  } catch (_) { _error = 'Erreur de chargement des boutiques'; }
  _loading = false; notifyListeners();
}

  Future<void> fetchMyStores() async {
    _loading = true; notifyListeners();
    try {
      _myStores = await _storeRepo.getMyStores();
      notifyListeners();
    } catch (e) {
      print('❌ Error fetching my stores: $e');
      _myStores = []; 
    }
    _loading = false; notifyListeners();
  }

  Future<Store?> createStore(Map<String, dynamic> data) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final store = await _storeRepo.createStore(data);
      _myStores.insert(0, store);
      _loading = false; notifyListeners();
      return store;
    } catch (e) {
      _error = 'Erreur lors de la création de la boutique';
      _loading = false; notifyListeners();
      return null;
    }
  }

  Future<void> fetchStoreProducts(String storeId) async {
    _loading = true; notifyListeners();
    try {
      _products = await _storeRepo.getStoreProducts(storeId);
    } catch (_) {
      _products = [];
    }
    _loading = false; notifyListeners();
  }

  void clearError() { _error = null; notifyListeners(); }

  /// Créer un store et retourner l'objet Store créé
  Future<Store?> createStoreAndReturn(Map<String, dynamic> data) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      print('📤 Creating store with data: $data');
      final store = await _storeRepo.createStoreAndReturn(data);
      print('✅ Store created: ${store.id}');
      _loading = false;
      notifyListeners();
      return store;
    } catch (e) {
      print('❌ Error creating store: $e');
      
      // ✅ Extraire le message du backend si c'est une DioException
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final backendMessage = e.response?.data?['message']?.toString() ?? '';
        final errors = e.response?.data?['errors'];
        
        print('📛 Status code: $statusCode');
        print('📛 Backend message: $backendMessage');
        print('📛 Errors: $errors');
        
        if (backendMessage.isNotEmpty) {
          _error = backendMessage;
        } else {
          _error = 'Erreur lors de la création de la boutique';
        }
      } else {
        _error = 'Erreur lors de la création de la boutique';
      }
      
      _loading = false;
      notifyListeners();
      return null;
    }
  }
}
