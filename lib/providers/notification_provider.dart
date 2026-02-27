import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../data/models/notification.dart';
import '../data/services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService _api;
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _loading = false;

  NotificationProvider(this._api);

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _loading;

  Future<void> fetchNotifications({bool unreadOnly = false}) async {
    _loading = true; notifyListeners();
    try {
      final res = await _api.get(
        AppConstants.myNotifications,
        queryParameters: unreadOnly ? {'unreadOnly': true} : null,
      );
      final list = res.data['data']['notifications'] as List;
      _notifications = list.map((e) => AppNotification.fromJson(e)).toList();
      _unreadCount = res.data['data']['unreadCount'] ?? 0;
    } catch (_) {}
    _loading = false; notifyListeners();
  }

  Future<void> fetchUnreadCount() async {
    try {
      final res = await _api.get(AppConstants.myNotificationsUnreadCount);
      _unreadCount = res.data['data']['unreadCount'] ?? 0;
      notifyListeners();
    } catch (e) {
      print('❌ Error fetching unread count: $e');
      _unreadCount = 0;  
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _api.patch('${AppConstants.myNotificationsMarkRead}/$notificationId/read');
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1) {
        _notifications[idx] = AppNotification(
          id: _notifications[idx].id,
          type: _notifications[idx].type,
          title: _notifications[idx].title,
          message: _notifications[idx].message,
          isRead: true,
          createdAt: _notifications[idx].createdAt,
          data: _notifications[idx].data,
        );
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _api.patch(AppConstants.myNotificationsMarkAllRead);
      _unreadCount = 0;
      for (int i = 0; i < _notifications.length; i++) {
        _notifications[i] = AppNotification(
          id: _notifications[i].id,
          type: _notifications[i].type,
          title: _notifications[i].title,
          message: _notifications[i].message,
          isRead: true,
          createdAt: _notifications[i].createdAt,
          data: _notifications[i].data,
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _api.delete('${AppConstants.myNotifications}/$notificationId');
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    } catch (_) {}
  }

}