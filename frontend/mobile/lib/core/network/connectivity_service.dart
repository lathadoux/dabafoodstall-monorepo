import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  
  // Contrôleur de flux pour diffuser l'état de la connexion à travers l'application
  final StreamController<bool> _connectionChangeController = StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionChangeController.stream;

  ConnectivityService() {
    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  /// Intercepte le changement physique de réseau (Cellulaire ou Wi-Fi)
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    // connectivity_plus renvoie une liste depuis les versions récentes. 
    // On vérifie si au moins un réseau actif permet d'accéder à internet.
    bool hasConnection = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    _connectionChangeController.add(hasConnection);
  }

  /// Permet une vérification ponctuelle (One-shot) de l'état réseau actuel
  Future<bool> checkCurrentConnection() async {
    List<ConnectivityResult> results = await _connectivity.checkConnectivity();
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }

  /// Fermeture propre du contrôleur pour éviter les fuites de mémoire vive (RAM)
  void dispose() {
    _connectionChangeController.close();
  }
}
