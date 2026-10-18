import 'package:flutter/material.dart';

class FraudScreen extends StatelessWidget {
  // 🟢 CORRECTIF 1 : Utilisation des super parameters (Dart 3)
  const FraudScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 🟢 CORRECTIF 2 : Remplacement de WillPopScope par le nouveau PopScope natif de Flutter
    return const PopScope(
      canPop: false, // 🛡️ SÉCURITÉ ABSOLUE : Interdit formellement le retour arrière physique ou gestuel d'Android
      child:  Scaffold(
        backgroundColor: Color(0xFF111111), // Écran noir d'anomalie
        body: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.gpp_bad, size: 80, color: Colors.orange),
              SizedBox(height: 24),
              Text(
                "SÉCURITÉ TEMPORELLE COMPROMISE",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.white, 
                  letterSpacing: 1.2
                ),
              ),
              SizedBox(height: 16),
              Text(
                "Une incohérence majeure a été détectée entre l'horloge système de cette tablette et l'historique sécurisé de vos ventes de caisse hors-ligne.\n\nL'utilisation du grand livre est désactivée tant que la date de l'appareil n'est pas corrigée.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.orange)),
              SizedBox(height: 16),
              Text(
                "En attente de rétablissement de l'heure légale...",
                style: TextStyle(fontSize: 12, color: Colors.white30, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
