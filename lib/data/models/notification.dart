class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id:        json['id'] ?? json['_id'] ?? '',
    type:      json['type'] ?? '',
    title:     json['title'] ?? '',
    message:   json['message'] ?? '',
    isRead:    json['isRead'] ?? false,
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    data:      json['data'],
  );
}