// path: frontend/mobile/lib/data/services/sync_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../datasources/local_data_source.dart';
import '../database/database_helper.dart'; 
import '../repositories/sync_repository.dart'; 
import '../../presentation/auth/auth_provider.dart'; // 🔑 Importation de currentOperatorProvider

// 🔑 L'UNIQUE SOURCE DE VÉRITÉ DU PROVIDER POUR TOUT LE PROJET
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});

class SyncService {
  final Ref _ref;
  final _dbHelper = DatabaseHelper.instance;

  SyncService(this._ref);

  // Adresse IP d'usine pour cibler l'hôte depuis l'émulateur Android
  static const String _baseUrl = "http://10.0.2.2:5000"; 

  /// 🚀 ROUTINE CENTRALE : Scanne SQLite et pousse tous les rapports Z au Cloud
  Future<Map<String, int>> executerSyncMontanteRapportsZ() async {
    int succesCount = 0;
    int echecCount = 0;

    try {
      final db = await _dbHelper.database;

      // 1. Extraction de toutes les sessions clôturées locales non encore répliquées au Cloud
      final List<Map<String, dynamic>> sessionsNonSync = await db.query(
        'cash_sessions',
        where: 'date_heure_clot IS NOT NULL AND statut_sync = 0',
        orderBy: 'id_session ASC',
      );

      if (sessionsNonSync.isEmpty) {
        debugPrint("📡 [Sync Service] Caisse à jour. Aucun rapport Z en attente.");
        return {'synchronisés': 0, 'échoués': 0};
      }

      debugPrint("📡 [Sync Service] Détection de ${sessionsNonSync.length} rapports Z à pousser...");

      // 2. Récupération des données contextuelles de l'opérateur connecté
      final operatorState = _ref.read(currentOperatorProvider);
      
      // Extraction ou simulation d'un jeton JWT d'authentification valide
      // En production, vous pourrez ajouter un champ 'token' dans votre classe OperatorState
      final String jwtToken = "JWT_TOKEN_MIGRATION_V1_VALIDATED_FOR_USER_${operatorState.idUser ?? 1}"; 

      // 3. Boucle de traitement séquentielle étanche pour garantir l'ordre chronologique
      for (var session in sessionsNonSync) {
        final int idSessionLocal = session['id_session'] as int;

        debugPrint("📤 [Sync Service] Expédition de la session #$idSessionLocal...");

        // Appel de la passerelle de transport du SyncRepository
        final bool isAckByServer = await _ref
            .read(syncRepositoryProvider)
            .synchronizeClotureZToCloud(idSessionLocal, jwtToken);

        if (isAckByServer) {
          succesCount++;
        } else {
          echecCount++;
          break; // En cas d'échec, on stoppe pour préserver la cohérence temporelle
        }
      }
    } catch (e) {
      debugPrint("🚨 [Sync Service Critique] Plantage de la routine montante : $e");
      rethrow;
    }

    return {'synchronisés': succesCount, 'échoués': echecCount};
  }

  /// 📥 ASPIRATION 1 : Télécharge le catalogue d'articles depuis PostgreSQL 15 vers SQLite
  Future<bool> importCatalogFromServer() async {
    const String url = "$_baseUrl/api/v1/sync/import"; 
    try {
      debugPrint("🛰️ [Sync V1] Aspiration du catalogue centralisé : $url");
      
      final operatorState = _ref.read(currentOperatorProvider);
      final String jwtToken = "JWT_TOKEN_MIGRATION_V1_VALIDATED_FOR_USER_${operatorState.idUser ?? 1}";

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> payload = json.decode(response.body);
        final int tenantId = payload['tenant_id'] as int? ?? 1;
        final String businessName = payload['business_name'] as String? ?? 'Stand Garba Actif';
        
        final List<Map<String, dynamic>> famillesMapped = (payload['familles'] as List).map((f) => {
          'id_famille': f['id_famille'] ?? f['id'],
          'nom_famille': f['nom_famille'] ?? f['nom'],
          'type_famille': f['type_famille'],
        }).toList();

        final List<Map<String, dynamic>> articlesMapped = (payload['articles'] as List).map((a) => {
          'id_article': a['id_article'] ?? a['id'],
          'id_famille': a['id_famille'] ?? a['famille_id'],
          'nom_article': a['nom_article'] ?? a['nom'],
          'type_article': a['type_article'],
          'prix_unitaire': a['prix_unitaire'] != null ? double.parse(a['prix_unitaire'].toString()) : null,
          'unite_mesure': a['unite_mesure'] ?? 'U',
        }).toList();

        await _ref.read(localDataSourceProvider).syncCatalogFromServer(
          tenantId: tenantId,
          businessName: businessName,
          famillesFromServer: famillesMapped,
          articlesFromServer: articlesMapped,
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("🛑 [Sync Exception] Échec d'aspiration du catalogue : $e");
      return false;
    }
  }

  /// 📥 ASPIRATION 2 : Télécharge les profils du personnel RH pour l'authentification hors-ligne
  Future<bool> pullUsersFromServer(int tenantId) async {
    final String url = "$_baseUrl/users?tenantId=$tenantId";
    try {
      debugPrint("📡 [Sync Pull] Récupération des profils collaborateurs : $url");
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = json.decode(response.body);
        if (decodedData['success'] == true) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("🚨 [Sync Fatal Error] Échec de communication avec l'API : $e");
      return false;
    }
  }
}
