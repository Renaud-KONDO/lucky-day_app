import '../models/models.dart';
import '../services/api_service.dart';
import '../../core/constants/app_constants.dart';

class RaffleRepository {
  final ApiService _api;
  RaffleRepository(this._api);

  Future<List<Raffle>> getAllRaffles({String? probabilityType, String? status, String? storeId}) async {
    final params = <String, dynamic>{'limit': AppConstants.pageSize};
    if (probabilityType != null) params['probabilityType'] = probabilityType;
    if (status != null) params['status'] = status;
    if (storeId != null) params['storeId'] = storeId;
    final res = await _api.get(AppConstants.raffles, queryParameters: params);
    final list = (res.data['data'] ?? []) as List;
    return list.map((e) => Raffle.fromJson(e)).toList();
  }

  // Récuperation des derniers gagnants (raffles tirées récemment)
  Future<List<Raffle>> getRecentWinners({String? probabilityType}) async {
    final params = <String, dynamic>{'status': 'drawn', 'limit': 5};
    if (probabilityType != null) params['probabilityType'] = probabilityType;
    final res = await _api.get(AppConstants.raffles, queryParameters: params);
    final list = (res.data['data'] ?? []) as List;
    return list.map((e) => Raffle.fromJson(e)).toList();
  }


  Future<Raffle> getRaffleById(String id) async {
    final res = await _api.get('${AppConstants.raffles}/$id');
    return Raffle.fromJson(res.data['data']);
  }

  Future<void> participate(String raffleId) async {
    await _api.post('${AppConstants.raffles}/$raffleId${AppConstants.raffleParticipate}');
  }

  Future<List<Raffle>> getMyRaffles() async {
    final res = await _api.get(AppConstants.myRaffles);
    final list = (res.data['data'] ?? []) as List;
    return list.map((e) => Raffle.fromJson(e)).toList();
  }

  Future<List<Raffle>> getMyWins() async {
    final res = await _api.get(AppConstants.myWins);
    final list = (res.data['data'] ?? []) as List;
    return list.map((e) => Raffle.fromJson(e)).toList();
  }

  Future<void> claimPrize({required String raffleId, required String claimOption, Map<String, dynamic>? deliveryAddress}) async {
    final data = {'claimOption': claimOption};
    if (deliveryAddress != null) data['deliveryAddress'] = deliveryAddress.toString();
    await _api.post('${AppConstants.raffles}/$raffleId${AppConstants.raffleClaim}', data: data);
  }
}
