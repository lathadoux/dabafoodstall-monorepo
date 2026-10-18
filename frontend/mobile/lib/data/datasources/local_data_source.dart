// path: frontend/mobile/lib/data/datasources/local_data_source.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_seeder.dart';

// 🔑 UNIQUE SOURCE DE VÉRITÉ DU PROVIDER POUR LE LOGICIEL DE BASE
final localDataSourceProvider = Provider<LocalDataSource>((ref) {
  return LocalDataSource();
});

class LocalDataSource {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

// path: frontend/mobile/lib/data/datasources/local_data_source.dart

  /// ⚙️ 1. GESTION DES SEEDERS ET DE L'INITIALISATION DYNAMIQUE DE BASE
  Future<void> seedTestData() async {
    try {
      final db = await _dbHelper.database;
      // 🔑 CORRECTIF V2 : Appel de la méthode dynamique et globale basée sur le manifeste injecté
      await DatabaseSeeder.seedDatabaseFromManifest(db);
      debugPrint("✅ [LocalDataSource] Base SQLite synchronisée et initialisée via identity.json.");
    } catch (e) {
      debugPrint("🛑 [LocalDataSource Erreur] Impossible d'initialiser : $e");
      rethrow;
    }
  }


  /// ⚙️ 2. RÉCUPÉRATION DES PARAMÈTRES DE CONFIGURATION GÉNÉRAUX
  Future<Map<String, dynamic>> getConfigurationParams() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('pos_params', limit: 1);
    return maps.isNotEmpty ? maps.first : {
      'id_tenant': 1, 
      'nom_pos': 'Étal Provisoire Daba', 
      'devise': 'F'
    };
  }

  /// 📥 3. ASPIRATION ET RECHARGEMENT DES CATALOGUES DEPUIS POSTGRESQL 15
  Future<void> syncCatalogFromServer({
    required int tenantId,
    required String businessName,
    required List<Map<String, dynamic>> famillesFromServer,
    required List<Map<String, dynamic>> articlesFromServer,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');
      await txn.delete('articles', where: 'id_tenant = ?', whereArgs: [tenantId]);
      await txn.delete('familles', where: 'id_tenant = ?', whereArgs: [tenantId]);
      await txn.insert('tenants', {'id_tenant': tenantId, 'nom_business': businessName}, conflictAlgorithm: ConflictAlgorithm.replace);
      
      final batchFamilles = txn.batch();
      for (var fam in famillesFromServer) {
        batchFamilles.insert('familles', {
          'id_famille': fam['id_famille'] ?? fam['id'],
          'id_tenant': tenantId,
          'nom_famille': fam['nom_famille'] ?? fam['nom'],
          'type_famille': fam['type_famille'],
          'type_pos': fam['type_pos'] ?? 'general',
        });
      }
      await batchFamilles.commit(noResult: true);

      final batchArticles = txn.batch();
      for (var art in articlesFromServer) {
        batchArticles.insert('articles', {
          'id_article': art['id_article'] ?? art['id'],
          'id_tenant': tenantId,
          'id_famille': art['id_famille'] ?? art['famille_id'],
          'nom_article': art['nom_article'] ?? art['nom'],
          'type_article': art['type_article'],
          'prix_unitaire': art['prix_unitaire'],
          'unite_mesure': art['unite_mesure'] ?? 'pcs',
          'type_pos': art['type_pos'] ?? 'general',
        });
      }
      await batchArticles.commit(noResult: true);
      await txn.execute('PRAGMA foreign_keys = ON');
    });
  }

  /// ⚙️ 4. EXAMEN ET AUDIT STRUCTUREL DES TABLES LOCALES POUR L'IHM SYNC
  Future<List> getListeTables() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> res = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'android_%' AND name NOT LIKE 'sqlite_%'"
    );
    return res.map((row) => row['name'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getStructureTable(String nomTable) async {
    final db = await _dbHelper.database;
    return await db.rawQuery("PRAGMA table_info('$nomTable')");
  }

  Future<List<Map<String, dynamic>>> getDonneesTable(String nomTable) async {
    final db = await _dbHelper.database;
    return await db.query(nomTable, limit: 100);
  }

  /// ⚙️ 5. GESTION DES COMPTES COLLABORATEURS ET DE LA SÉCURITÉ RH EN LOCAL
  Future<Map<String, dynamic>?> verifierPinUtilisateur(String pinSaisi) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> res = await db.query('users', where: 'pin_user = ?', whereArgs: [pinSaisi], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<bool> estPinUnique(String pin, {int? idUserAExclure}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> res = await db.query(
      'users', 
      where: idUserAExclure != null ? 'pin_user = ? AND id_user != ?' : 'pin_user = ?', 
      whereArgs: idUserAExclure != null ? [pin, idUserAExclure] : [pin]
    );
    return res.isEmpty;
  }

  Future<int> creerUtilisateur(String nom, String role, String password, String pin) async {
    final db = await _dbHelper.database;
    return await db.insert('users', {
      'id_tenant': 1, 
      'nom_user': nom, 
      'role_user': role, 
      'password_user': password, 
      'pin_user': pin
    });
  }

// À coller à la fin de la classe LocalDataSource dans lib/data/datasources/local_data_source.dart

  /// 📊 EXTRACTION RH : Récupère la liste consolidée des manquants cumulés par Chef d'équipe
  Future<List<Map<String, dynamic>>> getSyntheseManquantsParResponsable() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        u.id_user, u.nom_user, u.role_user,
        COUNT(rz.id_rapport_z) as nbr_clotures_deficitaires,
        SUM(CASE WHEN rz.ecart_caisse < 0 THEN rz.ecart_caisse ELSE 0 END) as total_manquants_cumules
      FROM users u
      JOIN rapports_z rz ON u.id_user = rz.id_user
      WHERE rz.ecart_caisse < 0
      GROUP BY u.id_user
      ORDER BY total_manquants_cumules ASC
    ''');
  }

  /// 🧼 PURGE SÉCURISÉE (ADMIN ONLY) : Solder ou effacer les manquants d'un responsable après remboursement
  Future<int> purgerEtSolderManquantsResponsable(int idUser) async {
    final db = await _dbHelper.database;
    return await db.update(
      'rapports_z',
      {
        'ecart_caisse': 0.0,
        'observations': '[SOLDE ET PURGÉ PAR L\'ADMINISTRATEUR]',
        'statut_sync': 0 // Prêt pour notifier le Cloud PostgreSQL 15
      },
      where: 'id_user = ? AND ecart_caisse < 0',
      whereArgs: [idUser],
    );
  }


  Future<int> modifierUtilisateur(int idUser, String nom, String role, String password, String pin) async {
    final db = await _dbHelper.database;
    return await db.update('users', {
      'nom_user': nom, 
      'role_user': role, 
      'password_user': password, 
      'pin_user': pin
    }, where: 'id_user = ?', whereArgs: [idUser]);
  }


  Future<void> purgerToutEnCascade() async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');
      await txn.delete('rapports_z');
      await txn.delete('financial_transactions');
      await txn.delete('order_items');
      await txn.delete('orders');
      await txn.delete('cash_sessions');
      await txn.execute('PRAGMA foreign_keys = ON');
    });
  }

  Future<void> purgerDonneesLocales() async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');
      await txn.delete('rapports_z');
      await txn.delete('order_items');
      await txn.delete('orders');
      await txn.delete('financial_transactions');
      await txn.delete('articles');
      await txn.delete('familles');
      await txn.delete('cash_sessions');
      await txn.delete('tenants');
      await txn.execute('PRAGMA foreign_keys = ON');
    });
  }
  /// ⚙️ PASSE-PLAT DE SYNC : Valide la remontée réseau en lot en basculant le flag statut_sync à 1
  Future<void> marquerTransactionsCommeSynchronisees() async {
    final db = await _dbHelper.database;
    await db.update(
      'financial_transactions', 
      {'statut_sync': 1}, 
      where: 'statut_sync = 0'
    );
  }

// À coller à la fin de la classe LocalDataSource dans lib/data/datasources/local_data_source.dart

  /// 🛡️ VERROU SYNC ENGINE V2 : Valide l'état d'activation de la licence BackOffice
  /// Utilisé par l'aiguillage du code PIN pour bloquer l'IHM Admin en cas d'expiration
  Future<bool> verifierLicenceBackOffice() async {
    final db = await _dbHelper.database; 

    final List<Map<String, dynamic>> result = await db.query(
      'local_license_config',
      where: 'feature_key = ? AND is_enabled = 1 AND status = ?',
      whereArgs: ['allow_backoffice', 'ACTIVE'],
    );

    return result.isNotEmpty;
  }


}
