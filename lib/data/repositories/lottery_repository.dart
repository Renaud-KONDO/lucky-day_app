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
    final params = <String, dynamic>{'status': 'completed', 'limit': 5};
    if (probabilityType != null) params['probabilityType'] = probabilityType;
    final res = await _api.get(AppConstants.raffles, queryParameters: params);
    final list = (res.data['data'] ?? []) as List;
    return list.map((e) => Raffle.fromJson(e)).toList();
  }


  Future<Raffle> getRaffleById(String id) async {
    final res = await _api.get('${AppConstants.raffles}/$id');
    return Raffle.fromJson(res.data['data']);
  }

  Future<void> participate(String raffleId, String participationType) async {
    await _api.post('${AppConstants.raffles}/$raffleId${AppConstants.raffleParticipate}/$participationType');
  }

  Future<List<Raffle>> getMyRaffles() async {
    final res = await _api.get(AppConstants.myRaffles);
    /* final list = (res.data['data'] ?? []) as List;
    return list.map((e) => Raffle.fromJson(e)).toList(); */

    // Le backend renvoie des participations avec raffle imbriqué
  final participations = (res.data['data'] ?? []) as List;
  
  print('📦 Participations received: ${participations.length}');
  
  // Extraire les raffles depuis les participations
  final raffles = <Raffle>[];
  
  for (var participation in participations) {
    final raffleData = participation['raffle'];
    
    if (raffleData != null) {
      try {
        final raffle = Raffle.fromJson(raffleData);
        raffles.add(raffle);
      } catch (e) {
        print('❌ Error parsing raffle: $e');
        print('   Raffle data: $raffleData');
      }
    } else {
      print('⚠️ Participation without raffle: ${participation['id']}');
    }
  }
  
  print('✅ Parsed ${raffles.length} raffles');
  
  return raffles;
  }

  Future<List<Raffle>> getMyWins() async {
    final res = await _api.get(AppConstants.myWins);
    /* final list = (res.data['data'] ?? []) as List;
    return list.map((e) => Raffle.fromJson(e)).toList(); */

    // Même structure
    final wins = (res.data['data'] ?? []) as List;
    
    final raffles = <Raffle>[];
    
    for (var win in wins) {
      final raffleData = win['raffle'];
      
      if (raffleData != null) {
        try {
          raffles.add(Raffle.fromJson(raffleData));
        } catch (e) {
          print('❌ Error parsing won raffle: $e');
        }
      }
  }
  
  return raffles;
  }

  Future<void> claimPrize({required String raffleId, required String claimOption, Map<String, dynamic>? deliveryAddress}) async {
    final data = {'claimOption': claimOption};
    if (deliveryAddress != null) data['deliveryAddress'] = deliveryAddress.toString();
    await _api.post('${AppConstants.raffles}/$raffleId${AppConstants.raffleClaim}', data: data);
  }

  Future<List<Raffle>> getMyCreatedRaffles(String userId) async {
    final res = await _api.get('/raffles/user/$userId/created');
    final raffles = (res.data['data']['raffles'] ?? []) as List;
    return raffles.map((r) => Raffle.fromJson(r)).toList();
  }

  /// Créer une nouvelle tombola
  Future<void> createRaffle(Map<String, dynamic> data) async {
    await _api.post('/raffles', data: data);
  }

  /// Annuler une tombola
  Future<void> cancelRaffle(String raffleId) async {
    await _api.post('/raffles/$raffleId/cancel');
  }

  /// Tirer au sort le gagnant
  Future<void> drawWinner(String raffleId) async {
    await _api.post('/raffles/$raffleId/draw');
  }


}
