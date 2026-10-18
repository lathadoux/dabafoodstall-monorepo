import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../datasources/sync_local_datasource.dart';
import '../datasources/remote_api_source.dart';
import '../models/order_model.dart';
import '../datasources/security_data_source.dart';

// ===========================================================================
// FOURNISSEURS RIVERPOD (PROVIDERS)
// ===========================================================================



/// Fournisseur pour l'instance globale de RemoteApiSource
final remoteApiSourceProvider = Provider<RemoteApiSource>((ref) {
  // 🔑 Lecture à chaud du fournisseur de sécurité existant
  final securitySource = ref.watch(securityDataSourceProvider); 
  
  // Injection propre de l'instance dans le constructeur de l'API
  return RemoteApiSource(securityDataSource: securitySource);
});

/// Fournisseur principal de Riverpod pour le SyncRepository
final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final remoteSource = ref.watch(remoteApiSourceProvider);
  final localDataSource = ref.watch(syncLocalDataSourceProvider); // 🔑 Écoute de la source locale Z
  return SyncRepository(remoteSource, localDataSource);
});

// ===========================================================================
// IMPLÉMENTATION DU DÉPÔT DE SYNCHRONISATION (VERSION 1 ARTICLES ÉPURÉS)
// ===========================================================================

class SyncRepository {
  final RemoteApiSource _remoteApiSource;
  final SyncLocalDataSource _syncLocalDataSource; // 🔑 Injection de la source locale Z
  final _dbHelper = DatabaseHelper.instance;
  SyncRepository(this._remoteApiSource, this._syncLocalDataSource);


/// 🚀 ORCHESTRATION CLÔTURE Z : Récupère le dictionnaire Map, l'envoie et met à jour le statut
  Future<bool> synchronizeClotureZToCloud(int idSession, String jwtToken) async {
    try {
      debugPrint("🧱 [Sync Z] Extraction et empaquetage du schéma #DABA_SYNC_PUSH_V1...");
      
      // 1. Appel de votre dictionnaire Map mis à jour à l'étape précédente
      final Map<String, dynamic> cloturePayload = await _syncLocalDataSource.genererPayloadClotureZ(idSession);

      debugPrint("📡 [Sync Z] Acheminement du payload scellé vers la passerelle d'API...");

      // 2. Expédition via le canal réseau authentifié
      final bool isServerAck = await _remoteApiSource.uploadClotureZPayload(
        syncPayload: cloturePayload,
        jwtToken: jwtToken,
      );

      if (isServerAck) {
        final db = await _dbHelper.database;
        // 3. Règle métier : On flag la session comme synchronisée localement pour éviter les re-bonds
        await db.update(
          'cash_sessions',
          {'statut_sync': 1},
          where: 'id_session = ?',
          whereArgs: [idSession],
        );
        debugPrint("✅ [Sync Z] Clôture de session archivée et scellée sur le serveur cloud.");
        return true;
      }

      debugPrint("⚠️ [Sync Z] Le serveur distant a refusé la transaction financière.");
      return false;
    } catch (e) {
      debugPrint("🛑 [Sync Z] Échec critique d'assemblage ou de transmission réseau : $e");
      return false;
    }
  }

  /// Orchestre la synchronisation des données locales vers le serveur Cloud
  /// selon la règle stricte du MOP (Modèle Physique Opérationnel des Traitements)
  Future<bool> synchronizeLocalDataToCloud(String jwtToken) async {
    final db = await _dbHelper.database;

    try {
      // 1. Extraction physique de toutes les commandes non synchronisées
      final List<Map<String, dynamic>> rawOrders = await db.query(
        'orders',
        where: 'statut_sync = 0',
      );

      // 2. Extraction physique de toutes les transactions financières non synchronisées
      final List<Map<String, dynamic>> rawTransactions = await db.query(
        'financial_transactions',
        where: 'statut_sync = 0',
      );

      // S'il n'y a aucune nouvelle donnée locale à pousser, la synchro est virtuellement réussie
      if (rawOrders.isEmpty && rawTransactions.isEmpty) {
        debugPrint("💡 [Sync] Aucune donnée locale en attente de synchronisation.");
        return true;
      }

      // 3. Reconstruction de l'arbre complet des commandes avec leurs lignes d'articles
      final List<Map<String, dynamic>> populatedOrdersJson = [];
      
      for (var orderMap in rawOrders) {
        final idCde = orderMap['id_cde'] as int;
        
        // Extraction des lignes d'articles associées à cette commande
        // 🛠️ Aligné au modèle physique de la table order_items épurée (id_article, prix_facture)
        final List<Map<String, dynamic>> rawItems = await db.query(
          'order_items',
          where: 'id_cde = ?',
          whereArgs: [idCde],
        );

        // Conversion en structures de modèles de données (Data Models)
        final itemsModels = rawItems.map((item) => OrderItemModel.fromSql(item)).toList();
        final orderModel = OrderModel.fromSql(orderMap, itemsModels);
        
        populatedOrdersJson.add(orderModel.toJson());
      }

      // 4. Structuration du Payload JSON global conforme au MLC (Modèle Logique)
      final Map<String, dynamic> syncPayload = {
        "sync_metadata": {
          "sent_at": DateTime.now().toUtc().toIso8601String(),
        },
        "payload": {
          "orders": populatedOrdersJson,
          "transactions": rawTransactions, // Contient déjà les structures SQL plates
        }
      };

      debugPrint("📡 [Sync] Envoi d'un lot compressé au serveur Node.js...");

      // 5. Envoi au serveur distant via la passerelle HTTP
      final bool serverAck = await _remoteApiSource.uploadSyncBatch(
        syncPayload: syncPayload,
        jwtToken: jwtToken,
      );

      // 6. Application de la règle métier : Si succès, on passe le statut local à 1 dans SQLite
      if (serverAck) {
        await db.transaction((txn) async {
          // Mise à jour des commandes traitées
          await txn.update(
            'orders',
            {'statut_sync': 1},
            where: 'statut_sync = 0',
          );

          // Mise à jour des transactions financières traitées
          await txn.update(
            'financial_transactions',
            {'statut_sync': 1},
            where: 'statut_sync = 0',
          );
        });

        debugPrint("✅ [Sync] Lot synchronisé et consolidé sur le Cloud. Flag statut_sync mis à 1.");
        return true;
      }

      debugPrint("⚠️ [Sync] Le serveur distant n'a pas validé le lot ou a renvoyé une erreur.");
      return false;

    } catch (e) {
      debugPrint("🛑 [Sync] Erreur fatale durant le cycle physique d'assemblage : $e");
      return false;
    }
  }
}
