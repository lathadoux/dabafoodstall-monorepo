import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class LicenseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Ecrase et flash la configuration de licence locale reçue du serveur cloud
  Future<void> flashLicenseConfig(Map<String, dynamic> jsonResponse) async {
    final Database db = await _dbHelper.database;
    final String expiresAt = jsonResponse['expires_at'] as String;
    final String status = jsonResponse['status'] as String;
    final Map<String, dynamic> features = jsonResponse['features'] as Map<String, dynamic>;

    await db.transaction((txn) async {
      // Nettoyage de l'ancien état flashé
      await txn.delete('local_license_config');

      // Insertion des nouveaux drapeaux de fonctionnalités
      final List<Map<String, String>> featureRows = [
        {'key': 'allow_backup', 'val': features['allow_backup'] == true ? '1' : '0'},
        {'key': 'allow_backoffice', 'val': features['allow_backoffice'] == true ? '1' : '0'},
        {'key': 'allow_realtime_x', 'val': features['allow_realtime_x'] == true ? '1' : '0'},
      ];

      for (var row in featureRows) {
        await txn.rawInsert('''
          INSERT INTO local_license_config (feature_key, is_enabled, expires_at, status)
          VALUES (?, ?, ?, ?)
        ''', [row['key'], int.parse(row['val']!), expiresAt, status]);
      }
    });
  }

  /// Garde fou local : Vérifie si une option spécifique est souscrite et valide
  Future<bool> isFeatureAllowed(String featureKey) async {
    final Database db = await _dbHelper.database;
    
    final List<Map<String, dynamic>> result = await db.query(
      'local_license_config',
      where: 'feature_key = ?',
      whereArgs: [featureKey],
    );

    if (result.isEmpty) return false;

    final Map<String, dynamic> row = result.first;
    
    // Contrôle double de sécurité sur l'horloge locale de l'appareil
    if (row['status'] != 'ACTIVE') return false;
    
    final DateTime expireDate = DateTime.parse(row['expires_at'] as String);
    if (DateTime.now().isAfter(expireDate)) {
      return false; // Licence expirée sur le terminal
    }

    return (row['is_enabled'] as int) == 1;
  }
}
