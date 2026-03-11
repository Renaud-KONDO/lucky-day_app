import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../data/models/transaction.dart';
import '../data/repositories/transaction_repository.dart';

class TransactionProvider with ChangeNotifier {
  final TransactionRepository _repo;

  List<Transaction> _transactions = [];
  TransactionStats? _stats;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  
  // Pagination
  int _currentPage = 1;
  bool _hasMore = true;
  
  // Filtres
  String? _typeFilter;
  String? _statusFilter;

  TransactionProvider(this._repo);

  // Getters
  List<Transaction> get transactions => _transactions;
  TransactionStats? get stats => _stats;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _error;
  String? get typeFilter => _typeFilter;
  String? get statusFilter => _statusFilter;

  /// Récupérer les transactions (refresh)
  /* Future<void> fetchTransactions({
    String? type,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _loading = true;
    _error = null;
    _currentPage = 1;
    _hasMore = true;
    _typeFilter = type;
    _statusFilter = status;
    notifyListeners();

    try {
      final result = await _repo.getMyTransactions(
        page: _currentPage,
        type: type,
        status: status,
        startDate: startDate,
        endDate: endDate,
      );

      _transactions = result['transactions'] as List<Transaction>;
      
      final pagination = result['pagination'] as Map<String, dynamic>;
      _hasMore = pagination['hasMore'] as bool? ?? false;

      print('✅ Transactions fetched: ${_transactions.length}');
    } catch (e) {
      print('❌ Error fetching transactions: $e');
      _error = 'Erreur lors du chargement des transactions';
      
      /* if (e is DioException) {
        final message = e.response?.data?['message']?.toString();
        if (message != null) _error = message;
      } */
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
          _error = 'Error while fetching transactions';
        }
      } else {
        _error = 'Error while fetching transaction. Not a Dio Exception';
      }
    }

    _loading = false;
    notifyListeners();
  } */
 Future<void> fetchTransactions({
    String? type,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _loading = true;
    _error = null;
    _currentPage = 1;
    _hasMore = true;
    _typeFilter = type;
    _statusFilter = status;
    notifyListeners();

    try {
      final result = await _repo.getMyTransactions(
        page: _currentPage,
        type: type,
        status: status,
        startDate: startDate,
        endDate: endDate,
      );

      _transactions = result['transactions'] as List<Transaction>;
      
      final pagination = result['pagination'] as Map<String, dynamic>?;
      _hasMore = pagination?['hasMore'] as bool? ?? false;

      // ✅ Optionnel : récupérer les stats directement
      final statistics = result['statistics'] as Map<String, dynamic>?;
      if (statistics != null) {
        print('📊 Stats from response: $statistics');
        // Tu peux les stocker dans le provider si besoin
      }

      print('✅ Transactions fetched: ${_transactions.length}');
      _error = null;
    } catch (e) {
      print('❌ Error fetching transactions: $e');
      
      if (e is DioException && e.response?.data is Map) {
        _error = e.response!.data['message']?.toString() ?? 
                'Erreur lors du chargement des transactions';
      } else {
        _error = 'Erreur lors du chargement des transactions';
      }
    }

    _loading = false;
    notifyListeners();
  }

  /// Charger plus de transactions (pagination)
  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;

    _loadingMore = true;
    notifyListeners();

    try {
      _currentPage++;
      
      final result = await _repo.getMyTransactions(
        page: _currentPage,
        type: _typeFilter,
        status: _statusFilter,
      );

      final newTransactions = result['transactions'] as List<Transaction>;
      _transactions.addAll(newTransactions);
      
      final pagination = result['pagination'] as Map<String, dynamic>;
      _hasMore = pagination['hasMore'] as bool? ?? false;

      print('✅ Loaded more transactions: ${newTransactions.length}');
    } catch (e) {
      print('❌ Error loading more transactions: $e');

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
          _error = 'Error while getting more transactions';
        }
      } else {
        _error = 'Error while getting more transactions. Not a Dio Exception';
      }
      _currentPage--;
    }

    _loadingMore = false;
    notifyListeners();
  }

  /// Récupérer les statistiques
  Future<void> fetchStats() async {
    try {
      _stats = await _repo.getMyStats();
      print('✅ Stats fetched: ${_stats?.totalTransactions} transactions');
      notifyListeners();
    } catch (e) {
      print('❌ Error fetching stats: $e');

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
          _error = 'Error while fetching transactions Stats';
        }
      } else {
        _error = 'Error while fetching transaction Stats. Not a Dio Exception';
      }
    }
  }

  /// Nettoyer les filtres
  void clearFilters() {
    _typeFilter = null;
    _statusFilter = null;
    fetchTransactions();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}