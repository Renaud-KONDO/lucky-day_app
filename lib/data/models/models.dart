import '../../helpers/utils.dart';

// ─── Store ────────────────────────────────────────────────────────────────────
class Store {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? address;
  final bool isActive;
  final int raffleCount;
  final String? ownerId;
  final String? categoryId;       
  final String? categoryName;    


  Store({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.address,
    this.isActive = true,
    this.raffleCount = 0,
    this.ownerId,
    this.categoryId,              
    this.categoryName,            
  });

  factory Store.fromJson(Map<String, dynamic> json) => Store(
    id: json['id'] ?? json['_id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'],
    logoUrl: json['logoUrl'],
    address: json['address'],
    isActive: json['isActive'] ?? true,
    raffleCount: json['raffleCount'] ?? json['_count']?['raffles'] ?? 0,
    ownerId:     json['ownerId'],
    categoryId:   json['categoryId'],                        
    categoryName: json['category']?['name'],                 
  );
}

// ─── Product ──────────────────────────────────────────────────────────────────
class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final List<String> imageUrls;
  final String? storeId;
  final bool isActive;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrls = const [],
    this.storeId,
    this.isActive = true,
  });

  String? get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] ?? json['_id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'],
    price: AppUtils.parseDouble(json['price'] ?? 0),
    imageUrls: json['imageUrls'] != null
        ? List<String>.from(json['imageUrls'])
        : [],
    storeId: json['storeId'],
    isActive: json['isActive'] ?? true,
  );



/*   Map<String, dynamic> toJson() => {
    'id': id,
    'storeId': storeId,
    'name': name,
    'description': description,
    'price': price,
    'imageUrls': imageUrls,
    'isActive': isActive,
  };
 */
}

// ─── Raffle ───────────────────────────────────────────────────────────────────
class Raffle {
  final String id;
  final String title;
  final String? description;
  final String raffleType;
  final String probabilityType;
  final double entryPrice;
  final int maxParticipants;
  final int currentParticipants;
  final String status;
  final bool cashOptionAvailable;
  final double? cashAmount;
  final String? winnerId;
  final String? winnerName;
  final String? imageUrl;
  final Product? product;
  final String storeId;
  final DateTime? drawDate;
  final DateTime createdAt;
  final String? productCategoryId;    
  final String? productCategoryName;  
  final bool autoDrawEnabled;
  final String? autoDrawType;            // 'instant' ou 'scheduled'
  final DateTime? autoDrawAt;            // pour scheduled
  final int? autoDrawDelayMinutes;       // pour instant
  final DateTime? autoDrawTriggeredAt;

  Raffle({
    required this.id,
    required this.title,
    this.description,
    this.raffleType = 'product',
    required this.probabilityType,
    required this.entryPrice,
    required this.maxParticipants,
    this.currentParticipants = 0,
    this.status = 'open',
    this.cashOptionAvailable = false,
    this.cashAmount,
    this.winnerId,
    this.winnerName,
    this.imageUrl,
    this.product,
    required this.storeId,
    this.drawDate,
    required this.createdAt,
    this.productCategoryId,           
    this.productCategoryName, 
    this.autoDrawEnabled = false,
    this.autoDrawType,
    this.autoDrawAt,
    this.autoDrawDelayMinutes,
    this.autoDrawTriggeredAt,        
  });

  double get fillPercentage =>
      maxParticipants > 0 ? (currentParticipants / maxParticipants) : 0.0;

  bool get isFull => currentParticipants >= maxParticipants;
  bool get canParticipate => status == 'open' && !isFull;
  bool get isDrawn => status == 'drawn' || status == 'claimed';

  factory Raffle.fromJson(Map<String, dynamic> json) => Raffle(
    id: json['id'] ?? json['_id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'],
    raffleType: json['raffleType'] ?? 'product',
    probabilityType: json['probabilityType'] ?? 'medium',
    entryPrice: AppUtils.parseDouble(json['entryPrice'] ?? 0),
    maxParticipants: json['maxParticipants'] ?? 10,
    currentParticipants: json['currentParticipants'] ?? 0,
    status: json['status'] ?? 'open',
    cashOptionAvailable: json['cashOptionAvailable'] ?? false,
    cashAmount: json['cashAmount'] != null
        ? AppUtils.parseDouble(json['cashAmount'])
        : null,
    winnerId: json['winnerId'],
    winnerName:json['winner']?['fullName'] ?? json['winnerName'],
    imageUrl: json['imageUrl'],
    product: json['product'] != null
        ? Product.fromJson(json['product'])
        : null,
    storeId: json['storeId'] ?? '',
    drawDate: json['drawDate'] != null
        ? DateTime.tryParse(json['drawDate'])
        : null,
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    productCategoryId:   json['product']?['categoryId'] ?? json['productCategoryId'],
    productCategoryName: json['product']?['category']?['name'] ?? json['productCategoryName'],
    autoDrawEnabled:      json['autoDrawEnabled'] ?? false,
    autoDrawType:         json['autoDrawType'],
    autoDrawAt:           json['autoDrawAt'] != null ? DateTime.tryParse(json['autoDrawAt']) : null,
    autoDrawDelayMinutes: json['autoDrawDelayMinutes'],
    autoDrawTriggeredAt:  json['autoDrawTriggeredAt'] != null ? DateTime.tryParse(json['autoDrawTriggeredAt']) : null,

  );

  // Ajoute cette méthode à la fin de ta classe
  /* Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'raffleType': raffleType,
    'probabilityType': probabilityType,
    'entryPrice': entryPrice,
    'maxParticipants': maxParticipants,
    'currentParticipants': currentParticipants,
    'status': status,
    'cashOptionAvailable': cashOptionAvailable,
    'cashAmount': cashAmount,
    'winnerId': winnerId,
    'winnerName': winnerName,
    'imageUrl': imageUrl,
    'product': product?.toJson(),  // Assure-toi que Product a aussi une méthode toJson()
    'storeId': storeId,
    'drawDate': drawDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'productCategoryId': productCategoryId,
    'productCategoryName': productCategoryName,
    'autoDrawEnabled': autoDrawEnabled,
    'autoDrawType': autoDrawType,
    'autoDrawAt': autoDrawAt?.toIso8601String(),
    'autoDrawDelayMinutes': autoDrawDelayMinutes,
    'autoDrawTriggeredAt': autoDrawTriggeredAt?.toIso8601String(),
  }; */
}


class Category {
  final String id;
  final String name;
  final String? icon;
  final String? description;

  Category({required this.id, required this.name, this.icon, this.description});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id:          json['id'] ?? json['_id'] ?? '',
    name:        json['name'] ?? '',
    icon:        json['icon'],
    description: json['description'],
  );
}