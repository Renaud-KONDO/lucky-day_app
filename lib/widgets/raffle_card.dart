import 'package:flutter/material.dart';
import '../data/models/models.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';

class RaffleCard extends StatelessWidget {
  final Raffle raffle;
  final VoidCallback onTap;
  final bool isWon;
  final String? label;
  final Color? labelColor;
  

  const RaffleCard({super.key, required this.raffle, required this.onTap, this.isWon = false, this.label, this.labelColor});

  String _probabilityLabel(String type) {
    switch (type) {
      case 'high':   return 'FORTE CHANCE';
      case 'medium': return 'CHANCE MOYENNE';
      case 'low':    return 'PETITE CHANCE';
      default:       return type.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final probColor = AppTheme.getProbabilityColor(raffle.probabilityType);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  color: const Color(0xFFEFF6FF),
                  child: raffle.product?.imageUrl != null
                      ? Image.network(raffle.product!.imageUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 48, color: AppTheme.textSecondary))
                      : const Icon(Icons.card_giftcard, size: 64, color: AppTheme.primaryColor),
                ),
                // Badge probabilité
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: raffle.probabilityType == 'high' ? null : probColor,
                      gradient: raffle.probabilityType == 'high' ? AppTheme.goldGradient : null,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_probabilityLabel(raffle.probabilityType),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // Badge GAGNÉ
                if (isWon)
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('GAGNÉ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                if (label != null && !isWon)
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: labelColor ?? Colors.grey,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(label!,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(raffle.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // Prix
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppTheme.secondaryColor, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${raffle.entryPrice.toStringAsFixed(0)} ${AppStrings.currency}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                      ),
                      const Spacer(),
                      Icon(
                        raffle.isFull ? Icons.lock : Icons.check_circle,
                        size: 14,
                        color: raffle.isFull ? Colors.red : AppTheme.secondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        raffle.isFull ? 'Complet' : 'Disponible',
                        style: TextStyle(fontSize: 12, color: raffle.isFull ? Colors.red : AppTheme.secondaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Barre de progression
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: raffle.fillPercentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(probColor),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Barre de progression
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: raffle.fillPercentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(probColor),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${raffle.currentParticipants} / ${raffle.maxParticipants} participants',
                    style: AppTheme.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
