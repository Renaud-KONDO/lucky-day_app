class AppConstants {
  static const String baseUrl = 'http://10.241.88.6:5000/api/v1';

  // Auth
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authRefreshToken = '/auth/refresh-token';
  static const String authProfile = '/auth/profile';
  static const String authChangePassword = '/auth/change-password';

  // Stores
  static const String stores = '/stores';
  static const String myStores = '/stores/my/stores';
  static const String topStores = '/stores/top';
  static const String storeToggleStatus = '/toggle-status';

  // Products
  static const String products = '/products';
  static const String productsByStore = '/products/store';
  static const String productToggleStatus = '/toggle-status';
  static const String productStock = '/stock';

  // Raffles
  static const String raffles = '/raffles';
  static const String raffleParticipate = '/participate';
  static const String raffleDraw = '/draw';
  static const String raffleClaim = '/claim';
  static const String raffleCancel = '/cancel';
  static const String myRaffles = '/raffles/my/participations';
  static const String myWins = '/raffles/my/wins';
  //static const String  userRaffles = "/user/:userId/created";

  // Categories
  static const String storeCategories = '/store-categories';
  static const String productCategories = '/product-categories';

  // Wallet
  static const String walletBalance = '/wallet/balance';
  static const String walletAddMoney = '/wallet/add-money';

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';

  // Pagination
  static const int pageSize = 20;
  static const int requestTimeout = 30;

  // Raffle probability types
  static const String highProbability = 'high';
  static const String mediumProbability = 'medium';
  static const String lowProbability = 'low';

  // Raffle status
  static const String raffleStatusOpen = 'open';
  static const String raffleStatusFull = 'full';
  static const String raffleStatusDrawn = 'completed';
  static const String raffleStatusClaimed = 'claimed';
  static const String raffleStatusCancelled = 'cancelled';

  // Claim options
  static const String claimCash = 'cash';
  static const String claimDelivery = 'delivery';

  //users
  static const String users = '/users';

  // Username
  static const String checkUsername    = '/auth/check-username';
  static const String suggestUsernames = '/auth/suggest-usernames';

  // Upload
  static const String uploadAvatar         = '/upload/avatar';
  static const String uploadStoreLogo      = '/upload/stores';      // + /{storeId}/logo
  static const String uploadStoreBanner    = '/upload/stores';      // + /{storeId}/banner
  static const String uploadProductImages  = '/upload/products';    // + /{productId}/images
  static const String deleteProductImage   = '/upload/products';

// Notifications
  static const String notificationsRegister   = '/notifications/register';
  static const String notificationsUnregister = '/notifications/unregister';
  static const String myNotifications         = '/my-notifications';
  static const String myNotificationsUnreadCount = '/my-notifications/unread-count';
  static const String myNotificationsMarkRead = '/my-notifications';  // + /{id}/read
  static const String myNotificationsMarkAllRead = '/my-notifications/mark-all-read';
  
}

class AppStrings {
  static const String appName = 'Lucky Day';
  static const String currency = 'XOF';
  static const String slogan = 'Tentez votre chance et gagnez !';

  // Navigation
  static const String home = 'Accueil';
  static const String stores = 'Boutiques';
  static const String myRaffles = 'Mes Tombolas';
  static const String profile = 'Profil';

  // Auth
  static const String login = 'Connexion';
  static const String register = 'Inscription';
  static const String logout = 'Déconnexion';
  static const String email = 'Email';
  static const String password = 'Mot de passe';
  static const String fullName = 'Nom complet';
  static const String phone = 'Téléphone';

  // Raffles
  static const String raffles = 'Tombolas';
  static const String highProbabilityLabel = 'Forte Chance';
  static const String mediumProbabilityLabel = 'Chance Moyenne';
  static const String lowProbabilityLabel = 'Petite Chance';
  static const String participate = 'Participer';
  static const String entryPrice = 'Prix d\'entrée';
  static const String participants = 'Participants';

  // Wallet
  static const String wallet = 'Portefeuille';
  static const String balance = 'Solde';

  }