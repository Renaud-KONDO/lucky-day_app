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
  final bool isParticipating;
  final VoidCallback? onParticipate;
  

  const RaffleCard({super.key, required this.raffle,this.onParticipate, required this.onTap, this.isWon = false, this.label, this.labelColor,this.isParticipating = false,});

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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                 // Badge personnalisé (PERDU, ANNULÉ, etc.)
                  if (label != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: labelColor?.withOpacity(0.9) ?? Colors.grey,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          label!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
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
                      const Icon(Icons.star, color: AppTheme.textPrimary, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'prix d\'entrée : ',
                        style: const TextStyle(fontSize: 15,fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      Text(
                        '${raffle.entryPrice.toStringAsFixed(0)} ${AppStrings.currency}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 61, 126, 63)),
                      ),
                      const Spacer(),
                      Icon(
                        raffle.isFull ? Icons.lock : Icons.check_circle,
                        size: 14,
                        color: raffle.isFull ? Colors.red : Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        raffle.isFull ? 'Complet' : 'Disponible',
                        style: TextStyle(fontSize: 12,fontWeight: FontWeight.bold, color: raffle.isFull ? Colors.red : Colors.green[700]),
                      ),
                    ],
                  ),
                  /* const SizedBox(height: 10),
                  // Barre de progression
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: raffle.fillPercentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(probColor),
                      minHeight: 6,
                    ),
                  ), */
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
                  if (raffle.autoDrawEnabled) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.auto_mode, size: 14, color: AppTheme.primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          raffle.autoDrawType == 'instant'
                              ? 'Tirage auto après remplissage'
                              : raffle.autoDrawType == 'scheduled' && raffle.autoDrawAt != null
                                  ? 'Tirage le ${raffle.autoDrawAt!.day}/${raffle.autoDrawAt!.month} à ${raffle.autoDrawAt!.hour}h${raffle.autoDrawAt!.minute.toString().padLeft(2, '0')}'
                                  : 'Tirage automatique',
                          style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w500),
                        ),
                      ]),
                    ),
                  ], 
                  if (!raffle.autoDrawEnabled) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.touch_app, size: 14, color: AppTheme.primaryColor),
                        const SizedBox(width: 6),
                        Text('Tirage sur autorisation de l\'organisateur',
                          style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w500),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Bouton participation
                  /* if (raffle.canParticipate)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.confirmation_number, size: 18),
                        label: Text('Participer • ${raffle.entryPrice.toStringAsFixed(0)} ${AppStrings.currency}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.getProbabilityColor(raffle.probabilityType),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    )
                  else if (raffle.isFull)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock, size: 16, color: Colors.grey),
                          SizedBox(width: 6),
                          Text('Complet', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ), */

                  if (isParticipating && raffle.status == 'open')
                    // Badge "Vous participez"
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.1),
                            AppTheme.primaryColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              size: 20, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            '🍀 Vous participez · Bonne chance !',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )else if(isParticipating && raffle.status == 'completed' && isWon)
                    // Badge "GAGNÉ"
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.1),
                            AppTheme.primaryColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events,
                              size: 20, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Vous êtes le champion de cette tombola ! Félicitations ✨',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )else if(isParticipating && raffle.status == 'completed' && !isWon)
                    // Badge "GAGNÉ"
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.1),
                            AppTheme.primaryColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events,
                              size: 20, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Tombola terminéé ! Ne perdez pas espoir. Tentez votre chance sur d\'autres tombola 🍀',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )else if (raffle.canParticipate && !isWon)
                    // Bouton participer (seulement si pas encore participant)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onParticipate,
                        icon: const Icon(Icons.confirmation_number, size: 18),
                        label: const Text('Participer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.getProbabilityColor(raffle.probabilityType),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
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
