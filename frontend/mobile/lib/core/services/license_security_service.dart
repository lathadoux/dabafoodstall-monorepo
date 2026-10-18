// path: frontend/mobile/lib/services/license_security_service.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class LicenseSecurityService {
  static const String _keyLastValidTimestamp = "daba_last_valid_time";
  static const String _keyLicenseExpiration = "daba_license_expiry";
  static const String serverUrl = "hhttp://192.168.1.100:5000/api/license/activate-precompiled";

  /// 📥 EXTRACTION MANIFESTE : Lit l'empreinte d'enrôlement scellée dans l'APK
  static Future<String?> getEmbeddedFingerprint() async {
    try {
      final String response = await rootBundle.loadString('assets/config/identity.json');
      final data = jsonDecode(response);
      return data['enrolment_fingerprint'];
    } catch (e) {
      return null; // Pas de fichier injecté (Version Dev)
    }
  }

  /// 📡 CLOUD ACTIVATION : Tente l'enrôlement flash auprès du serveur
  static Future<bool> triggerAutoActivation(String enrolmentFingerprint) async {
    try {
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "enrolment_fingerprint": enrolmentFingerprint,
          "device_fingerprint": enrolmentFingerprint 
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // On sauvegarde l'expiration calculée dans les SharedPreferences de l'appareil
        await saveNewExpiration(data['expiry_date']);
        return true;
      }
      return false;
    } catch (e) {
      return false; // Serveur injoignable ou réseau absent
    }
  }

  /// Enregistre la date système courante comme jalon de sécurité temporel immuable.
  static Future<void> updateSecureTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final lastTime = prefs.getInt(_keyLastValidTimestamp) ?? 0;
    if (now > lastTime) {
      await prefs.setInt(_keyLastValidTimestamp, now);
    }
  }

  /// Analyse la cohérence de l'horloge système et l'état de la licence
  static Future<LicenseStatus> verifyLicenseIntegrity() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    
    final int lastValidMillis = prefs.getInt(_keyLastValidTimestamp) ?? 0;
    final DateTime lastValidTime = DateTime.fromMillisecondsSinceEpoch(lastValidMillis);

    // 1. 🛡️ VERROU ANTI-FRAUDE
    if (now.isBefore(lastValidTime)) {
      return LicenseStatus.fraudDetected;
    }

    final String? expiryStr = prefs.getString(_keyLicenseExpiration);
    if (expiryStr == null) {
      return LicenseStatus.unregistered; 
    }

    final DateTime expirationDate = DateTime.parse(expiryStr);

    // 2. 🔴 VERROU DE BRIDAGE
    if (now.isAfter(expirationDate)) {
      return LicenseStatus.expired;
    }

    // 3. 🟠 BANNIÈRE D'AVERTISSEMENT
    if (expirationDate.difference(now).inDays <= 3) {
      return LicenseStatus.warningNearExpiry;
    }

    // 4. 🟢 TOUT EST AU VERT
    return LicenseStatus.active;
  }

  /// Sauvegarde la nouvelle date d'expiration renvoyée par le serveur après un règlement
  static Future<void> saveNewExpiration(String isoExpirationDate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLicenseExpiration, isoExpirationDate);
    await prefs.setInt(_keyLastValidTimestamp, DateTime.now().millisecondsSinceEpoch);
  }
}

enum LicenseStatus {
  active,             
  warningNearExpiry,  
  expired,            
  fraudDetected,      
  unregistered        
}
