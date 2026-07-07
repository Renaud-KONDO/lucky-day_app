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

  /// ✅ Mettre à jour le compteur localement (depuis SSE)
  void updateUnreadCountLocally(int count) {
    _unreadCount = count;
    notifyListeners();
    print('✅ Unread count updated locally: $count');
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}