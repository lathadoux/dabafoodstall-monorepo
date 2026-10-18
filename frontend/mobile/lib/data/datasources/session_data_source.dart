// path: frontend/mobile/lib/data/datasources/session_data_source.dart
//import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';

final sessionDataSourceProvider = Provider<SessionDataSource>((ref) {
  return SessionDataSource();
});

class SessionDataSource {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Map<String, dynamic>> getSessionActive() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cash_sessions', 
      where: 'date_heure_clot IS NULL', 
      orderBy: 'id_session DESC', 
      limit: 1
    );
    return maps.isNotEmpty ? maps.first : {};
  }

  Future<int> ouvrirNouvelleSession({
    required int idTenant, 
    required int idUtilisateur, 
    required double fondCaisseInitial
  }) async {
    final db = await _dbHelper.database;
    return await db.insert('cash_sessions', {
      'id_tenant': idTenant,
      'id_user': idUtilisateur,
      'date_heure_ouv': DateTime.now().toIso8601String(),
      'date_heure_clot': null,
      'montant_init': fondCaisseInitial,
      'montant_theo': 0.00,
      'montant_reel': null,
      'statut_sync': 0,
    });
  }  /// 🧼 6. PURGES MANUELLES ET ROUTINES DE NETTOYAGE SYSTÈME
  Future<void> purgerAchatsSession() async {
    final db = await _dbHelper.database;
    await db.delete('orders', where: "statut_commande = 'achat'");
  }

  Future<void> purgerVentesSession() async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('order_items');
      await txn.delete('orders', where: "statut_commande = 'termine'");
    });
  }

  Future<void> executerClotureEtScellementSessionZ({
    required int idSessionActive,
    required int idGerant,
    required double cashPhysiqueSaisi,
    required double soldeTheoriqueAttendu,
    required double chiffreAffairesTheorique,
    required double totalAchatsCaisse,
    required double ecartFinal,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'cash_sessions', 
        {
          'date_heure_clot': DateTime.now().toIso8601String(), 
          'montant_reel': cashPhysiqueSaisi, 
          'montant_theo': soldeTheoriqueAttendu, 
          'id_user': idGerant, 
          'statut_sync': 0
        }, 
        where: 'id_session = ?', 
        whereArgs: [idSessionActive]
      );
      
      await txn.insert('rapports_z', {
        'id_session': idSessionActive,
        'id_tenant': 1,
        'id_user': idGerant,
        'total_ventes': chiffreAffairesTheorique,
        'total_achats': totalAchatsCaisse,
        'solde_especes': cashPhysiqueSaisi,
        'solde_mobile_money': 0.00,
        'ecart_caisse': ecartFinal,
        'signature_hash': 'LOCAL_SECURE_SIGNED_BY_$idGerant',
        'statut_sync': 0
      });

      await txn.insert('cash_sessions', {
        'id_tenant': 1,
        'id_user': idGerant,
        'date_heure_ouv': DateTime.now().toIso8601String(),
        'date_heure_clot': null,
        'montant_init': cashPhysiqueSaisi,
        'montant_theo': 0.00,
        'montant_reel': null,
        'statut_sync': 0,
      });
    });
  }

  Future<List<Map<String, dynamic>>> getHistoriqueSessionsCloses() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT cs.id_session, cs.date_heure_ouv, cs.date_heure_clot, cs.montant_init, cs.montant_theo, cs.montant_reel, u.nom_user as nom_gerant, rz.total_ventes, rz.total_achats, rz.ecart_caisse
      FROM cash_sessions cs
      LEFT JOIN rapports_z rz ON cs.id_session = rz.id_session
      JOIN users u ON rz.id_user = u.id_user
      WHERE cs.date_heure_clot IS NOT NULL
      ORDER BY cs.date_heure_clot DESC
    ''');
  }
}
