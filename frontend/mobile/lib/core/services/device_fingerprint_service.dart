import 'dart:convert';
import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceFingerprintService {
  static const _androidIdPlugin = AndroidId();
  static final _deviceInfoPlugin = DeviceInfoPlugin();

  /// Génère une DFP cryptographique unique, stable et immuable pour le terminal
  static Future<String> generateDFP() async {
    try {
      final AndroidDeviceInfo androidInfo = await _deviceInfoPlugin.androidInfo;
      
      // Récupération de l'Android ID matériel (Persiste tant que l'appareil n'est pas réinitialisé d'usine)
      final String? androidId = await _androidIdPlugin.getId();

      if (androidId == null || androidId.isEmpty) {
        throw Exception("Impossible de lire l'identifiant matériel Android.");
      }

      // Combinaison des vecteurs matériels atomiques de la tablette
      final String hardwarePayload = [
        androidId,
        androidInfo.brand,        // ex: "Samsung"
        androidInfo.model,        // ex: "Galaxy Tab A9"
        androidInfo.hardware,     // Référence du SoC/Processeur
        androidInfo.board,        // Nom de la carte mère
      ].join('|');

      // Hachage SHA-256 pour générer une signature propre de 64 caractères
      final bytes = utf8.encode(hardwarePayload);
      final digest = sha256.convert(bytes);

      return digest.toString();
    } catch (e) {
      throw Exception("Échec de la génération de l'empreinte matérielle DFP : $e");
    }
  }
}
