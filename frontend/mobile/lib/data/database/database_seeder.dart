// path: frontend/mobile/lib/data/database/database_seeder.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

class DatabaseSeeder {
  /// 🎛️ Point d'entrée unique et atomique d'amorçage de la base de données locale
  static Future<void> seedDatabaseFromManifest(Database db) async {
    try {
      debugPrint("🌱 [Sync Engine V2 Seeder] Lecture du manifeste d'identité injecté...");
      
      // 1. Chargement sécurisé du manifeste d'identité injecté par le serveur
      final String manifestContent = await rootBundle.loadString('assets/config/identity.json');
      final Map<String, dynamic> manifest = jsonDecode(manifestContent);

      final batch = db.batch();

      // Extrait les variables du premier niveau du contrat JSON
      final String enrolmentFingerprint = manifest['enrolment_fingerprint'] ?? 'UNKNOWN_FP';
      final String posType = manifest['pos_type'] ?? 'general';
      final Map<String, dynamic> licenseMeta = manifest['license_meta'] ?? {};
      final List<dynamic> factoryRh = manifest['factory_rh'] ?? [];
      final Map<String, dynamic> catalogueTemplate = manifest['catalogue_template'] ?? {};

      // ===================================================================
      // 🗄️ ÉTAPE 1 : PROVISIONNING DES PARAMÈTRES DU POINT DE VENTE
      // ===================================================================
      final List<Map<String, dynamic>> existingParams = await db.query('pos_params', limit: 1);
      if (existingParams.isEmpty) {
        batch.insert('pos_params', {
          'id_param': 1,
          'id_tenant': 1,
          'id_pos': 1,
          'device_fingerprint': enrolmentFingerprint,
          'nom_pos': posType == 'garba_stall' ? 'Stand Garba Certifié' : 'Commerce Général',
          'telephone_pos': '+225 07 00 00 00 00',
          'devise': 'F',
          'adresse_pos': 'Abidjan, Côte d\'Ivoire',
          'version_schema': 'V2.0-SOVEREIGN-AUTO',
          'cle_activation_scellee': enrolmentFingerprint,
          'date_activation': DateTime.now().toIso8601String(),
          'jours_utilises_cumules': 0
        });
      }

      // ===================================================================
      // 🛡️ ÉTAPE 2 : INJECTION DE LA TRIADE RH MULTI-NIVEAUX (PRODUITS DE PIN)
      // ===================================================================
      debugPrint("👥 [Seeder] Injection de l'équipe de comptoir standard...");
      for (var user in factoryRh) {
        batch.insert('users', {
          'id_user': user['id_user'],
          'id_tenant': 1,
          'nom_user': user['nom_user'],
          'role_user': user['role_user'],
          'password_user': 'pass', // Secours cryptographique standard
          'pin_user': user['initial_pin'] // Code PIN d'étal calculé en amont par le serveur
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // ===================================================================
      // 🔒 ÉTAPE 3 : ARMEMENT DES VERROUS DU PLAN COMMERCIAL SAAS
      // ===================================================================
      debugPrint("🔑 [Seeder] Configuration des verrous de l'IHM applicative...");
      final String expiryDate = licenseMeta['expires_at'] ?? DateTime.now().add(const Duration(days: 30)).toIso8601String();
      
      final List<Map<String, String>> featureKeys = [
        {'key': 'allow_backup', 'val': (licenseMeta['allow_backup'] ?? 0).toString()},
        {'key': 'allow_backoffice', 'val': (licenseMeta['allow_backoffice'] ?? 0).toString()},
        {'key': 'allow_realtime_sync', 'val': (licenseMeta['allow_realtime_sync'] ?? 0).toString()}
      ];

      for (var feature in featureKeys) {
        batch.insert('local_license_config', {
          'feature_key': feature['key'],
          'is_enabled': int.parse(feature['val']!),
          'expires_at': expiryDate,
          'status': 'ACTIVE'
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // ===================================================================
      // 📥 ÉTAPE 4 : PEUPLEMENT DYNAMIQUE DES FAMILLES (ONGLETS IHM)
      // ===================================================================
      final List<dynamic> famillesList = catalogueTemplate['familles'] ?? [];
      final List<Map<String, dynamic>> checkFamilles = await db.query('familles', limit: 1);
      
      if (checkFamilles.isEmpty && famillesList.isNotEmpty) {
        debugPrint("📊 [Seeder] Amorçage des onglets tactiles du catalogue...");
        for (var f in famillesList) {
          batch.insert('familles', {
            'id_famille': f['id_famille'],
            'id_tenant': 1,
            'nom_famille': f['nom_famille'],
            'type_famille': f['type_famille'],
            'type_pos': posType,
            'updated_at': DateTime.now().toIso8601String()
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      // ===================================================================
      // 📦 ÉTAPE 5 : PEUPLEMENT DYNAMIQUE DES ARTICLES (COMPTOIR & LOGISTIQUE)
      // ===================================================================
      final List<dynamic> articlesList = catalogueTemplate['articles'] ?? [];
      final List<Map<String, dynamic>> checkArticles = await db.query('articles', limit: 1);

      if (checkArticles.isEmpty && articlesList.isNotEmpty) {
        debugPrint("🐟 [Seeder] Injection des références du Grand Livre distant...");
        for (var a in articlesList) {
          batch.insert('articles', {
            'id_article': a['id_article'],
            'id_tenant': 1,
            'id_famille': a['id_famille'],
            'nom_article': a['nom_article'],
            'type_article': a['type_article'],
            'prix_unitaire': a['prix_unitaire'],
            'unite_mesure': a['unite_mesure'] ?? 'pcs',
            'type_pos': posType,
            'updated_at': DateTime.now().toIso8601String()
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      // Validation finale unifiée au sein d'une unique transaction SQL
      await batch.commit(noResult: true);
      debugPrint("✅ [Sync Engine V2 Seeder] Base locale initialisée et armée au vert parfait.");
      
    } catch (e) {
      debugPrint("🛑 [Sync Engine V2 Seeder Erreur] Échec de l'analyse ou du commit SQL : $e");
    }
  }
}
