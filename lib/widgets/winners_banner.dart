import 'package:flutter/material.dart';
import 'package:logger/web.dart';
import '../data/models/models.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';

class WinnersBanner extends StatelessWidget {
  final List<Raffle> winners;

  const WinnersBanner({super.key, required this.winners});

  @override
  Widget build(BuildContext context) {
    if (winners.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        gradient: AppTheme.blueGoldGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              const Icon(Icons.emoji_events, color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 8),
              const Text('Derniers Gagnants',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${winners.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          // Liste horizontale
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              itemCount: winners.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _WinnerChip(raffle: winners[i]), 
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerChip extends StatelessWidget {
  final Raffle raffle;
  const _WinnerChip({required this.raffle});

  @override
  Widget build(BuildContext context) {
    final name = raffle.winnerName ?? 'Anonyme';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Avatar
        CircleAvatar(
          radius: 16,
          backgroundColor: AppTheme.accentColor,
          child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(name.length > 10 ? '${name.substring(0, 10)}…' : name,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          Text(
            raffle.cashOptionAvailable && raffle.cashAmount != null
              ? '${raffle.cashAmount!.toStringAsFixed(0)} ${AppStrings.currency}'
              : raffle.product?.name ?? raffle.title,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ]),
      ]),
    );
  }
}
