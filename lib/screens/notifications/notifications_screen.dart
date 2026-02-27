import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/notification_provider.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (_, prov, __) => prov.unreadCount > 0
              ? TextButton(
                  onPressed: () => prov.markAllAsRead(),
                  child: const Text('Tout marquer lu',
                    style: TextStyle(color: Colors.white)),
                )
              : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (_, prov, __) {
          if (prov.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (prov.notifications.isEmpty) {
            return const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: AppTheme.textSecondary),
                SizedBox(height: 12),
                Text('Aucune notification', style: AppTheme.bodyText),
              ],
            ));
          }
          return RefreshIndicator(
            onRefresh: () => prov.fetchNotifications(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: prov.notifications.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final notif = prov.notifications[i];
                return Dismissible(
                  key: Key(notif.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => prov.deleteNotification(notif.id),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: notif.isRead
                          ? Colors.grey.withOpacity(0.2)
                          : AppTheme.primaryColor.withOpacity(0.2),
                      child: Icon(_getIcon(notif.type),
                        color: notif.isRead ? Colors.grey : AppTheme.primaryColor),
                    ),
                    title: Text(notif.title,
                      style: TextStyle(
                        fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                        color: AppTheme.textPrimary)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(notif.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(timeago.format(notif.createdAt, locale: 'fr'),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                    trailing: !notif.isRead
                      ? Container(
                          width: 10, height: 10,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                    onTap: () {
                      if (!notif.isRead) {
                        prov.markAsRead(notif.id);
                      }
                      // TODO: Navigate based on notif.data
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'participation':     return Icons.confirmation_number;
      case 'winner':            return Icons.emoji_events;
      case 'raffle_completed':  return Icons.cancel;
      case 'raffle_cancelled':  return Icons.cancel;
      case 'wallet_credit':     return Icons.account_balance_wallet;
      case 'almost_full':       return Icons.warning;
      default:                  return Icons.notifications;
    }
  }
}