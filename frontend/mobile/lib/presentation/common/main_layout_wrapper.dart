import 'package:dabafoodstall/core/services/license_security_service.dart';
import 'package:flutter/material.dart';
import 'bandeau_session.dart'; // Notre composant créé précédemment

class MainLayoutWrapper extends StatelessWidget {
  final Widget child;
  final String nomPOS;
  final String nomUtilisateur;
  final String role;

  const MainLayoutWrapper({
    super.key,
    required this.child,
    this.nomPOS = "Étal Pilote Abidjan",       // Remplacer par vos variables globales/providers
    this.nomUtilisateur = "Diallo Ahmed",      // Remplacer par vos variables globales/providers
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 🛠️ Le bandeau s'affiche obligatoirement au sommet, sur chaque écran enveloppé
          BandeauSession(
            nomPOS: nomPOS,
            nomUtilisateur: nomUtilisateur,
            role: role,
            licenseStatus : LicenseStatus.active,
          ),
          // L'écran cible se déploie juste en dessous
          Expanded(child: child),
        ],
      ),
    );
  }
}
