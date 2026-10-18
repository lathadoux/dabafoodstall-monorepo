// path: frontend/mobile/lib/data/datasources/remote_api_source.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import 'security_data_source.dart';

class RemoteApiSource {
  final http.Client _client;
  final SecurityDataSource _securityDataSource; // 🔑 Liaison d'instance

  RemoteApiSource({
    http.Client? client,
    required SecurityDataSource securityDataSource,
  })  : _client = client ?? http.Client(),
        _securityDataSource = securityDataSource;

  /// 📡 #DABA_SYNC_PUSH_V1 : Acheminement du rapport Z complet de fin de journée
  Future<bool> uploadClotureZPayload({
    required Map<String, dynamic> syncPayload,
    required String jwtToken,
  }) async {
    final url = Uri.parse(AppConstants.uploadSessionEndpoint);

    try {
      // 🕵️ INTERCEPTEUR DE DIAGNOSTIC FORMATÉ (DUMP JSON EN CLAIR)
      const JsonEncoder encoderFormateur = JsonEncoder.withIndent('  ');
      final String jsonLisibleEnClair = encoderFormateur.convert(syncPayload);
      
      debugPrint("📦 [DUMP PAYLOAD #DABA_SYNC_PUSH_V1] Inspection du paquet JSON sortant :");
      debugPrint(jsonLisibleEnClair);
      debugPrint("---------------------------------------------------------------------");

      // 🔑 FIX : Accès via la variable d'instance privée injectée au constructeur
      final String hardwareFingerprint = await _securityDataSource.generateDeviceFingerprint();

      debugPrint("📤 [HTTP POST] Envoi du Rapport Z scellé vers $url...");
      
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $jwtToken',
          'x-terminal-imei': hardwareFingerprint, 
          'device-fingerprint': hardwareFingerprint,
        },
        body: jsonEncode(syncPayload),
      ).timeout(
        const Duration(seconds: AppConstants.networkTimeoutSeconds),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData['success'] == true;
      }
      
      debugPrint("⚠️ [Sync Z Refus Server] Statut anomal reçu : ${response.statusCode} - ${response.body}");
      return false;
    } catch (e) {
      debugPrint("🛑 Échec technique de communication lors du push : $e");
      return false;
    }
  }

  /// 📡 FLUX CONTINU : Émet le lot régulier de transactions locales vers le Cloud
  Future<bool> uploadSyncBatch({
    required Map<String, dynamic> syncPayload,
    required String jwtToken,
  }) async {
    final url = Uri.parse(AppConstants.syncDataEndpoint);

    try {
      // 🔑 FIX : Accès via la variable d'instance privée
      final String hardwareFingerprint = await _securityDataSource.generateDeviceFingerprint();

      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $jwtToken',
          'x-terminal-imei': hardwareFingerprint,
          'device-fingerprint': hardwareFingerprint,
        },
        body: jsonEncode(syncPayload),
      ).timeout(
        const Duration(seconds: AppConstants.networkTimeoutSeconds),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData['success'] == true;
      }
      
      return false;
    } catch (e) {
      debugPrint("⚠️ Échec technique de communication distante sur le flux : $e");
      return false;
    }
  }
}
