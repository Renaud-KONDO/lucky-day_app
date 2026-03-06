/* import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../core/constants/app_constants.dart';
import '../data/models/notification.dart';
import '../data/repositories/notification_repository.dart';
import '../data/services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService _api;
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _loading = false;
  String? _error;
  final NotificationRepository _repo;

  var logger = Logger();

  NotificationProvider(this._api, this._repo);

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _loading;
  String? get errorMessage => _error;

  List<AppNotification> get unreadNotifications => 
      _notifications.where((n) => !n.isRead).toList();

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
    } catch (e) {
      _error = 'Erreur de chargement des notifications';
      logger.e('Error fetching notifications: $e');
      _loading = false; notifyListeners();
    }
    //_loading = false; notifyListeners();
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

  Future<bool> markAsRead(String notificationId) async {
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
      return true;
    } catch (e) {
      logger.e('Error marking notification as read: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
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
      return true;
    } catch (e) {
      logger.e('Error marking all notifications as read: $e');
      return false;
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _api.delete('${AppConstants.myNotifications}/$notificationId');
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
      return true;
    } catch (e) {
      logger.e('Error deleting notification: $e');
      return false;
    }
  }

} */

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../data/models/notification.dart';
import '../data/repositories/notification_repository.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationRepository _repo;
  
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _loading = false;
  String? _error;

  var logger = Logger();

  // ✅ Un seul paramètre suffit
  NotificationProvider(this._repo);

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _loading;
  String? get errorMessage => _error;

  List<AppNotification> get unreadNotifications => 
      _notifications.where((n) => !n.isRead).toList();

  /// Fetch notifications
  Future<void> fetchNotifications({bool unreadOnly = false}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    
    try {
      _notifications = await _repo.getNotifications(unreadOnly: unreadOnly);
      await fetchUnreadCount(); // Update badge count
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur de chargement des notifications';
      logger.e('Error fetching notifications: $e');
      _loading = false;
      notifyListeners();
    }
  }

  /// Fetch unread count only (for badge)
  Future<void> fetchUnreadCount() async {
    try {
      _unreadCount = await _repo.getUnreadCount();
      notifyListeners();
    } catch (e) {
      print('❌ Error fetching unread count: $e');
      _unreadCount = 0;
      if (_notifications.isNotEmpty) {
        notifyListeners();
      }
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _repo.markAsRead(notificationId);
      
      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = AppNotification(
          id: _notifications[index].id,
          type: _notifications[index].type,
          title: _notifications[index].title,
          message: _notifications[index].message,
          isRead: true,
          createdAt: _notifications[index].createdAt,
          data: _notifications[index].data,
        );
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      logger.e('Error marking as read: $e');
      return false;
    }
  }

  /// Mark all as read
  Future<bool> markAllAsRead() async {
    try {
      await _repo.markAllAsRead();
      
      // Update local state
      _notifications = _notifications.map((n) => AppNotification(
        id: n.id,
        type: n.type,
        title: n.title,
        message: n.message,
        isRead: true,
        createdAt: n.createdAt,
        data: n.data,
      )).toList();
      _unreadCount = 0;
      notifyListeners();
      
      return true;
    } catch (e) {
      logger.e('Error marking all as read: $e');
      return false;
    }
  }

  /// Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _repo.deleteNotification(notificationId);
      
      // Update local state
      final notification = _notifications.firstWhere((n) => n.id == notificationId);
      if (!notification.isRead) {
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
      }
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
      
      return true;
    } catch (e) {
      logger.e('Error deleting notification: $e');
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}