import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_provider.dart'; // 🛠/ IMPORT DU NOUVEAU PROVIDER DE SESSION
/// 🧠 STRUCTURE DE L'ÉTAT GLOBALE DU BANDEAU
class OperatorState {
  final bool isAuthenticated;
  final String nomPOS;
  final int? idUser; // 🛠️ FIX : Ajout de la clé primaire d'audit pour l'extraction SQLite
  final String? nomUtilisateur;
  final String? role;

  const OperatorState({
    required this.isAuthenticated,
    required this.nomPOS,
    required this.idUser,
    this.nomUtilisateur,
    this.role,
  });
}

/// 🕹️ PROVIDER COMPTABLE DE L'OPÉRATEUR COURANT
final currentOperatorProvider = StateProvider<OperatorState>((ref) {
  return const OperatorState(
    isAuthenticated: false,
    nomPOS: "Étal Pilote Abidjan",
    idUser: null,
    nomUtilisateur: null,
    role: null,
  );
});
// path: frontend/mobile/lib/presentation/auth/auth_provider.dart

// ... Conservez le code initial de OperatorState et currentOperatorProvider intact

/// 🧠 NOUVEL EXTRRACTEUR GLOBAL FUSIONNÉ (Pull-Synchronisé)
/// Permet d'accéder d'un seul coup aux identifiants Contextuels de vente partout.
final activeSessionContextContext = Provider.autoDispose<Map<String, int>>((ref) {
  // 🕵️ Écoute à chaud du vendeur connecté et de la session de caisse ouverte
  final operator = ref.watch(currentOperatorProvider);
  final session = ref.watch(sessionProvider); // Provient de session_provider.dart

  return {
    'idUser': operator.idUser ?? 2,       // Repli de secours (ex: Moussa Diop)
    'idSession': session.idSession ?? 1,   // Repli sur la session 1 par défaut
  };
});
