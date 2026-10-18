import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ActivationService {
  final _storage = const FlutterSecureStorage();
  final String serverUrl = "http://192.168.1";

  // 1. Récupérer ou générer la fingerprint unique de l'appareil
  Future<String> getDeviceFingerprint() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      // Combinaison de caractéristiques matérielles stables pour la fingerprint
      return "${androidInfo.brand}-${androidInfo.model}-${androidInfo.id}";
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? "unknown_ios_device";
    }
    return "unknown_platform";
  }

  // 2. Tenter d'activer l'APK auprès du serveur
  Future<bool> activateDevice(String activationCode) async {
    try {
      String fingerprint = await getDeviceFingerprint();

      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "activation_code": activationCode,
          "device_fingerprint": fingerprint,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Sauvegarde des données critiques de licence retournées par le serveur
        await _storage.write(key: "is_activated", value: "true");
        await _storage.write(key: "activation_code", value: activationCode);
        await _storage.write(key: "device_fingerprint", value: fingerprint);
        await _storage.write(key: "expiry_date", value: data["expiry_date"]); // Format ISO8601
        await _storage.write(key: "pos_type", value: data["pos_type"]); // Type de POS précompilé

        return true;
      }
      return false;
    } catch (e) {
      // Log d'erreur ou gestion de l'absence de réseau en local
      return false;
    }
  }

  // 3. Vérifier si l'application est déjà activée localement
  Future<bool> isDeviceActivated() async {
    String? status = await _storage.read(key: "is_activated");
    String? expiryStr = await _storage.read(key: "expiry_date");

    if (status == "true" && expiryStr != null) {
      DateTime expiryDate = DateTime.parse(expiryStr);
      // L'application est active uniquement si la date courante n'a pas dépassé l'expiration
      return DateTime.now().isBefore(expiryDate);
    }
    return false;
  }
}
