// path: frontend/mobile/lib/core/constants/app_constants.dart

/// Centralisation des constantes globales et des endpoints d'API 
/// pour l'application POS Multi-Tenant "DabaFoodStall".
class AppConstants {
  // ===========================================================================
  // 1. CONFIGURATION RÉSEAU & BACKEND NODE.JS
  // ===========================================================================
  
  /// Base URL de l'API Node.js.
  /// NOTE TECHNIQUE ANDROID : L'adresse 'http://10.0.2.2:3000' est un alias 
  /// physique propre à l'émulateur Android pour cibler le 'localhost' de votre PC.
  /// Si vous testez sur un vrai smartphone en USB, remplacez par l'IP locale 
  /// de votre machine (ex: 'http://192.168.1.15:3000') ou votre URL Cloud.
  static const String apiBaseUrl = "http://10.0.2.2:5000";

  // --- Endpoints d'Authentification ---
  static const String loginEndpoint = "$apiBaseUrl/auth/login";
  static const String logoutEndpoint = "$apiBaseUrl/auth/logout";

  // --- Endpoints de Synchronisation (Offline-First) ---
  static const String syncDataEndpoint = "$apiBaseUrl/sync";
  static const String fetchCatalogEndpoint = "$apiBaseUrl/products/catalog";
  
  /// 🔑 ENDPOINT POUR LA RÉCEPTION DES CLÔTURES Z (RAPPORTS FIN DE JOURNÉE)
  /// Aligné sur l'architecture réseau dynamique et routé vers le contrôleur d'ingestion.
  static const String uploadSessionEndpoint = "$apiBaseUrl/api/v1/sync/upload-session"; 
  
  // ===========================================================================
  // 2. CONFIGURATION MULTI-TENANT (TEST TERRAIN)
  // ===========================================================================
  
  /// Identifiant par défaut du Tenant (l'entreprise propriétaire du stand).
  /// En production, cette valeur sera extraite dynamiquement du jeton JWT 
  /// lors de l'authentification et stockée de manière sécurisée.
  static const int defaultTenantId = 1;

  // ===========================================================================
  // 3. SEUILS ET PARAMÈTRES OPÉRATIONNELS HORS-LIGNE
  // ===========================================================================
  
  /// Intervalle de temps (en minutes) entre chaque tentative automatique 
  /// de synchronisation des paquets locaux vers le serveur Cloud.
  static const int syncIntervalMinutes = 15;

  /// Nombre maximal de jours d'historique de ventes conservés en local 
  /// dans le SQLite du smartphone après une synchronisation réussie (Règle de purge).
  static const int localHistoryRetentionDays = 7;

  /// Timeout physique (en secondes) appliqué à toutes les requêtes HTTP 
  /// réseau avant de basculer automatiquement l'expérience UI en mode dégradé (Offline).
  static const int networkTimeoutSeconds = 5;

  // ===========================================================================
  // 4. CONFIGURATION COMPTABLE & MATÉRIEL
  // ===========================================================================
  
  /// Devise par défaut utilisée pour l'affichage des prix et les calculs de rendus.
  static const String currencySymbol = "FCFA";

  /// Largeur physique standard du papier des imprimantes de reçus Bluetooth (en mm).
  /// Généralement '58' ou '80' selon le modèle de l'imprimante thermique de ceinture.
  static const int defaultPrinterWidthMm = 58;
}
