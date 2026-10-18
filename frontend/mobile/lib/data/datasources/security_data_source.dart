// path: frontend/mobile/lib/data/datasources/security_data_source.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';

// 🔑 PROVIDER RIVERPOD SÉPARÉ POUR LE COMPTOIR SÉCURITÉ
final securityDataSourceProvider = Provider<SecurityDataSource>((ref) {
  return SecurityDataSource();
});

class SecurityDataSource {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // 🔐 CLÉ SECRÈTE D'INFRASTRUCTURE (DABA_SECRET_SALT_2026)
  final _secretKey = enc.Key.fromUtf8('DabaFoodStallSecretKeySalt2026X'); 
  final _iv = enc.IV.fromLength(16);

  /// 📱 Génère une signature unique SHA-256 du smartphone physique
  Future<String> generateDeviceFingerprint() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String rawHardwareData = "";

    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        rawHardwareData = "${androidInfo.board}_${androidInfo.brand}_${androidInfo.device}_${androidInfo.hardware}_${androidInfo.id}_${androidInfo.model}";
      } else {
        rawHardwareData = "unknown_hardware_platform";
      }
    } catch (e) {
      rawHardwareData = "fallback_daba_device_fingerprint_2026";
    }

    final bytes = utf8.encode(rawHardwareData);
    return sha256.convert(bytes).toString();
  }

  /// 🔑 Récupère les paramètres de configuration du POS liés à la sécurité
  Future<Map<String, dynamic>> getSecurityParams() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('pos_params', limit: 1);
    return maps.isNotEmpty ? maps.first : {
      'id_tenant': 1, 
      'jours_utilises_cumules': 0
    };
  }

// À coller dans la classe SecurityDataSource (dans security_data_source.dart)

/// 🔐 Contrôle de sécurité à chaud : Vérifie le mot de passe du gestionnaire spécifié
Future<Map<String, dynamic>?> verifierPasswordManagerDynamique(String passwordSaisi, int idUserAttendu) async {
  final db = await _dbHelper.database;
  final List<Map<String, dynamic>> res = await db.query(
    'users', 
    where: "id_user = ? AND password_user = ? AND role_user IN ('manager', 'admin')", 
    whereArgs: [idUserAttendu, passwordSaisi], 
    limit: 1
  );
  return res.isNotEmpty ? res.first : null;
}



  /// 🔑 Initialise les jalons de sécurité lors du tout premier démarrage
  Future<void> enregistrerJalonsSecurite({
    required DateTime activation,
    required DateTime derniereUtil,
    required int cumul,
  }) async {
    final db = await _dbHelper.database;
    await db.update('pos_params', {
      'date_activation': activation.toIso8601String(),
      'date_derniere_utilisation': derniereUtil.toIso8601String(),
      'jours_utilises_cumules': cumul,
    }, where: 'id_param = 1');
  }

  /// 🔑 Incrémente de manière monotone le compteur de journées réelles d'utilisation
  Future<void> mettreAJourCompteurJours(DateTime dateUtil, int nouveauCumul) async {
    final db = await _dbHelper.database;
    await db.update('pos_params', {
      'jours_utilises_cumules': nouveauCumul,
      'date_derniere_utilisation': dateUtil.toIso8601String(),
    }, where: 'id_param = 1');
  }

  /// 🔑 Met à jour uniquement le timestamp horaire de la dernière utilisation
  Future<void> mettreAJourDerniereDateUtilisation(DateTime dateUtil) async {
    final db = await _dbHelper.database;
    await db.update('pos_params', {
      'date_derniere_utilisation': dateUtil.toIso8601String(),
    }, where: 'id_param = 1');
  }

  /// 🔐 Routine d'enregistrement d'une clé d'activation saisie par le gérant
  Future<bool> appliquerCleActivationDistante(String keyAlphanumerique) async {
    final db = await _dbHelper.database;
    try {
      final encrypter = enc.Encrypter(enc.AES(_secretKey));
      final decrypted = encrypter.decrypt(enc.Encrypted.fromBase64(keyAlphanumerique), iv: _iv);
      final Map<String, dynamic> licensePayload = json.decode(decrypted);

      final String hardwareIdInKey = licensePayload['hardware_id'] ?? '';
      final String localFingerprint = await generateDeviceFingerprint();

      if (hardwareIdInKey != localFingerprint) {
        debugPrint("🛑 [Licence Rejet] Tentative de partage frauduleux de clé détectée.");
        return false;
      }

      await db.update('pos_params', {
        'cle_activation_scellee': keyAlphanumerique,
      }, where: 'id_param = 1');

      return true;
    } catch (e) {
      debugPrint("🛑 [Licence Erreur] Format de clé corrompu ou invalide : $e");
      return false;
    }
  }

  /// ⏳ LE VERROU CENTRAL DE DÉMARRAGE : Contrôle Anti-Triche et validation de l'état d'essai
  Future<String> verifierSecuriteLicenceAuDemarrage() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    final List<Map<String, dynamic>> maps = await db.query('pos_params', limit: 1);
    if (maps.isEmpty) return "SANS_CONFIGURATION";

    final params = maps.first;
    final String? cleScellee = params['cle_activation_scellee'];
    final String? dateActivationStr = params['date_activation'];
    final String? dateDerniereUtilStr = params['date_derniere_utilisation'];
    int joursCumules = params['jours_utilises_cumules'] ?? 0;

    if (cleScellee != null && cleScellee.isNotEmpty) {
      try {
        final encrypter = enc.Encrypter(enc.AES(_secretKey));
        final decrypted = encrypter.decrypt(enc.Encrypted.fromBase64(cleScellee), iv: _iv);
        final Map<String, dynamic> licensePayload = json.decode(decrypted);

        final String localFingerprint = await generateDeviceFingerprint();
        if (licensePayload['hardware_id'] != localFingerprint) return "LICENCE_CLONEE";

        final dateFinLicence = DateTime.parse(licensePayload['date_expiration']);
        if (now.isAfter(dateFinLicence)) return "LICENCE_EXPIREE";

        if (dateDerniereUtilStr != null) {
          final dateDerniereUtil = DateTime.parse(dateDerniereUtilStr);
          if (now.isBefore(dateDerniereUtil)) return "ALERTE_TRICHE_HORLOGE";
        }

        await db.update('pos_params', {'date_derniere_utilisation': now.toIso8601String()}, where: 'id_param = 1');
        return "ACCES_PRO_VALIDATED";
      } catch (e) {
        return "LICENCE_CORROMPUE";
      }
    }

    if (dateActivationStr == null) {
      await db.update('pos_params', {
        'date_activation': now.toIso8601String(),
        'date_derniere_utilisation': now.toIso8601String(),
        'jours_utilises_cumules': 0
      }, where: 'id_param = 1');
      return "ESSAI_ACTIF";
    }

    final dateActivation = DateTime.parse(dateActivationStr);
    final dateDerniereUtil = DateTime.parse(dateDerniereUtilStr!);

    if (now.isBefore(dateDerniereUtil)) {
      return "ALERTE_TRICHE_HORLOGE";
    }

    final int differenceEnJours = now.difference(dateDerniereUtil).inDays;
    if (differenceEnJours >= 1) {
      joursCumules += differenceEnJours;
      await db.update('pos_params', {
        'jours_utilises_cumules': joursCumules,
        'date_derniere_utilisation': now.toIso8601String()
      }, where: 'id_param = 1');
    } else {
      await db.update('pos_params', {
        'date_derniere_utilisation': now.toIso8601String()
      }, where: 'id_param = 1');
    }

    final int joursCalendrierEcoules = now.difference(dateActivation).inDays;
    if (joursCalendrierEcoules > 30 || joursCumules > 30) {
      return "ESSAI_EXPIRE_BLOQUE";
    }

    return "ESSAI_ACTIF";
  }
}
