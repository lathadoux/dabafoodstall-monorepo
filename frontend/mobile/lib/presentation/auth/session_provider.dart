import 'package:flutter_riverpod/flutter_riverpod.dart';
//import '../../data/datasources/local_data_source.dart'; // 💡 Vérifiez ce chemin selon votre projet
import '../../data/datasources/session_data_source.dart'; // 💡 Vérifiez ce chemin selon votre projet

class SessionState {
  final bool hasActiveSession;
  final int? idSession;
  final double? fondCaisse;
  final bool isLoading;

  const SessionState({
    required this.hasActiveSession,
    this.idSession,
    this.fondCaisse,
    this.isLoading = false,
  });
}

class SessionNotifier extends StateNotifier<SessionState> {
  // 🔑 1. Déclarer une variable privée pour conserver la référence Riverpod
  final Ref _ref;

  // 🔑 2. Passer 'ref' au constructeur et le stocker localement
  SessionNotifier(this._ref) : super(const SessionState(hasActiveSession: false, isLoading: true)) {
    verifierSessionAChaud();
  }

  /// Interroge la base SQLite locale pour connaître l'état de la caisse au démarrage
  Future<void> verifierSessionAChaud() async {
    state = const SessionState(hasActiveSession: false, isLoading: true);
    final session = await _ref.read(sessionDataSourceProvider).getSessionActive();
    
    if (session.isNotEmpty) {
      state = SessionState(
        hasActiveSession: true,
        idSession: session['id_session'] as int,
        fondCaisse: (session['montant_init'] as num).toDouble(),
      );
    } else {
      state = const SessionState(hasActiveSession: false);
    }
  }

  /// Initialise la caisse du matin et bascule l'état au vert
  Future<void> initCaisse(double fondInitial, int idTenant, int idUser) async {
    final int newId = await _ref.read(sessionDataSourceProvider).ouvrirNouvelleSession(
      idTenant: idTenant,
      idUtilisateur: idUser,
      fondCaisseInitial: fondInitial,
    );
    state = SessionState(
      hasActiveSession: true,
      idSession: newId,
      fondCaisse: fondInitial,
    );
  }
}

// 🕹️ LE PROVIDER DE SESSION CENTRALISÉ
final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(ref);
});
