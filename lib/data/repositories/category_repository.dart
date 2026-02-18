import '../models/models.dart';
import '../services/api_service.dart';
import '../../core/constants/app_constants.dart';

class CategoryRepository {
  final ApiService _api;
  CategoryRepository(this._api);

  Future<List<Category>> getStoreCategories() async {
    final res = await _api.get(AppConstants.storeCategories);
    final list = (res.data['data'] ?? []) as List;
    return list.map((e) => Category.fromJson(e)).toList();
  }

  Future<List<Category>> getProductCategories() async {
    final res = await _api.get(AppConstants.productCategories);
    final list = (res.data['data'] ?? []) as List;
    return list.map((e) => Category.fromJson(e)).toList();
  }
}