// path: frontend/mobile/lib/data/datasources/sales_data_source.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../../core/services/license_security_service.dart';

final salesDataSourceProvider = Provider<SalesDataSource>((ref) {
  return SalesDataSource();
});

class SalesDataSource {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> finalizePaymentAndService({
    required int sessionId,
    required int idUser, 
    required double totalAmount,
    required List<dynamic> cartItems,
  }) async {
    final db = await _dbHelper.database;
    try {
      await db.transaction((txn) async {
        final int generatedOrderId = await txn.insert('orders', {
          'id_session': sessionId,
          'id_user': idUser, 
          'statut_commande': 'termine',
          'statut_sync': 0,
          'date_heure_cde': DateTime.now().toIso8601String(),
          'total_amount': totalAmount,
          'mode_reglement': 'Cash',
        });

        for (var item in cartItems) {
          await txn.insert('order_items', {
            'id_cde': generatedOrderId,
            'id_article': item.idArticle,
            'qte_vendue': (item.qteVendue as num).toDouble(),
            'prix_facture': (item.prixFacture as num).toDouble(),
          });
        }

        await txn.insert('financial_transactions', {
          'id_session': sessionId,
          'id_user': idUser, 
          'id_cde': generatedOrderId,
          'type_trans': 'encaissement_vente',
          'montant_trans': totalAmount,
          'sens_flux': 'CREDIT',
          'mode_reglement': 'especes',
          'statut_sync': 0,
          'date_heure_trans': DateTime.now().toIso8601String(),
        });
      });
          // 🛡️ ANCRAGE IMMUABLE DE LA FLÈCHE DU TEMPS (Après commit réussi de la transaction SQLite)
      await LicenseSecurityService.updateSecureTimestamp();
      debugPrint("🐘 [Sales Material Shield] Vente scellée. Marqueur de sécurité temporel avancé.");
  
    } catch (e) {
      debugPrint("❌ [Sales Material Shield Erreur] Échec d'écriture de la vente : $e");
      rethrow;
    }
  }

  Future<void> suspendreCommande(int idCde) async {
    final db = await _dbHelper.database;
    await db.update('orders', {'statut_commande': 'en_attente'}, where: 'id_cde = ?', whereArgs: [idCde]);
  }

  Future<void> reactiverCommande(int idCde) async {
    final db = await _dbHelper.database;
    await db.update('orders', {'statut_commande': 'actif'}, where: 'id_cde = ?', whereArgs: [idCde]);
  }

  Future<List<Map<String, dynamic>>> getCommandesEnAttente(int idSession) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT o.id_cde, o.date_heure_cde, o.tag_commande, u.nom_user as nom_auteur, COUNT(oi.id_article) as nbr_articles, COALESCE(SUM(oi.qte_vendue * oi.prix_facture), 0.0) as total
      FROM orders o
      JOIN users u ON o.id_user = u.id_user
      LEFT JOIN order_items oi ON o.id_cde = oi.id_cde
      WHERE o.id_session = ? AND o.statut_commande = 'en_attente'
      GROUP BY o.id_cde
      ORDER BY o.date_heure_cde DESC
    ''', [idSession]);
  }

  Future<List<Map<String, dynamic>>> getItemsDeCommande(int idCde) async {
    final db = await _dbHelper.database;
    return await db.query('order_items', where: 'id_cde = ?', whereArgs: [idCde]);
  }

  Future<int> deleteOrderItems(int idCde) async {
    final db = await _dbHelper.database;
    return await db.delete('order_items', where: 'id_cde = ?', whereArgs: [idCde]);
  }

  Future<int> deleteOrder(int idCde) async {
    final db = await _dbHelper.database;
    return await db.delete('orders', where: 'id_cde = ?', whereArgs: [idCde]);
  }
}
