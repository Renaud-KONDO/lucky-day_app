import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../data/models/models.dart';
import '../data/repositories/lottery_repository.dart';
import '../core/constants/app_constants.dart';
import 'package:logger/logger.dart';

class RaffleProvider with ChangeNotifier {
  final RaffleRepository _repo;
  List<Raffle> _all = [];
  List<Raffle> _mine = [];
  List<Raffle> _wins = [];
  List<Raffle> _myCreated = [];  
  bool _loading = false;
  String? _error;
  var logger = Logger();
  Map<String, List<Raffle>> _winners = {}; // par probabilityType

  RaffleProvider(this._repo);

  // Getters
  List<Raffle> get allRaffles => _all;
  List<Raffle> get myRaffles  => _mine;
  List<Raffle> get myWins     => _wins;
  List<Raffle> get myCreatedRaffles => _myCreated;  
  bool   get isLoading    => _loading;
  String? get errorMessage => _error;

  List<Raffle> byProbability(String type) =>
      _all.where((r) => r.probabilityType == type).toList();

  List<Raffle> recentWinners(String type) => _winners[type] ?? [];

  // ═══════════════════════════════════════════════════════════════════════════
  // FETCH METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> fetchAll({String? probabilityType}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      _all = await _repo.getAllRaffles(
        status: AppConstants.raffleStatusOpen,
        probabilityType: probabilityType,
      );
      // Charger les gagnants récents pour chaque type
      await Future.wait([
        _fetchWinnersFor(AppConstants.highProbability),
        _fetchWinnersFor(AppConstants.mediumProbability),
        _fetchWinnersFor(AppConstants.lowProbability),
      ]);
      logger.i("raffles get end ! ");
    } catch (e) {
      _error = 'Erreur de chargement des tombolas';
      //logger.e("error listing raffles : $e");
      if (e is DioException && e.response?.data is Map) {
        _error = e.response!.data['message']?.toString() ?? 
                'Une erreur est survenue';
      } else {
        _error = 'Une erreur est survenue';
      }
    }
    _loading = false; notifyListeners();
  }

  Future<void> _fetchWinnersFor(String type) async {
    try {
      _winners[type] = await _repo.getRecentWinners(probabilityType: type);
    } catch (_) {
      _winners[type] = [];
    }
  }

  Future<void> fetchMine() async {
    try {
      print('🔵 Fetching my raffles...');
      _mine = await _repo.getMyRaffles();
      logger.i("mine raffles get end ! ");
      logger.i("here is the list of raffles and its details : ${_mine.map((r) => 'Raffle: ${r.id}, Status: ${r.status}, Prize: ${r.product?.name}').join('\n')}");
      notifyListeners();
      print('✅ My raffles fetched successfully: ${_mine.length}');
    } catch (e) {
      print('❌ Error fetching my raffles: $e');

      if (e is DioException) {
      print('🔴 DioException status code: ${e.response?.statusCode}');
      if (e.response?.statusCode == 401) {
        print('🔴🔴🔴 401 DETECTED IN PROVIDER - Token should expire now');
      }
    }

    notifyListeners();
      logger.e("error fetching my raffles: $e");
    }
  }

  Future<void> fetchWins() async {
    try {
      _wins = await _repo.getMyWins();
      logger.i("wins fetched: ${_wins.length}");
      notifyListeners();
    } catch (e) {
      logger.e("error fetching wins: $e");
    }
  }

  /// ← Nouveau : Récupère les tombolas créées par l'utilisateur (store owners)
  Future<void> fetchMyCreatedRaffles(String userId) async {
    print('🔄 fetchMyCreatedRaffles() called');

    _loading = true; _error = null;  notifyListeners();
    try {
      _myCreated = await _repo.getMyCreatedRaffles(userId);
      logger.i("my created raffles fetched: ${_myCreated.length}");
      _error = null;
      print('✅ No error, _error = $_error');

    } catch (e) {
      logger.e("❌ error fetching my created raffles: $e");

      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message']?.toString() ?? '';
        
        // Si non autorisé, pas d'erreur visible
        if (statusCode == 400 || statusCode == 403 || statusCode == 401 || 
            message.contains('not authorized') || 
            message.contains('Unauthorized') ||
            message.contains('No raffles') ||
            message.contains('not found')) {
          _myCreated = [];
          _error = null;
          print('⚠️ Non-critical error, no error message set');
        } else {
          _error = 'Erreur de chargement de vos tombolas';
          print('❌ Error set: $_error');
        }
      } else {
        _error = 'Erreur de chargement de vos tombolas';
        print('❌ Error set: $_error');
      }
    }
    _loading = false; notifyListeners();
    print('🏁 fetchMyCreatedRaffles() finished, _error = $_error');

  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PARTICIPATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> participate(String raffleId, String participationType) async {
    _loading = true; _error = null; notifyListeners();
    try {
      await _repo.participate(raffleId, participationType);
      await fetchAll(); 
      await fetchMine();
      _loading = false; 
      notifyListeners(); 
      return true;
    } catch (e) {
      // Extraire le message d'erreur du backend
      String errorMessage = 'Erreur de participation';
      
      if (e is DioException) {
        final backendMessage = e.response?.data?['message']?.toString() ?? '';
        
        if (backendMessage.contains('not found')) {
          errorMessage = 'Tombola introuvable';
        } else if (backendMessage.contains('not open')) {
          errorMessage = 'Cette tombola n\'est plus ouverte aux participations';
        } else if (backendMessage.contains('already full')) {
          errorMessage = 'Cette tombola est complète';
        } else if (backendMessage.contains('already participated')) {
          errorMessage = 'Vous avez déjà participé à cette tombola';
        } else if (backendMessage.contains('Insufficient')) {
          errorMessage = 'Solde insuffisant. Rechargez votre portefeuille.';
        } else if (backendMessage.isNotEmpty) {
          errorMessage = backendMessage;
        }
      }
      
      _error = errorMessage;
      logger.e("participation error: $errorMessage");
      _loading = false; 
      notifyListeners(); 
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLAIM PRIZE (mis à jour pour accepter options)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> claimPrize(String raffleId, Map<String, dynamic> options) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final claimOption = options['claimOption'] as String;
      Map<String, dynamic>? deliveryAddress;

      if (options.containsKey('deliveryAddress')) {
      deliveryAddress = {'deliveryAddress': options['deliveryAddress']};
    } else if (options.containsKey('useCurrentLocation')) {
      deliveryAddress = {'useCurrentLocation': options['useCurrentLocation']};
    }

       await _repo.claimPrize(
        raffleId: raffleId,
        claimOption: claimOption,
        deliveryAddress: deliveryAddress,
      );
      await fetchWins();
      _loading = false; 
      notifyListeners();
      return true;
    } catch (e) {
      if (e is DioException) {
        final backendMessage = e.response?.data?['message']?.toString() ?? '';
        
        if (backendMessage.contains('not authorized')) {
          _error = "Vous n'êtes pas le gagnant";
        } else if (backendMessage.contains('already claimed')) {
          _error = 'Prix déjà réclamé';
        } else if (backendMessage.contains('Cash option')) {
          _error = 'Option cash non disponible pour cette tombola';
        } else if (backendMessage.contains('address')) {
          _error = 'Adresse de livraison requise';
        } else if (backendMessage.isNotEmpty) {
          _error = backendMessage;
        } else {
          _error = 'Erreur de réclamation';
        }
      } else {
        _error = 'Erreur de réclamation';
      }
      
      logger.e("claim prize error: $_error");
      _loading = false; 
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CREATE RAFFLE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> createRaffle(Map<String, dynamic> data, {String? userId}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      await _repo.createRaffle(data);
      //logger.i("raffle created successfully");
      //Logger().i("raffle creation data: $data");
      
      // Refresh les listes
      if (userId != null) {
        await fetchMyCreatedRaffles(userId);
      }
      //await fetchMyCreatedRaffles(userId);
      await fetchAll();
      
      _loading = false; 
      notifyListeners();
      return true;
    } catch (e) {
      Logger().e("error creating raffle: $e");
      if (e is DioException) {
        //Logger().i("create raffle error status code: ${e.response?.statusCode}");
        //Logger().e("create raffle error details: ${e.response?.data?['message']?.toString() ?? ''}");
        final backendMessage = e.response?.data?['message']?.toString() ?? '';
        
        if (backendMessage.contains('Store not found')) {
          _error = 'Boutique introuvable';
        } else if (backendMessage.contains('Product not found')) {
          _error = 'Produit introuvable';
        }else if (backendMessage.contains('Product ID is required')) {
          _error = 'veillez sélectionner un produit valide. Produit non trouvé';
        } else if (backendMessage.contains('not authorized')) {
          _error = "Vous n'êtes pas autorisé à créer des tombolas pour cette boutique";
        } else if (backendMessage.contains('Product category not found')) {
          _error = 'Catégorie de produit introuvable';
        }else if (backendMessage.contains('not belong to this store')) {
          _error = 'Le produit choisi n\'appartient pas à la boutique choisie';
        } else if (backendMessage.contains('Entry price')) {
          _error = 'Prix d\'entrée invalide (minimum 100 XOF)';
        }  else if (backendMessage.contains('fees must cover the product price')) {
          _error = 'le nombre de participants doit être suffisant pour couvrir le prix du produit';
        } else if (backendMessage.contains('Max participants')) {
          _error = 'Nombre de participants invalide (entre 2 et 10000)';
        } else if (backendMessage.contains('Product price must be greater than 0')) {
          _error = 'Prix du produit doit être supérieur à 0';
        } else if (backendMessage.contains('price products (')) {
          _error = 'cette configuration ne couvre pas la commission. Revérifiez les prix et le nombre de participants';
        } else if (backendMessage.contains('Title')) {
          _error = 'Titre invalide (5-200 caractères)';
        } else if (backendMessage.contains('Cash amount')) {
          _error = 'Montant cash requis si option cash activée';
        } else if (backendMessage.isNotEmpty) {
          _error = backendMessage;
        } else {
          _error = 'Erreur lors de la création de la tombola';
        }
      } else {
        _error = 'Erreur lors de la création de la tombola : ${e.toString()}';
      }
      
      logger.e("create raffle error: $_error");
      _loading = false; 
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CANCEL RAFFLE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> cancelRaffle(String raffleId, String userId) async {
    _loading = true; _error = null; notifyListeners();
    try {
      await _repo.cancelRaffle(raffleId);
      logger.i("raffle cancelled successfully");
      
      
      // Refresh les listes
      await fetchMyCreatedRaffles(userId);
      await fetchAll();
      
      _loading = false; 
      notifyListeners();
      return true;
    } catch (e) {
      if (e is DioException) {
        final backendMessage = e.response?.data?['message']?.toString() ?? '';
        
        if (backendMessage.contains('not found')) {
          _error = 'Tombola introuvable';
        } else if (backendMessage.contains('not authorized')) {
          _error = "Vous n'êtes pas autorisé à annuler cette tombola";
        } else if (backendMessage.contains('already')) {
          _error = 'Cette tombola a déjà été annulée ou terminée';
        } else if (backendMessage.isNotEmpty) {
          _error = backendMessage;
        } else {
          _error = 'Erreur lors de l\'annulation';
        }
      } else {
        _error = 'Erreur lors de l\'annulation';
      }
      
      logger.e("cancel raffle error: $_error");
      _loading = false; 
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DRAW WINNER
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> drawWinner(String raffleId, String userId) async {
    _loading = true; _error = null; notifyListeners();
    try {
      await _repo.drawWinner(raffleId);
      logger.i("winner drawn successfully");
      
      // Refresh les listes
      await fetchMyCreatedRaffles(userId);
      await fetchAll();
      
      _loading = false; 
      notifyListeners();
      return true;
    } catch (e) {
      if (e is DioException) {
        final backendMessage = e.response?.data?['message']?.toString() ?? '';
        
        if (backendMessage.contains('not found')) {
          _error = 'Tombola introuvable';
        } else if (backendMessage.contains('not authorized')) {
          _error = "Vous n'êtes pas autorisé à tirer au sort cette tombola";
        } else if (backendMessage.contains('not full')) {
          _error = 'La tombola doit être complète avant de tirer au sort';
        } else if (backendMessage.contains('already drawn')) {
          _error = 'Le gagnant a déjà été tiré au sort';
        } else if (backendMessage.contains('No participants')) {
          _error = 'Aucun participant dans cette tombola';
        } else if (backendMessage.isNotEmpty) {
          _error = backendMessage;
        } else {
          _error = 'Erreur lors du tirage au sort';
        }
      } else {
        _error = 'Erreur lors du tirage au sort';
      }
      
      logger.e("draw winner error: $_error");
      _loading = false; 
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILS
  // ═══════════════════════════════════════════════════════════════════════════

  void clearError() { 
    _error = null; 
    notifyListeners(); 
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SSE LOCAL UPDATES (NO API CALLS)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update a raffle locally from SSE event (without API call)
  void updateRaffleLocally(Map<String, dynamic> raffleData) {
    final raffleId = raffleData['raffleId'] as String?;
    if (raffleId == null) {
      logger.w('updateRaffleLocally: No raffleId provided');
      return;
    }

    logger.i('🔄 Updating raffle $raffleId locally');

    bool updated = false;

    // Update in _all
    final allIndex = _all.indexWhere((r) => r.id == raffleId);
    if (allIndex != -1) {
      _all[allIndex] = _updateRaffleFields(_all[allIndex], raffleData);
      updated = true;
      logger.i('   ✅ Updated in allRaffles');
    }

    // Update in _mine
    final mineIndex = _mine.indexWhere((r) => r.id == raffleId);
    if (mineIndex != -1) {
      _mine[mineIndex] = _updateRaffleFields(_mine[mineIndex], raffleData);
      updated = true;
      logger.i('   ✅ Updated in myRaffles');
    }

    // Update in _myCreated
    final createdIndex = _myCreated.indexWhere((r) => r.id == raffleId);
    if (createdIndex != -1) {
      _myCreated[createdIndex] = _updateRaffleFields(_myCreated[createdIndex], raffleData);
      updated = true;
      logger.i('   ✅ Updated in myCreatedRaffles');
    }

    if (updated) {
      notifyListeners();
    } else {
      logger.w('   ⚠️ Raffle $raffleId not found in any list');
    }
  }

  /// Update specific raffle fields from SSE data
  Raffle _updateRaffleFields(Raffle raffle, Map<String, dynamic> data) {
    return raffle.copyWith(
      currentParticipants: data['currentParticipants'] as int? ?? raffle.currentParticipants,
      maxParticipants: data['maxParticipants'] as int? ?? raffle.maxParticipants,
      status: data['status'] as String? ?? raffle.status,
    );
  }

  /// Update raffle status locally (without API call)
  void updateRaffleStatusLocally(String raffleId, String newStatus) {
    logger.i('🔄 Updating raffle $raffleId status to $newStatus locally');

    bool updated = false;

    // Update in _all
    _updateRaffleInList(_all, raffleId, (r) {
      updated = true;
      return r.copyWith(status: newStatus);
    });

    // Update in _mine
    _updateRaffleInList(_mine, raffleId, (r) {
      updated = true;
      return r.copyWith(status: newStatus);
    });

    // Update in _myCreated
    _updateRaffleInList(_myCreated, raffleId, (r) {
      updated = true;
      return r.copyWith(status: newStatus);
    });

    if (updated) {
      notifyListeners();
      logger.i('   ✅ Status updated successfully');
    }
  }

  /// Remove raffle locally (for cancelled raffles, without API call)
  void removeRaffleLocally(String raffleId) {
    logger.i('🔄 Removing raffle $raffleId locally');

    final initialAllCount = _all.length;
    final initialMineCount = _mine.length;
    final initialCreatedCount = _myCreated.length;

    _all.removeWhere((r) => r.id == raffleId);
    _mine.removeWhere((r) => r.id == raffleId);
    _myCreated.removeWhere((r) => r.id == raffleId);

    final removed = (initialAllCount - _all.length) +
                    (initialMineCount - _mine.length) +
                    (initialCreatedCount - _myCreated.length);

    if (removed > 0) {
      notifyListeners();
      logger.i('   ✅ Raffle removed from $removed list(s)');
    } else {
      logger.w('   ⚠️ Raffle $raffleId not found in any list');
    }
  }

  /// Helper: Update raffle in a specific list
  void _updateRaffleInList(
    List<Raffle> list, 
    String raffleId, 
    Raffle Function(Raffle) updateFn
  ) {
    final index = list.indexWhere((r) => r.id == raffleId);
    if (index != -1) {
      list[index] = updateFn(list[index]);
    }
  }
}