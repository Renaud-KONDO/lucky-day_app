import 'package:flutter/material.dart';
import '../data/models/models.dart';
import '../core/theme/app_theme.dart';

class StoreCard extends StatelessWidget {
  final Store store;
  final VoidCallback onTap;

  const StoreCard({super.key, required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Logo
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFEFF6FF),
                ),
                child: store.logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(store.logoUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.store, color: AppTheme.primaryColor)),
                      )
                    : const Icon(Icons.store, color: AppTheme.primaryColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    if (store.description != null) ...[
                      const SizedBox(height: 4),
                      Text(store.description!, style: AppTheme.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: store.isActive ? AppTheme.secondaryColor : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          store.isActive ? 'Actif' : 'Inactif',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: store.isActive ? AppTheme.secondaryColor : Colors.grey,
                          ),
                        ),
                        if (store.raffleCount > 0) ...[
                          const Spacer(),
                          const Icon(Icons.confirmation_number_outlined, size: 14, color: AppTheme.primaryColor),
                          const SizedBox(width: 4),
                          Text('${store.raffleCount} tombola${store.raffleCount > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
