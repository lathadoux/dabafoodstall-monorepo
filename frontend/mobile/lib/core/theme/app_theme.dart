import 'package:flutter/material.dart';

/// Configuration du thème visuel de l'application "DabaFoodStall".
/// Conçu spécifiquement pour la Street Food : Haut contraste pour contrer
/// la forte luminosité extérieure (soleil) et boutons larges faciles à presser.
class AppTheme {
  // Couleurs principales (Palette forte et contrastée)
  static const Color primaryAmber = Color(0xFFFFB300); // Jaune étal / Chaleureux
  static const Color darkCharcoal = Color(0xFF1A1A1A); // Fond sombre texturé ou texte fort
  static const Color cleanWhite = Color(0xFFFFFFFF);   // Fond clair pour lisibilité max
  static const Color alertRed = Color(0xFFD32F2F);     // Alertes stocks / Rendu monnaie
  static const Color successGreen = Color(0xFF388E3C); // Validations encaissements

  /// Génère le thème clair haut contraste par défaut de l'application
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryAmber,
        primary: primaryAmber,
        secondary: darkCharcoal,
        surface: cleanWhite,
        error: alertRed,
      ),
      
      // Configuration de la barre supérieure (AppBar)
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCharcoal,
        foregroundColor: cleanWhite,
        elevation: 4,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: cleanWhite,
        ),
      ),

      // Configuration globale des textes pour une lecture instantanée en extérieur
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: darkCharcoal),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: darkCharcoal),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54),
      ),

      // Style des cartes tactiles (Grille des produits)
      cardTheme: CardThemeData(
        color: cleanWhite,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
        ),
      ),

      // Style par défaut des boutons d'actions massifs (CTA)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAmber,
          foregroundColor: darkCharcoal,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
      
      // Thème pour les onglets horizontaux (Catégories)
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF5F5F5),
        selectedColor: primaryAmber,
        secondarySelectedColor: primaryAmber,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: darkCharcoal),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
