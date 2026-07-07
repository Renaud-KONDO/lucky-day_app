import 'package:flutter/material.dart';

enum PaymentStatus { pending, processing, completed, failed, cancelled, refunded, expired }
enum PaymentPurpose { wallet_topup, raffle_entry, prize_claim }

class Payment {
  final String id;
  final String userId;
  final double amount;
  final String currency;
  final String? description;
  final String? paymentMethod;
  final String? phoneNumber;
  final PaymentStatus status;
  final PaymentPurpose purpose;
  final String? raffleId;
  final String? transactionId;
  final Map<String, dynamic>? metadata;
  final bool webhookReceived;
  final DateTime? webhookReceivedAt;
  final String? errorMessage;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  Payment({
    required this.id,
    required this.userId,
    required this.amount,
    required this.currency,
    this.description,
    this.paymentMethod,
    this.phoneNumber,
    required this.status,
    required this.purpose,
    this.raffleId,
    this.transactionId,
    this.metadata,
    required this.webhookReceived,
    this.webhookReceivedAt,
    this.errorMessage,
    this.failureReason,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      userId: json['userId'],
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] ?? 'XOF',
      description: json['description'],
      paymentMethod: json['paymentMethod'],
      phoneNumber: json['phoneNumber'],
      status: PaymentStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => PaymentStatus.pending),
      purpose: PaymentPurpose.values.firstWhere((e) => e.name == json['purpose']),
      raffleId: json['raffleId'],
      transactionId: json['transactionId'],
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
      webhookReceived: json['webhookReceived'] ?? false,
      webhookReceivedAt: json['webhookReceivedAt'] != null ? DateTime.parse(json['webhookReceivedAt']) : null,
      errorMessage: json['errorMessage'],
      failureReason: json['failureReason'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'currency': currency,
      'description': description,
      'paymentMethod': paymentMethod,
      'phoneNumber': phoneNumber,
      'status': status.name,
      'purpose': purpose.name,
      'raffleId': raffleId,
      'transactionId': transactionId,
      'metadata': metadata,
      'webhookReceived': webhookReceived,
      'webhookReceivedAt': webhookReceivedAt?.toIso8601String(),
      'errorMessage': errorMessage,
      'failureReason': failureReason,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}