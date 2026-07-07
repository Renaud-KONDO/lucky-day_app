import 'package:flutter/foundation.dart';
import '../data/repositories/payment_repository.dart';

enum TopupState { idle, loading, success, error }

class PaymentProvider with ChangeNotifier {
  final PaymentRepository _repo;

  TopupState _state = TopupState.idle;
  String? _errorMessage;
  String? _paymentUrl; // FedaPay redirect URL for not push ussd payments

  PaymentProvider(this._repo);

  TopupState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get paymentUrl => _paymentUrl;
  bool get isLoading => _state == TopupState.loading;

  Future<bool> initiateTopup({
    required double amount,
    String? phoneNumber,
    String? mode,
  }) async {
    _state = TopupState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repo.initiatealletTopup(
        amount: amount,
        phoneNumber: phoneNumber,
        mode: mode,
      );
      _paymentUrl = result['data']?['paymentUrl'];
      _state = TopupState.success;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _state = TopupState.error;
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _state = TopupState.idle;
    _errorMessage = null;
    _paymentUrl = null;
    notifyListeners();
  }
}