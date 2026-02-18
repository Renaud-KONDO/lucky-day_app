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
  bool _loading = false;
  String? _error;
  var logger = Logger();


  RaffleProvider(this._repo);

  List<Raffle> get allRaffles => _all;
  List<Raffle> get myRaffles  => _mine;
  List<Raffle> get myWins     => _wins;
  Map<String, List<Raffle>> _winners = {}; // par probabilityType
  bool   get isLoading    => _loading;
  String? get errorMessage => _error;

  List<Raffle> byProbability(String type) =>
      _all.where((r) => r.probabilityType == type).toList();

  List<Raffle> recentWinners(String type) => _winners[type] ?? [];

  Future<void> fetchAll({String? probabilityType}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      //logger.i("let's get all raffle. raffles get start ! ");
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
      logger.e("error listing raffles : $e");
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

  Future<bool> participate(String raffleId) async {
    _loading = true; _error = null; notifyListeners();
    try {
      await _repo.participate(raffleId);
      await fetchAll();
      await fetchMine();
      _loading = false; notifyListeners();
      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Insufficient'))        _error = 'Solde insuffisant';
      else if (msg.contains('already'))         _error = 'Vous participez déjà';
      else if (msg.contains('full'))            _error = 'Tombola complète';
      else                                      _error = 'Erreur de participation';
      _loading = false; notifyListeners();
      return false;
    }
  }

  Future<void> fetchMine() async {
    try {
      _mine = await _repo.getMyRaffles();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchWins() async {
    try {
      _wins = await _repo.getMyWins();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> claimPrize({
    required String raffleId,
    required String claimOption,
    Map<String, dynamic>? deliveryAddress,
  }) async {
    _loading = true; _error = null; notifyListeners();
    try {
      await _repo.claimPrize(
        raffleId: raffleId,
        claimOption: claimOption,
        deliveryAddress: deliveryAddress,
      );
      await fetchWins();
      _loading = false; notifyListeners();
      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('not authorized'))     _error = "Vous n'êtes pas le gagnant";
      else if (msg.contains('already'))       _error = 'Prix déjà réclamé';
      else if (msg.contains('Cash option'))   _error = 'Option cash non disponible';
      else if (msg.contains('address'))       _error = 'Adresse requise';
      else                                    _error = 'Erreur de réclamation';
      _loading = false; notifyListeners();
      return false;
    }
  }

  void clearError() { _error = null; notifyListeners(); }
}
