// path: frontend/mobile/lib/data/database/database_seeder.dart
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseSeeder {
  /// Initialise de manière étanche et idempotente le catalogue d'usine Maquis / Cave
  static Future<void> seedTestData(Database db) async {
    try {
      debugPrint("🌱 [SQLite Démo Seeder] Amorçage de la configuration d'usine, RH et Catalogue boissons...");

      final batch = db.batch();

      // ===================================================================
      // 🗄️ 1. PARAMÈTRES DU POINT DE VENTE D'USINE (CAVE / MAQUIS)
      // ===================================================================
      final List<Map<String, dynamic>> existingParams = await db.query('pos_params', limit: 1);
      if (existingParams.isEmpty) {
        batch.insert('pos_params', {
          'id_tenant': 1,
          'nom_pos': 'Cave Pilote',
          'telephone_pos': '+225 07 45 89 21 10',
          'devise': 'F',
          'adresse_pos': 'Ananeraie, Abidjan',
          'version_schema': 'V1.0-CAVE-DEMO'
        });
      }

      // ===================================================================
      // 🛡️ 2. BASE RH / PROFITS DE SÉCURITÉ ACCÈS PIN
      // ===================================================================
           // On bascule en REPLACE pour forcer la mise à jour de la clé 'pass' quoi qu'il arrive
      batch.insert('users', {'id_user': 3, 'id_tenant': 1, 'nom_user': 'Super Admin Daba', 'role_user': 'admin', 'password_user': 'admin', 'pin_user': '0000'}, conflictAlgorithm: ConflictAlgorithm.replace);
      batch.insert('users', {'id_user': 1, 'id_tenant': 1, 'nom_user': 'Koffi Alexis', 'role_user': 'manager', 'password_user': 'pass', 'pin_user': '2026'}, conflictAlgorithm: ConflictAlgorithm.replace);
      batch.insert('users', {'id_user': 2, 'id_tenant': 1, 'nom_user': 'Moussa Diop', 'role_user': 'vendor', 'password_user': 'pass', 'pin_user': '1234'}, conflictAlgorithm: ConflictAlgorithm.replace);

      // ===================================================================
      // 📥 3. INJECTION DES FAMILLES DE BOISSONS (ONGLETS IHM)
      // ===================================================================
      final List<Map<String, dynamic>> existingFamilles = await db.query('familles', limit: 1);
      if (existingFamilles.isEmpty) {
        // Flux Ventes (Menu tactile serveur / serveuse)
        batch.insert('familles', {'id_famille': 1, 'id_tenant': 1, 'nom_famille': 'Bières (Solibra) 🍺', 'type_famille': 'vente'});
        batch.insert('familles', {'id_famille': 2, 'id_tenant': 1, 'nom_famille': 'Bières (Brassivoire) 🍻', 'type_famille': 'vente'});
        batch.insert('familles', {'id_famille': 3, 'id_tenant': 1, 'nom_famille': 'Sodas & Sucreries 🥤', 'type_famille': 'vente'});
        batch.insert('familles', {'id_famille': 4, 'id_tenant': 1, 'nom_famille': 'Énergisantes ⚡', 'type_famille': 'vente'});
        batch.insert('familles', {'id_famille': 5, 'id_tenant': 1, 'nom_famille': 'Vins Rouges 🍷', 'type_famille': 'vente'});
        batch.insert('familles', {'id_famille': 6, 'id_tenant': 1, 'nom_famille': 'Vins Cave Rouges 🍾', 'type_famille': 'vente'});
        
        // Flux Logistique (Achats de gros par le gérant)
        batch.insert('familles', {'id_famille': 101, 'id_tenant': 1, 'nom_famille': 'Achat Bières Casier 📦', 'type_famille': 'achat'});
        batch.insert('familles', {'id_famille': 102, 'id_tenant': 1, 'nom_famille': 'Achat Sodas & Énergie 📦', 'type_famille': 'achat'});
        batch.insert('familles', {'id_famille': 103, 'id_tenant': 1, 'nom_famille': 'Achat Cartons Vins 📦', 'type_famille': 'achat'});

        // 🔒 FIX IDEMPOTENCE : Injection unifiée de la famille coffre sous le même bloc d'existence
        batch.insert('familles', {'id_famille': 10, 'id_tenant': 1, 'nom_famille': 'mvt_coffre 🪙', 'type_famille': 'vente'});
      }

      // ===================================================================
      // 📦 4. INJECTION DES ARTICLES (31 ARTICLES MULTI-FLUX + 2 FLUX COFFRE)
      // ===================================================================
      final List<Map<String, dynamic>> existingArticles = await db.query('articles', limit: 1);
      if (existingArticles.isEmpty) {
        
        // --- FAMILLE 1 : BIÈRES (SOLIBRA) ---
        _insertItemPair(batch, 1, 1, 101, 'Bock (La 66) 65cl', 600.0, 'Btle', 9000.0, 'Casier(12)');
        _insertItemPair(batch, 2, 1, 101, 'Beaufort Lager 50cl', 700.0, 'Btle', 9500.0, 'Casier(12)');
        _insertItemPair(batch, 3, 1, 101, 'Castel Beer 65cl', 600.0, 'Btle', 9500.0, 'Casier(12)');
        _insertItemPair(batch, 4, 1, 101, 'Doppel Munich 50cl', 700.0, 'Btle', 10500.0, 'Casier(12)');
        _insertItemPair(batch, 5, 1, 101, 'Guinness 33cl', 1000.0, 'Btle', 15500.0, 'Casier(24)');
        _insertItemPair(batch, 6, 1, 101, 'Chill Citron 33cl', 700.0, 'Btle', 13000.0, 'Casier(24)');
        _insertItemPair(batch, 7, 1, 101, 'Sombreros 33cl', 700.0, 'Btle', 15000.0, 'Casier(24)');
        _insertItemPair(batch, 8, 1, 101, 'Budweiser 33cl', 700.0, 'Btle', 18000.0, 'Carton(24)');
        _insertItemPair(batch, 9, 1, 101, 'Corona Extra 35,5cl', 1000.0, 'Btle', 24000.0, 'Carton(24)');

        // --- FAMILLE 2 : BIÈRES (BRASSIVOIRE) ---
        _insertItemPair(batch, 10, 2, 101, 'Ivoire 65cl', 600.0, 'Btle', 8500.0, 'Casier(12)');
        _insertItemPair(batch, 11, 2, 101, 'Black 50cl', 700.0, 'Btle', 10000.0, 'Casier(12)');
        _insertItemPair(batch, 12, 2, 101, 'Heineken 50cl', 700.0, 'Btle', 12500.0, 'Casier(12)');
        _insertItemPair(batch, 13, 2, 101, 'Desperados 33cl', 700.0, 'Btle', 20000.0, 'Carton(24)');

        // --- FAMILLE 3 : SODAS & SUCRERIES ---
        _insertItemPair(batch, 14, 3, 102, 'Youki (Parfums divers) 50cl', 500.0, 'Btle', 4500.0, 'Casier(12)');
        _insertItemPair(batch, 15, 3, 102, 'World Cola 50cl', 500.0, 'Btle', 4500.0, 'Casier(12)');
        _insertItemPair(batch, 16, 3, 102, 'Youzou 50cl', 500.0, 'Btle', 4500.0, 'Casier(12)');
        _insertItemPair(batch, 17, 3, 102, 'Orangina 25cl', 700.0, 'Btle', 11000.0, 'Casier(24)');

        // --- FAMILLE 4 : ÉNERGISANTES ---
        _insertItemPair(batch, 18, 4, 102, 'XXL Energy 33cl', 700.0, 'Canette', 11000.0, 'Carton(24)');
        _insertItemPair(batch, 19, 4, 102, 'Doppel Energy Malt 33cl', 700.0, 'Btle', 11500.0, 'Casier(24)');
        _insertItemPair(batch, 20, 4, 102, 'Malta Guinness 33cl', 700.0, 'Btle', 11500.0, 'Casier(24)');
        _insertItemPair(batch, 21, 4, 102, 'Rhino Energy Malt 33cl', 700.0, 'Canette', 11000.0, 'Carton(24)');
        _insertItemPair(batch, 22, 4, 102, 'Racines / Racines Fort 50cl', 800.0, 'Btle', 7500.0, 'Casier(12)');
        _insertItemPair(batch, 23, 4, 102, 'Kunja 33cl', 800.0, 'Btle', 13000.0, 'Casier(24)');

        // --- FAMILLE 5 : VINS ROUGES ---
        _insertItemPair(batch, 24, 5, 103, 'Le Grand Valpierre 100cl', 2000.0, 'Btle', 13500.0, 'Casier(12)');
        _insertItemPair(batch, 25, 5, 103, 'Le Petit Valpierre 65cl', 1000.0, 'Btle', 9000.0, 'Casier(12)');
        _insertItemPair(batch, 26, 5, 103, 'Le Petit Valpierre 50cl', 800.0, 'Btle', 7200.0, 'Casier(12)');
        _insertItemPair(batch, 27, 5, 103, 'Camus 75cl', 1500.0, 'Btle', 7000.0, 'Carton(6)');
        _insertItemPair(batch, 28, 5, 103, 'Vieux Papes 75cl', 1600.0, 'Btle', 7500.0, 'Carton(6)');
        _insertItemPair(batch, 29, 5, 103, 'Baron de Lestac (Bordeaux) 75cl', 3500.0, 'Btle', 16000.0, 'Carton(6)');

        // --- FAMILLE 6 : VINS CAVE ROUGES ---
        _insertItemPair(batch, 30, 6, 103, 'Roche Mazet (Variés) 75cl', 2500.0, 'Btle', 12000.0, 'Carton(6)');
        _insertItemPair(batch, 31, 6, 103, 'Listel (Grain de Gris) 75cl', 4000.0, 'Btle', 18000.0, 'Carton(6)');

        // 🛠️ FIX SYNTAXE ET IDEMPOTENCE : Réparation de la clé id_famille et protection de l'injection
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
      debugPrint("✅ [SQLite Cave Seeder] Écosystème autonome boissons armé au vert parfait.");
    } catch (e) {
      debugPrint("🛑 [SQLite Cave Seeder Erreur] Échec de l'injection : $e");
    }
  }

  /// 🧠 HELPER MULTI-FLUX COMPTABLE : Insère simultanément la ligne de vente (Détail) et la ligne d'achat (Gros)
  static void _insertItemPair(
    Batch batch, 
    int idBase, 
    int idFamilleVente, 
    int idFamilleAchat, 
    String nom, 
    double prixVente, 
    String unitVente, 
    double prixAchat, 
    String unitAchat
  ) {
    batch.insert('articles', {
      'id_article': idBase,
      'id_tenant': 1,
      'id_famille': idFamilleVente,
      'nom_article': nom,
      'type_article': 'vente',
      'prix_unitaire': prixVente,
      'unite_mesure': unitVente
    });

    batch.insert('articles', {
      'id_article': idBase + 1000, 
      'id_tenant': 1,
      'id_famille': idFamilleAchat,
      'nom_article': '$nom [GROS]',
      'type_article': 'achat',
      'prix_unitaire': prixAchat,
      'unite_mesure': unitAchat
    });
  }
}
