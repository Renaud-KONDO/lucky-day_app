import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';

enum PaymentDialogState { loading, success, error }

class PaymentStatusDialog extends StatefulWidget {
  final PaymentDialogState state;
  final String? message;

  const PaymentStatusDialog({
    super.key,
    required this.state,
    this.message,
  });

  @override
  State<PaymentStatusDialog> createState() => _PaymentStatusDialogState();
}

class _PaymentStatusDialogState extends State<PaymentStatusDialog> {
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    if (widget.state == PaymentDialogState.success) {
      _playSuccessSound();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAnimation(),
            const SizedBox(height: 16),
            _buildMessage(),
            const SizedBox(height: 8),
            if (widget.state != PaymentDialogState.loading)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimation() {
    switch (widget.state) {
      case PaymentDialogState.loading:
        return Lottie.asset(
          'lib/assets/loaders/payment_loading.json',
          width: 150,
          height: 150,
          repeat: true,
        );
      case PaymentDialogState.success:
        return Lottie.asset(
          'lib/assets/loaders/payment_success.json',
          width: 150,
          height: 150,
          repeat: false,
        );
      case PaymentDialogState.error:
        return Lottie.asset(
          'lib/assets/loaders/payment_error.json',
          width: 150,
          height: 150,
          repeat: false,
        );
    }
  }

  Widget _buildMessage() {
    switch (widget.state) {
      case PaymentDialogState.loading:
        return const Text(
          'Traitement en cours...\nVeuillez patienter.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey),
        );
      case PaymentDialogState.success:
        return Text(
          widget.message ?? '🎉 Rechargement effectué avec succès !',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        );
      case PaymentDialogState.error:
        return Text(
          widget.message ?? 'Une erreur est survenue. Veuillez réessayer.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.red,
          ),
        );
    }
  }

  Future<void> _playSuccessSound() async {
    try {
      //await _player.play(AssetSource('lib/assets/sounds/payment_success.mp3'));
      final data = await rootBundle.load('lib/assets/sounds/payment_success.mp3');
      await _player.play(BytesSource(data.buffer.asUint8List()));
    } catch (e) {
      // fail silently — sound is not critical
      debugPrint('Sound error: $e');
    }
  }
}