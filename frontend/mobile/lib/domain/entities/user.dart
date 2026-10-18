enum UserRole { admin, manager, vendor }

/// Entité métier pure représentant un collaborateur avec droits figés par groupe.
class User {
  final int idUser;
  final int idTenant;
  final String nomUser;
  final UserRole roleUser;

  const User({
    required this.idUser,
    required this.idTenant,
    required this.nomUser,
    required this.roleUser,
  });

  // ===========================================================================
  // MATRICE DES DROITS FIGÉS (MOT VERSION 1)
  // ===========================================================================

  bool get isAdmin => roleUser == UserRole.admin;
  bool get isManager => roleUser == UserRole.manager;
  bool get isVendor => roleUser == UserRole.vendor;

  // --- DROITS GROUPE : ADMINISTRATEURS ---
  /// Droits exclusifs : Configuration de l'infrastructure globale.
  bool get peutModifierParametresGlobaux => isAdmin;
  bool get peutModifierDevises => isAdmin;
  bool get peutModifierMoyensPaiement => isAdmin;
  bool get peutGererUtilisateurs => isAdmin;

  // --- DROITS GROUPE : GESTIONNAIRES ---
  /// Droits d'exploitation : Paramétrage du panneau, articles, achats et bilans.
  bool get peutParametrerPanneauVente => isManager;
  bool get peutGererArticlesEtFamilles => isManager;
  bool get peutGererAchatsDirects => isManager;
  bool get peutConsulterEtatsEtBilans => isManager;

  // --- DROITS GROUPE : VENDEURS ---
  /// Droits de terrain : Encaissement rapide et déclaration de fin de service.
  bool get peutVendreEtEncaisser => isVendor;
  bool get peutCloturerCaisse => isVendor;
}
