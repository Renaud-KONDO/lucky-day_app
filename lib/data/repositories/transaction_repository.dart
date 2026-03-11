/* import '../models/transaction.dart';
import '../services/api_service.dart';

class TransactionRepository {
  final ApiService _api;

  TransactionRepository(this._api);

  /// Récupérer mes transactions avec pagination et filtres
  Future<Map<String, dynamic>> getMyTransactions({
    int page = 1,
    int limit = 20,
    String? type,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };

    if (type != null) queryParams['type'] = type;
    if (status != null) queryParams['status'] = status;
    if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
    if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

    final res = await _api.get('/transactions/my', queryParameters: queryParams);

    print('🔍 Raw response data: ${res.data}');
    print('🔍 Response type: ${res.data.runtimeType}');

    // ✅ Gérer les différentes structures de réponse
    dynamic transactionsData;
    dynamic paginationData;

    if (res.data is Map) {
      // Structure 1: {data: [...], pagination: {...}}
      if (res.data.containsKey('data')) {
        transactionsData = res.data['data'];
        paginationData = res.data['pagination'];
      }
      // Structure 2: {transactions: [...], pagination: {...}}
      else if (res.data.containsKey('transactions')) {
        transactionsData = res.data['transactions'];
        paginationData = res.data['pagination'];
      }
      // Structure 3: Tout le data est directement les transactions
      else {
        transactionsData = res.data;
        paginationData = null;
      }
    } else if (res.data is List) {
      // Structure 4: Réponse directe en array
      transactionsData = res.data;
      paginationData = null;
    } else {
      throw Exception('Unexpected response format: ${res.data.runtimeType}');
    }

    print('🔍 Transactions data: $transactionsData');
    print('🔍 Pagination data: $paginationData');

    // ✅ Parser les transactions
    List<Transaction> transactions = [];
    if (transactionsData is List) {
      transactions = transactionsData
          .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    // ✅ Parser la pagination
    Map<String, dynamic> pagination = paginationData is Map
        ? Map<String, dynamic>.from(paginationData)
        : {'hasMore': false, 'currentPage': page, 'totalPages': 1};

    return {
      'transactions': transactions,
      'pagination': pagination,
    };
  }

  /// Récupérer les statistiques de mes transactions
  Future<TransactionStats> getMyStats() async {
    final res = await _api.get('/transactions/my/stats');
    
    print('🔍 Stats response: ${res.data}');

    // ✅ Gérer différentes structures
    dynamic statsData;
    
    if (res.data is Map) {
      if (res.data.containsKey('data')) {
        statsData = res.data['data'];
      } else {
        statsData = res.data;
      }
    } else {
      statsData = res.data;
    }

    return TransactionStats.fromJson(
      statsData is Map ? Map<String, dynamic>.from(statsData) : {},
    );
  }

  /// Récupérer une transaction par son ID
  Future<Transaction> getTransactionById(String id) async {
    final res = await _api.get('/transactions/$id');
    
    print('🔍 Transaction detail response: ${res.data}');

    // ✅ Gérer différentes structures
    dynamic transactionData;
    
    if (res.data is Map) {
      if (res.data.containsKey('data')) {
        transactionData = res.data['data'];
      } else {
        transactionData = res.data;
      }
    } else {
      transactionData = res.data;
    }

    return Transaction.fromJson(
      transactionData is Map ? Map<String, dynamic>.from(transactionData) : {},
    );
  }
} */

import '../models/transaction.dart';
import '../services/api_service.dart';

class TransactionRepository {
  final ApiService _api;

  TransactionRepository(this._api);

  /// Récupérer mes transactions avec pagination et filtres
  Future<Map<String, dynamic>> getMyTransactions({
    int page = 1,
    int limit = 20,
    String? type,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };

    if (type != null) queryParams['type'] = type;
    if (status != null) queryParams['status'] = status;
    if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
    if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

    try {
      final res = await _api.get('/transactions/my', queryParameters: queryParams);

      print('🔍 Full response: ${res.data}');

      // ✅ Structure: {success, message, data: {transactions: [...], statistics: {...}}, pagination: {...}}
      if (res.data is! Map) {
        throw Exception('Expected Map response, got ${res.data.runtimeType}');
      }

      final responseData = res.data as Map<String, dynamic>;

      // ✅ Extraire data (qui contient transactions et statistics)
      final data = responseData['data'] as Map<String, dynamic>? ?? {};
      
      // ✅ Extraire transactions (DANS data.transactions)
      final transactionsData = data['transactions'] as List? ?? [];
      
      // ✅ Extraire pagination
      final paginationData = responseData['pagination'] as Map<String, dynamic>? ?? {};

      print('✅ Transactions count: ${transactionsData.length}');
      print('✅ Pagination: $paginationData');

      return {
        'transactions': transactionsData
            .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
            .toList(),
        'pagination': paginationData,
        'statistics': data['statistics'], // ✅ Garder les stats
      };
    } catch (e) {
      print('❌ Repository error: $e');
      rethrow;
    }
  }

  /// Récupérer les statistiques de mes transactions
  Future<TransactionStats> getMyStats() async {
    try {
      final res = await _api.get('/transactions/my/stats');
      
      print('🔍 Stats response: ${res.data}');

      // ✅ Structure: {success, message, data: {...}}
      final responseData = res.data as Map<String, dynamic>;
      final statsData = responseData['data'] as Map<String, dynamic>? ?? {};

      return TransactionStats.fromJson(statsData);
    } catch (e) {
      print('❌ Stats repository error: $e');
      rethrow;
    }
  }

  /// Récupérer une transaction par son ID
  Future<Transaction> getTransactionById(String id) async {
    try {
      final res = await _api.get('/transactions/$id');
      
      print('🔍 Transaction detail response: ${res.data}');

      // ✅ Structure: {success, message, data: {...}}
      final responseData = res.data as Map<String, dynamic>;
      final transactionData = responseData['data'] as Map<String, dynamic>? ?? {};

      return Transaction.fromJson(transactionData);
    } catch (e) {
      print('❌ Transaction detail repository error: $e');
      rethrow;
    }
  }
}