import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/license_security_service.dart';

class BandeauSession extends StatelessWidget {
  final String nomPOS;
  // 🟢 CORRECTIF 1 : Passage en String? pour accepter les états nullables de Riverpod
  final String? nomUtilisateur;
  final String? role;
  final LicenseStatus licenseStatus; 

  const BandeauSession({
    super.key,
    required this.nomPOS,
    required this.nomUtilisateur,
    required this.role,
    required this.licenseStatus, 
  });

  @override
  Widget build(BuildContext context) {
    // 🟢 CORRECTIF 2 : La vérification redevient valide et utile pour l'analyseur Dart
    final bool isIdentified = nomUtilisateur != null && role != null;
    
    // Extraction des rôles métiers natifs sécurisée par la barrière d'identification
    final bool isManager = isIdentified && role!.toLowerCase() == 'manager';
    final bool isAdmin = isIdentified && role!.toLowerCase() == 'admin';

    // 🎨 Calcul dynamique de la couleur de fond du bandeau
    Color backgroundColor = const Color(0xFF1F1A17); 
    if (!isIdentified) {
      backgroundColor = const Color(0xFF2A1414); 
    } else if (isManager) {
      backgroundColor = const Color(0xFF2C1E17); 
    } else if (isAdmin) {
      backgroundColor = const Color(0xFF23142A); 
    }

    // 🏷️ Calcul dynamique du texte et de la couleur du Badge d'état
    String badgeText = 'VDR'; 
    Color badgeColor = Colors.orange; 

    if (!isIdentified) {
      badgeText = 'LOCK'; 
      badgeColor = AppTheme.alertRed; 
    } else if (isManager) {
      badgeText = 'MGR'; 
      badgeColor = AppTheme.successGreen; 
    } else if (isAdmin) {
      badgeText = 'ADM'; 
      badgeColor = Colors.purpleAccent; 
    }

    final bool displayWarning = licenseStatus == LicenseStatus.warningNearExpiry;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: backgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: SafeArea(
            bottom: false, 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                // 🏪 Côté Gauche : Stand / POS
                Row(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    const Text('🏪', style: TextStyle(fontSize: 12)), 
                    const SizedBox(width: 4), 
                    Text(
                      nomPOS.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primaryAmber,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(width: 8), 

                // 🔒 Côté Droit : Zone utilisateur isolée anti-overflow
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end, 
                    children: [
                      Flexible(
                        child: Text(
                          isIdentified ? nomUtilisateur! : "NON IDENTIFIÉ", 
                          overflow: TextOverflow.ellipsis, 
                          maxLines: 1, 
                          style: TextStyle(
                            color: isIdentified ? AppTheme.cleanWhite : AppTheme.alertRed, 
                            fontSize: 10, 
                            fontWeight: isIdentified ? FontWeight.w500 : FontWeight.bold, 
                          ),
                        ),
                      ),
                      const SizedBox(width: 6), 
                      
                      // Badge de Statut Dynamique
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5), 
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(4), 
                          border: Border.all(
                            color: badgeColor,
                            width: 0.8, 
                          ),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 8, 
                            fontWeight: FontWeight.bold, 
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 🟠 LA BANNIÈRE ORANGE DE BRIDAGE IMMINENT
        if (displayWarning)
          Container(
            width: double.infinity,
            color: const Color(0xFFFF9800), 
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.black, size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Attention : Votre abonnement de caisse expire bientôt. Veuillez renouveler le forfait pour éviter le blocage du stand.",
                    style: TextStyle(
                      color: Colors.black, 
                      fontWeight: FontWeight.w600, 
                      fontSize: 9,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
