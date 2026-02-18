import 'package:flutter/foundation.dart' hide Category;
import '../data/models/models.dart';
import '../data/repositories/category_repository.dart';

class CategoryProvider with ChangeNotifier {
  final CategoryRepository _repo;
  List<Category> _storeCategories   = [];
  List<Category> _productCategories = [];
  bool _loading = false;

  CategoryProvider(this._repo);

  List<Category> get storeCategories   => _storeCategories;
  List<Category> get productCategories => _productCategories;
  bool get isLoading => _loading;

  Future<void> fetchStoreCategories() async {
    if (_storeCategories.isNotEmpty) return; // cache simple
    _loading = true; notifyListeners();
    try {
      _storeCategories = await _repo.getStoreCategories();
    } catch (_) {}
    _loading = false; notifyListeners();
  }

  Future<void> fetchProductCategories() async {
    if (_productCategories.isNotEmpty) return; // cache simple
    _loading = true; notifyListeners();
    try {
      _productCategories = await _repo.getProductCategories();
    } catch (_) {}
    _loading = false; notifyListeners();
  }
}