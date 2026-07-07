import '../models/payment.dart';
import '../services/api_service.dart';
import '../../core/constants/app_constants.dart';

class PaymentRepository {
  final ApiService _api;
  PaymentRepository(this._api);

  /* Future<void> initiateWalletTopup({
    required double amount,
    String? phoneNumber,
  }) async {
    final body = {
      'amount': amount,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    };
    final res = await _api.post(AppConstants.walletTopup, data : body);
    //return Payment.fromJson(res.data as Map<String, dynamic>);
  } */

  Future<Map<String, dynamic>> initiateWalletTopup({
    required double amount,
    String? phoneNumber,
    String? mode,
  }) async {
    print('PaymentRepository: initiateWalletTopup called with amount=$amount, phoneNumber=$phoneNumber, mode=$mode');
    final body = {
      'amount': amount,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (mode != null) 'mode': mode,
    };
    final res = await _api.post(AppConstants.walletTopup, data : body);
    return res.data as Map<String, dynamic>;
  }
}