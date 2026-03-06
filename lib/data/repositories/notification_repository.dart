import 'package:dio/dio.dart';
import '../models/notification.dart';
import '../services/api_service.dart';

class NotificationRepository {
  final ApiService _api;

  NotificationRepository(this._api);

  /// Get notifications
  Future<List<AppNotification>> getNotifications({bool unreadOnly = false}) async {
    try {
      final response = await _api.get(
        '/my-notifications',
        queryParameters: {
          if (unreadOnly) 'unreadOnly': 'true',
          'limit': 50,
        },
      );

      final data = response.data['data'];
      final notificationsList = data['notifications'] as List;
      
      return notificationsList
          .map((json) => AppNotification.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    try {
      final response = await _api.get('/my-notifications/unread-count');
      return response.data['data']['unreadCount'] as int;
    } catch (e) {
      throw Exception('Failed to fetch unread count: $e');
    }
  }

  /// Mark as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _api.patch('/my-notifications/$notificationId/read');
    } catch (e) {
      throw Exception('Failed to mark as read: $e');
    }
  }

  /// Mark all as read
  Future<void> markAllAsRead() async {
    try {
      await _api.patch('/my-notifications/mark-all-read');
    } catch (e) {
      throw Exception('Failed to mark all as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _api.delete('/my-notifications/$notificationId');
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }
}