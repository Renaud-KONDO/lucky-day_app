import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'api_service.dart';
import '../../core/constants/app_constants.dart';

class UploadService {
  final ApiService _api;
  UploadService(this._api);

  Future<String> uploadAvatar(File imageFile) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'avatar.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    });
    final res = await _api.dio.post(AppConstants.uploadAvatar, data: formData);
    return res.data['data']['avatarUrl'];
  }

  Future<String> uploadStoreLogo(String storeId, File imageFile) async {
    final formData = FormData.fromMap({
      'logo': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'logo.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    });
    final res = await _api.dio.post(
      '${AppConstants.uploadStoreLogo}/$storeId/logo',
      data: formData,
    );
    return res.data['data']['logoUrl'];
  }

  Future<String> uploadStoreBanner(String storeId, File imageFile) async {
    final formData = FormData.fromMap({
      'banner': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'banner.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    });
    final res = await _api.dio.post(
      '${AppConstants.uploadStoreBanner}/$storeId/banner',
      data: formData,
    );
    return res.data['data']['bannerUrl'];
  }

  Future<List<String>> uploadProductImages(String productId, List<File> imageFiles) async {
    final List<MultipartFile> files = [];
    for (var file in imageFiles) {
      files.add(await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
        contentType: MediaType('image', 'jpeg'),
      ));
    }
    final formData = FormData.fromMap({'images': files});
    final res = await _api.dio.post(
      '${AppConstants.uploadProductImages}/$productId/images',
      data: formData,
    );
    final list = res.data['data']['imageUrls'] as List;
    return list.map((e) => e.toString()).toList();
  }

  Future<void> deleteProductImage(String productId, String imageUrl) async {
    await _api.dio.delete(
      '${AppConstants.deleteProductImage}/$productId/images',
      data: {'imageUrl': imageUrl},
    );
  }
}