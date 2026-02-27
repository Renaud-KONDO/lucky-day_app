import '../../helpers/utils.dart';

class User {
  final String id;
  final String fullName;
  final String email;
  final String username;
  final String? phone;
  final String? avatar;
  final String role; // gambler, store_owner, admin, super_admin
  final double balance;
  final bool isVerified;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.username,
    this.phone,
    this.avatar,
    this.role = 'gambler',
    this.balance = 0.0,
    this.isVerified = false,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isStoreOwner => role == 'store_owner' || role == 'admin' || role == 'super_admin';
  bool get isAdmin => role == 'admin' || role == 'super_admin';

  String get roleLabel {
    switch (role) {
      case 'store_owner': return 'business';
      case 'admin':       return 'Administrateur';
      case 'super_admin': return 'Super Administrateur';
      default:            return 'Joueur';
    }
  }

  factory User.fromJson(Map<String, dynamic> json) {
    
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      fullName: json['fullName'] ?? json['name'] ?? '',
      email: json['email'] ?? '',
      username:    json['username'] ?? '', 
      phone: json['phone'],
      avatar:      json['avatarUrl'] ?? json['avatar_url'] ?? json['avatar'],
      role:        json['role'] ?? 'gambler',                                
      balance: AppUtils.parseDouble(json['wallet']?['balance'] ?? json['balance'] ?? 0),
      isVerified:  json['isVerified'] ?? false,
      isActive:    json['isActive'] ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'username': username,        
    'phone': phone,
    'avatarUrl': avatar,             
    'role': role,                 
    'balance': balance,
    'isVerified': isVerified,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
  };

  User copyWith({String? fullName, String? phone, String? avatar, String? username}) => User(
    id: id, email: email, role: role, balance: balance,
    isVerified: isVerified, isActive: isActive, createdAt: createdAt,
    fullName: fullName ?? this.fullName,
    username: username ?? this.username,
    phone: phone ?? this.phone,
    avatar: avatar ?? this.avatar,
  );
}