// path: frontend/mobile/lib/data/database/database_seeder.dart
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseSeeder {
  /// Initialise de manière étanche et idempotente le catalogue complet Garba Stall
  static Future<void> seedTestData(Database db) async {
    try {
      debugPrint("🌱 [SQLite Démo Seeder] Amorçage de la configuration d'usine, RH et Catalogue complet...");

      final batch = db.batch();

      // ===================================================================
      // 🗄️ 1. PARAMÈTRES DU POINT DE VENTE D'USINE
      // ===================================================================
      final List<Map<String, dynamic>> existingParams = await db.query('pos_params', limit: 1);
      if (existingParams.isEmpty) {
        batch.insert('pos_params', {
          'id_tenant': 1,
          'nom_pos': 'Garba Pilote ',
          'telephone_pos': '+225 07 01 02 03',
          'devise': 'F',
          'adresse_pos': 'Zone 4, Abidjan',
          'version_schema': 'V1.0-DEMO'
        });
      }

      // ===================================================================
      // 🛡️ 2. BASE RH / PROFIL DE SÉCURITÉ ACCÈS PIN
      // ===================================================================
      final List<Map<String, dynamic>> existingUsers = await db.query('users', limit: 1);
      if (existingUsers.isEmpty) {
        batch.insert('users', {'id_user': 3, 'id_tenant': 1, 'nom_user': 'Super Admin Daba', 'role_user': 'admin', 'password_user': 'pass', 'pin_user': '0000'});
        batch.insert('users', {'id_user': 1, 'id_tenant': 1, 'nom_user': 'Koffi Alexis', 'role_user': 'manager', 'password_user': 'pass', 'pin_user': '2026'});
        batch.insert('users', {'id_user': 2, 'id_tenant': 1, 'nom_user': 'Moussa Diop', 'role_user': 'vendor', 'password_user': 'pass', 'pin_user': '1234'});
      }

      // ===================================================================
      // 📥 3. INJECTION COMPLÈTE DES 10 FAMILLES (COMMERCIALES + COFFRE)
      // ===================================================================
      final List<Map<String, dynamic>> existingFamilles = await db.query('familles', limit: 1);
      if (existingFamilles.isEmpty) {
        batch.insert('familles', {'id_famille': 1, 'id_tenant': 1, 'nom_famille': 'Garba 🐟', 'type_famille': 'vente'});
        batch.insert('familles', {'id_famille': 2, 'id_tenant': 1, 'nom_famille': 'Attiéké 🌾', 'type_famille': 'vente'});
        batch.insert('familles', {'id_famille': 3, 'id_tenant': 1, 'nom_famille': 'Condiments 🌶️', 'type_famille': 'vente'});
        batch.insert('familles', {'id_famille': 4, 'id_tenant': 1, 'nom_famille': 'Boissons 🥤', 'type_famille': 'vente'});
        batch.insert('familles', {'id_famille': 5, 'id_tenant': 1, 'nom_famille': 'Général 🏢', 'type_famille': 'achat'});
        batch.insert('familles', {'id_famille': 6, 'id_tenant': 1, 'nom_famille': 'Épicerie 🧅', 'type_famille': 'achat'});
        batch.insert('familles', {'id_famille': 7, 'id_tenant': 1, 'nom_famille': 'Énergie ⚡', 'type_famille': 'achat'});
        batch.insert('familles', {'id_famille': 8, 'id_tenant': 1, 'nom_famille': 'Ustensiles 🍳', 'type_famille': 'achat'});
        batch.insert('familles', {'id_famille': 9, 'id_tenant': 1, 'nom_famille': 'Désaltérants 🧪', 'type_famille': 'achat'});
        
        // 🔒 LOCK IDEMPOTENCE : Intégration étanche de la famille de mouvements de caisse du patron
        batch.insert('familles', {'id_famille': 10, 'id_tenant': 1, 'nom_famille': 'mvt_coffre 🪙', 'type_famille': 'vente'});
      }

      // ===================================================================
      // 📦 4. INJECTION DES 35 ARTICLES (33 CATALOGUE GARBA + 2 INFRA COFFRE)
      // ===================================================================
      final List<Map<String, dynamic>> existingArticles = await db.query('articles', limit: 1);
      if (existingArticles.isEmpty) {
        // --- FAMILLE 1 : GARBA 🐟 ---
        batch.insert('articles', {'id_article': 1, 'id_tenant': 1, 'id_famille': 1, 'nom_article': 'Garba 150F', 'type_article': 'vente', 'prix_unitaire': 150.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 2, 'id_tenant': 1, 'id_famille': 1, 'nom_article': 'Garba 200F', 'type_article': 'vente', 'prix_unitaire': 200.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 3, 'id_tenant': 1, 'id_famille': 1, 'nom_article': 'Garba 250F', 'type_article': 'vente', 'prix_unitaire': 250.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 4, 'id_tenant': 1, 'id_famille': 1, 'nom_article': 'Garba 300F', 'type_article': 'vente', 'prix_unitaire': 300.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 5, 'id_tenant': 1, 'id_famille': 1, 'nom_article': 'Garba 400F', 'type_article': 'vente', 'prix_unitaire': 400.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 6, 'id_tenant': 1, 'id_famille': 1, 'nom_article': 'Garba 500F', 'type_article': 'vente', 'prix_unitaire': 500.00, 'unite_mesure': 'pcs'});

        // --- FAMILLE 2 : ATTIÉKÉ 🌾 ---
        batch.insert('articles', {'id_article': 7, 'id_tenant': 1, 'id_famille': 2, 'nom_article': 'Attiéké 100F', 'type_article': 'vente', 'prix_unitaire': 100.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 8, 'id_tenant': 1, 'id_famille': 2, 'nom_article': 'Attiéké 50F', 'type_article': 'vente', 'prix_unitaire': 50.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 9, 'id_tenant': 1, 'id_famille': 2, 'nom_article': 'Attiéké 200F', 'type_article': 'vente', 'prix_unitaire': 200.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 10, 'id_tenant': 1, 'id_famille': 2, 'nom_article': 'Attiéké 300F', 'type_article': 'vente', 'prix_unitaire': 300.00, 'unite_mesure': 'pcs'});

        // --- FAMILLE 3 : CONDIMENTS 🌶️ ---
        batch.insert('articles', {'id_article': 11, 'id_tenant': 1, 'id_famille': 3, 'nom_article': 'Tomate 50F', 'type_article': 'vente', 'prix_unitaire': 50.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 12, 'id_tenant': 1, 'id_famille': 3, 'nom_article': 'Tomate 100F', 'type_article': 'vente', 'prix_unitaire': 100.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 13, 'id_tenant': 1, 'id_famille': 3, 'nom_article': 'Oignon 50F', 'type_article': 'vente', 'prix_unitaire': 50.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 14, 'id_tenant': 1, 'id_famille': 3, 'nom_article': 'Oignon 100F', 'type_article': 'vente', 'prix_unitaire': 100.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 15, 'id_tenant': 1, 'id_famille': 3, 'nom_article': 'Mayo 50F', 'type_article': 'vente', 'prix_unitaire': 50.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 16, 'id_tenant': 1, 'id_famille': 3, 'nom_article': 'Œuf Dur', 'type_article': 'vente', 'prix_unitaire': 100.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 17, 'id_tenant': 1, 'id_famille': 3, 'nom_article': 'Cube Maggi', 'type_article': 'vente', 'prix_unitaire': 50.00, 'unite_mesure': 'pcs'});

        // --- FAMILLE 4 : BOISSONS 🥤 ---
        batch.insert('articles', {'id_article': 18, 'id_tenant': 1, 'id_famille': 4, 'nom_article': 'Eau-Pack 50F', 'type_article': 'vente', 'prix_unitaire': 50.00, 'unite_mesure': 'pcs'});

        // --- FAMILLE 5 : GÉNÉRAL (ACHATS EN GROS AU MONTANT) 🏢 ---
        batch.insert('articles', {'id_article': 19, 'id_tenant': 1, 'id_famille': 5, 'nom_article': 'Poisson au montant', 'type_article': 'achat', 'prix_unitaire': null, 'unite_mesure': 'kg'});
        batch.insert('articles', {'id_article': 20, 'id_tenant': 1, 'id_famille': 5, 'nom_article': 'Attiéké au montant', 'type_article': 'achat', 'prix_unitaire': null, 'unite_mesure': 'sac'});

        // --- FAMILLE 6 : ÉPICERIE 🧅 ---
        batch.insert('articles', {'id_article': 21, 'id_tenant': 1, 'id_famille': 6, 'nom_article': 'Huile (Bidon 6L)', 'type_article': 'achat', 'prix_unitaire': 5000.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 22, 'id_tenant': 1, 'id_famille': 6, 'nom_article': 'Tomate vrac', 'type_article': 'achat', 'prix_unitaire': null, 'unite_mesure': 'lot'});
        batch.insert('articles', {'id_article': 23, 'id_tenant': 1, 'id_famille': 6, 'nom_article': 'Oignon vrac', 'type_article': 'achat', 'prix_unitaire': null, 'unite_mesure': 'lot'});
        batch.insert('articles', {'id_article': 24, 'id_tenant': 1, 'id_famille': 6, 'nom_article': 'Piment vrac', 'type_article': 'achat', 'prix_unitaire': null, 'unite_mesure': 'lot'});
        batch.insert('articles', {'id_article': 25, 'id_tenant': 1, 'id_famille': 6, 'nom_article': 'Cube (Plaquette)', 'type_article': 'achat', 'prix_unitaire': 600.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 26, 'id_tenant': 1, 'id_famille': 6, 'nom_article': 'Mayo (Chapeau)', 'type_article': 'achat', 'prix_unitaire': 1000.00, 'unite_mesure': 'pcs'});

        // --- FAMILLE 7 : ÉNERGIE ⚡ ---
        batch.insert('articles', {'id_article': 27, 'id_tenant': 1, 'id_famille': 7, 'nom_article': 'Gaz (Recharge)', 'type_article': 'achat', 'prix_unitaire': 2500.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 28, 'id_tenant': 1, 'id_famille': 7, 'nom_article': 'Gaz (Bonbonne)', 'type_article': 'achat', 'prix_unitaire': 1500.00, 'unite_mesure': 'pcs'});

        // --- FAMILLE 8 : USTENSILES 🍳 ---
        batch.insert('articles', {'id_article': 29, 'id_tenant': 1, 'id_famille': 8, 'nom_article': 'Poêle', 'type_article': 'achat', 'prix_unitaire': 5000.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 30, 'id_tenant': 1, 'id_famille': 8, 'nom_article': 'Écumoire', 'type_article': 'achat', 'prix_unitaire': 2000.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 31, 'id_tenant': 1, 'id_famille': 8, 'nom_article': 'Assiettes', 'type_article': 'achat', 'prix_unitaire': 100.00, 'unite_mesure': 'pcs'});
        batch.insert('articles', {'id_article': 32, 'id_tenant': 1, 'id_famille': 8, 'nom_article': 'Gobelets', 'type_article': 'achat', 'prix_unitaire': 200.00, 'unite_mesure': 'pcs'});
        // --- FAMILLE 9 : DÉSALTÉRANTS 🧪 ---
        batch.insert('articles', {'id_article': 33, 'id_tenant': 1, 'id_famille': 9, 'nom_article': 'Sac d''eau', 'type_article': 'achat', 'prix_unitaire': 600.00, 'unite_mesure': 'sac'});
        // --- FAMILLE 10 : INFRASTRUCTURE MOUVEMENTS COFFRE 🪙 ---
        batch.insert('articles', {
        'id_article': 901,
        'id_tenant': 1,
        'id_famille': 10,
        'nom_article': 'Appro Caisse (+)',
        'type_article': 'vente',
        'prix_unitaire': 1.0,
        'unite_mesure': 'F'
        });
        batch.insert('articles', {
        'id_article': 902,
        'id_tenant': 1,
        'id_famille': 10,
        'nom_article': 'Versement  (-)',
        'type_article': 'achat',
        'prix_unitaire': 1.0,
        'unite_mesure': 'F'
        });
}
await batch.commit(noResult: true);
debugPrint("✅ [SQLite Démo Seeder] Catalogue d'usine Garba Stall armé au vert parfait et sécurisé.");
} catch (e) {
debugPrint("🛑 [SQLite Démo Seeder Erreur] Échec de l'injection : $e");
}
}
}