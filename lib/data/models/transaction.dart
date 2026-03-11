import 'package:flutter/material.dart';

class Transaction {
  final String id;
  final String userId;
  final String type; // raffle_entry, wallet_credit, wallet_debit, refunded, prize
  final double amount;
  final String currency;
  final String status; // pending, completed, failed, refunded
  final String? paymentMethod;
  final String? paymentProviderId;
  final String? raffleId;
  final String? description;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    this.paymentMethod,
    this.paymentProviderId,
    this.raffleId,
    this.description,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: json['type'] as String,
      amount: _parseAmount(json['amount']),
      currency: json['currency'] as String? ?? 'XOF',
      status: json['status'] as String,
      paymentMethod: json['paymentMethod'] as String?,
      paymentProviderId: json['paymentProviderId'] as String?,
      raffleId: json['raffleId'] as String?,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static double _parseAmount(dynamic amount) {
    if (amount is num) return amount.toDouble();
    if (amount is String) return double.tryParse(amount) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'amount': amount,
      'currency': currency,
      'status': status,
      'paymentMethod': paymentMethod,
      'paymentProviderId': paymentProviderId,
      'raffleId': raffleId,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Helpers pour le type
  bool get isDeposit => type == 'wallet_credit';
  bool get isWithdrawal => type == 'wallet_debit';
  bool get isRaffleEntry => type == 'raffle_entry';
  bool get isCancelledRaffleRefund => type == 'raffle_refund';
  bool get isPrize => type == 'prize';

  // Helpers pour le statut
  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isRefunded => status == 'refunded';

  // Est-ce un crédit (entrée d'argent) ?
  bool get isCredit => type == 'wallet_credit' || type == 'prize';
  
  // Est-ce un débit (sortie d'argent) ?
  bool get isDebit => type == 'raffle_entry' || type == 'wallet_debit';

  String get typeLabel {
    switch (type) {
      case 'wallet_credit':
        return 'Dépôt';
      case 'wallet_debit':
        return 'Retrait';
      case 'raffle_entry':
        return 'Participation tombola';
      case 'raffle_refund':
        return 'Remboursement pour annulation de tombola';
      case 'prize':
        return 'Réclamation de prix';
      default:
        return type;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'completed':
        return 'Succès';
      case 'failed':
        return 'Échoué';
      case 'refunded':
        return 'Remboursé';
      default:
        return status;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'wallet_credit':
        return Icons.add_circle_outline;
      case 'wallet_debit':
        return Icons.remove_circle_outline;
      case 'raffle_entry':
        return Icons.confirmation_number;
      case 'raffle_refund':
        return Icons.confirmation_number;
      case 'prize':
        return Icons.emoji_events;
      default:
        return Icons.sync_alt;
    }
  }

  Color get typeColor {
    switch (type) {
      case 'wallet_credit':
        return Colors.green;
      case 'wallet_debit':
        return Colors.red;
      case 'raffle_entry':
      case 'raffle_refund':
        return Colors.blue;
      case 'prize':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}

// Stats model
/* class TransactionStats {
  final double totalCredits;
  final double totalDebits;
  final double totalParticipations;
  final int totalTransactions;
  final Map<String, int> transactionsByType;
  final Map<String, int> transactionsByStatus;

  TransactionStats({
    required this.totalCredits,
    required this.totalDebits,
    required this.totalParticipations,
    required this.totalTransactions,
    required this.transactionsByType,
    required this.transactionsByStatus,
  });

  factory TransactionStats.fromJson(Map<String, dynamic> json) {
    return TransactionStats(
      totalCredits: _parseDouble(json['totalCredits']),
      totalDebits: _parseDouble(json['totalDebits']),
      totalParticipations: _parseDouble(json['totalParticipations']),
      totalTransactions: json['totalTransactions'] as int? ?? 0,
      transactionsByType: _parseMap(json['transactionsByType']),
      transactionsByStatus: _parseMap(json['transactionsByStatus']),
    );
  }
  

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static Map<String, int> _parseMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(
        key.toString(),
        val is int ? val : int.tryParse(val.toString()) ?? 0,
      ));
    }
    return {};
  }

  double get balance => totalCredits - totalDebits;
} */
class TransactionStats {
  final int totalTransactions;
  final int completedTransactions;
  final int pendingTransactions;
  final List<Map<String, dynamic>> recentTransactions;
  final List<Map<String, dynamic>> monthlyStats;

  TransactionStats({
    required this.totalTransactions,
    required this.completedTransactions,
    required this.pendingTransactions,
    required this.recentTransactions,
    required this.monthlyStats,
  });

  factory TransactionStats.fromJson(Map<String, dynamic> json) {
    return TransactionStats(
      totalTransactions: json['totalTransactions'] as int? ?? 0,
      completedTransactions: json['completedTransactions'] as int? ?? 0,
      pendingTransactions: json['pendingTransactions'] as int? ?? 0,
      recentTransactions: (json['recentTransactions'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList() ?? [],
      monthlyStats: (json['monthlyStats'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList() ?? [],
    );
  }

  // ✅ Calculer totalCredits depuis monthlyStats
  double get totalCredits {
    return monthlyStats
        .where((stat) => ['deposit', 'prize'].contains(stat['type']))
        .fold(0.0, (sum, stat) => sum + _parseDouble(stat['total']));
  }

  // ✅ Calculer totalDebits depuis monthlyStats
  double get totalDebits {
    return monthlyStats
        .where((stat) => ['raffle_entry', 'withdrawal'].contains(stat['type']))
        .fold(0.0, (sum, stat) => sum + _parseDouble(stat['total']));
  }

  double get balance => totalCredits - totalDebits;

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  
}