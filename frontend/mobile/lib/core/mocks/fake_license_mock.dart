import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class FakeLicenseMock {
  static const String _keyLastValidTimestamp = "daba_last_valid_time";
  static const String _keyLicenseExpiration = "daba_license_expiry";

  /// Injecte un abonnement fictif de production valide pour contourner le premier boot
  static Future<void> injectFakeSubscription() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Calcul d'une date d'expiration valide (Date actuelle + 30 jours)
    final DateTime fakeExpiry = DateTime.now().add(const Duration(days: 30));
    await prefs.setString(_keyLicenseExpiration, fakeExpiry.toIso8601String());

    // 2. Ancrage initial de la flèche du temps (Date d'aujourd'hui en millisecondes)
    final int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_keyLastValidTimestamp, currentTimestamp);

    debugPrint("🌱 [DabaPOS Mock] Injection d'un abonnement valide jusqu'au : ${fakeExpiry.toLocal()}");
  }
}
