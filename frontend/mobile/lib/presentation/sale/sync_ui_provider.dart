import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/connectivity_service.dart';
import '../../data/repositories/sync_repository.dart';

class SyncUiState {
  final bool isOnline;
  final bool isSyncing;
  final String lastSyncMessage;

  SyncUiState({
    this.isOnline = true,
    this.isSyncing = false,
    this.lastSyncMessage = "",
  });

  SyncUiState copyWith({bool? isOnline, bool? isSyncing, String? lastSyncMessage}) {
    return SyncUiState(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncMessage: lastSyncMessage ?? this.lastSyncMessage,
    );
  }
}

class SyncUiNotifier extends StateNotifier<SyncUiState> {
  final ConnectivityService _connectivityService = ConnectivityService();
  final Ref _ref;

  SyncUiNotifier(this._ref) : super(SyncUiState()) {
    // Écoute en continu les changements physiques du signal réseau du téléphone
    _connectivityService.connectionStream.listen((hasConnection) {
      state = state.copyWith(isOnline: hasConnection);
    });
    _initFirstCheck();
  }

  Future<void> _initFirstCheck() async {
    bool currentNet = await _connectivityService.checkCurrentConnection();
    state = state.copyWith(isOnline: currentNet);
  }

  /// Force le déclenchement du dépôt de synchronisation binaire vers le Cloud
  Future<void> triggerManualSync() async {
    if (!state.isOnline) {
      state = state.copyWith(lastSyncMessage: "❌ Impossible : Vous êtes actuellement hors-ligne (🟡).");
      return;
    }

    state = state.copyWith(isSyncing: true, lastSyncMessage: "📡 Synchronisation du stand en cours...");
    
    final syncRepo = _ref.read(syncRepositoryProvider);
    // Utilisation du jeton multi-tenant de test du stand
    bool success = await syncRepo.synchronizeLocalDataToCloud("TOKEN_STAND_TEST");

    state = state.copyWith(
      isSyncing: false,
      lastSyncMessage: success 
          ? "✅ Caisse synchronisée avec succès avec le Cloud !" 
          : "⚠️ Échec : Le serveur distant n'a pas validé le lot.",
    );
  }
}

final syncUiProvider = StateNotifierProvider<SyncUiNotifier, SyncUiState>((ref) {
  return SyncUiNotifier(ref);
});
