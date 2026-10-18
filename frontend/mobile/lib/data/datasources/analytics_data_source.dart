// path: frontend/mobile/lib/data/datasources/analytics_data_source.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';

final analyticsDataSourceProvider = Provider<AnalyticsDataSource>((ref) {
  return AnalyticsDataSource();
});

class AnalyticsDataSource {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// 📊 EXTRACTION 1 : Calcule le solde net théorique en temps réel (Prise en charge de l'argument positionnel)
  Future<double> getSoldeCaisseTempsReel([int? idSessionOptionnelle]) async {
    final db = await _dbHelper.database;
    try {
      List<Map<String, dynamic>> result;
      if (idSessionOptionnelle != null) {
        result = await db.query(
          'cash_sessions',
          columns: ['montant_theo'],
          where: 'id_session = ?',
          whereArgs: [idSessionOptionnelle],
          limit: 1,
        );
      } else {
        result = await db.rawQuery('SELECT montant_theo FROM cash_sessions ORDER BY id_session DESC LIMIT 1');
      }
      if (result.isEmpty || result.first['montant_theo'] == null) return 0.0;
      return (result.first['montant_theo'] as num).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  /// 📊 EXTRACTION 2 : Rapport X de caisse
  Future<Map<String, dynamic>> calculerRapportX() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> sessionQuery = await db.query('cash_sessions', where: 'date_heure_clot IS NULL', orderBy: 'id_session DESC', limit: 1);
    if (sessionQuery.isEmpty) return {'statut': 'AUCUNE_SESSION'};
    
    final session = sessionQuery.first;
    final int idSession = session['id_session'] as int;
    final double montantInit = (session['montant_init'] as num).toDouble();
    
    final List<Map<String, dynamic>> queryVentes = await db.rawQuery('SELECT COALESCE(SUM(total_amount), 0.0) as total FROM orders WHERE id_session = ? AND statut_commande = "termine"', [idSession]);
    final List<Map<String, dynamic>> queryAchats = await db.rawQuery('SELECT COALESCE(SUM(total_amount), 0.0) as total FROM orders WHERE id_session = ?  AND statut_commande = "achat"', [idSession]);
    
    final double totalVentes = (queryVentes.first['total'] as num).toDouble();
    final double totalAchats = (queryAchats.first['total'] as num).toDouble();
    final double soldeEspecesTheorique = montantInit + totalVentes - totalAchats;
    
    return {
      'statut': 'OK',
      'id_session': idSession,
      'date_ouverture': session['date_heure_ouv'],
      'montant_init': montantInit,
      'total_ventes': totalVentes,
      'total_achats': totalAchats,
      'solde_especes_theo': soldeEspecesTheorique,
      'solde_mobile_theo': 0.0,
      'solde_total_theo': soldeEspecesTheorique,
    };
  }

  /// 📊 EXTRACTION 3 : Ventes ventilées (Surcharge tolérante pour préserver l'IHM)
  Future<List<Map<String, dynamic>>> getVentesVentilees({
    bool? deLaJourneeSeule, 
    required int idSessionCourante
  }) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT a.nom_article as designation, SUM(oi.qte_vendue) as quantite, SUM(oi.qte_vendue * oi.prix_facture) as total
      FROM order_items oi
      JOIN orders o ON oi.id_cde = o.id_cde
      JOIN articles a ON oi.id_article = a.id_article
      WHERE o.id_session = ? AND o.statut_commande = 'termine'
      GROUP BY a.nom_article
    ''', [idSessionCourante]);
  }

  /// 📊 EXTRACTION 4 : Achats ventilés
  Future<List<Map<String, dynamic>>> getAchatsVentiles({
    bool? deLaJourneeSeule, 
    required int idSessionCourante
  }) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT a.nom_article as designation, SUM(oi.qte_vendue) as quantite, SUM(oi.qte_vendue * oi.prix_facture) as total
      FROM order_items oi
      JOIN orders o ON oi.id_cde = o.id_cde
      JOIN articles a ON oi.id_article = a.id_article
      WHERE o.id_session = ? AND o.statut_commande = 'achat'
      GROUP BY a.nom_article
    ''', [idSessionCourante]);
  }

  /// 📊 EXTRACTION 5 : Règlements ventilés
  Future<List<Map<String, dynamic>>> getReglementsVentiles({
    bool? deLaJourneeSeule, 
    required int idSessionCourante
  }) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT mode_reglement, SUM(montant_trans) as total
      FROM financial_transactions
      WHERE id_session = ? AND sens_flux = 'DEBIT'
      GROUP BY mode_reglement
    ''', [idSessionCourante]);
  }

  /// 📊 EXTRACTION 6 : Grand livre des achats
  Future<List<Map<String, dynamic>>> getJournalAchatsConsolideSession() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> activeSession = await db.query('cash_sessions', where: 'date_heure_clot IS NULL', orderBy: 'id_session DESC', limit: 1);
    if (activeSession.isEmpty) return [];
    final int idSession = activeSession.first['id_session'] as int;
    return await db.rawQuery('''
      SELECT u.nom_user, f.nom_famille, a.nom_article, a.unite_mesure, 
             SUM(oi.qte_vendue) as qte_totale, SUM(oi.qte_vendue * oi.prix_facture) as montant_total
      FROM order_items oi
      JOIN orders o ON oi.id_cde = o.id_cde
      JOIN articles a ON oi.id_article = a.id_article
      JOIN familles f ON a.id_famille = f.id_famille
      JOIN users u ON o.id_user = u.id_user
      WHERE o.id_session = ? AND o.statut_commande = 'achat'
      GROUP BY u.id_user, f.id_famille, a.id_article
      ORDER BY u.nom_user ASC, f.nom_famille ASC, montant_total DESC
    ''', [idSession]);
  }

  /// 📊 EXTRACTION 7 : Comptage des bons d'achats
  Future<int> getNombreBonsAchatsSessionActive() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> activeSession = await db.query('cash_sessions', where: 'date_heure_clot IS NULL', orderBy: 'id_session DESC', limit: 1);
    if (activeSession.isEmpty) return 0;
    final int idSession = activeSession.first['id_session'] as int;
    final List<Map<String, dynamic>> res = await db.rawQuery('SELECT COUNT(id_cde) as total FROM orders WHERE id_session = ? AND statut_commande = "achat"', [idSession]);
    return res.first['total'] as int? ?? 0;
  }

  /// 📊 EXTRACTION 8 : Grand livre des ventes
  Future<List<Map<String, dynamic>>> getJournalVentesConsolideSession() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> activeSession = await db.query('cash_sessions', where: 'date_heure_clot IS NULL', orderBy: 'id_session DESC', limit: 1);
    if (activeSession.isEmpty) return [];
    final int idSession = activeSession.first['id_session'] as int;
    return await db.rawQuery('''
      SELECT u.nom_user, f.nom_famille, a.nom_article, a.unite_mesure,
             SUM(oi.qte_vendue) as qte_totale, SUM(oi.qte_vendue * oi.prix_facture) as montant_total
      FROM order_items oi
      JOIN orders o ON oi.id_cde = o.id_cde
      JOIN articles a ON oi.id_article = a.id_article
      JOIN familles f ON a.id_famille = f.id_famille
      JOIN users u ON o.id_user = u.id_user
      WHERE o.id_session = ? AND o.statut_commande = 'termine'
      GROUP BY u.id_user, f.id_famille, a.id_article
      ORDER BY u.nom_user ASC, f.nom_famille ASC, montant_total DESC
    ''', [idSession]);
  }

  /// 📊 EXTRACTION 9 : Comptage des tickets de caisse
  Future<int> getNombreTicketsSessionActive() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> activeSession = await db.query('cash_sessions', where: 'date_heure_clot IS NULL', orderBy: 'id_session DESC', limit: 1);
    if (activeSession.isEmpty) return 0;
    final int idSession = activeSession.first['id_session'] as int;
    final List<Map<String, dynamic>> res = await db.rawQuery('SELECT COUNT(id_cde) as total FROM orders WHERE id_session = ? AND statut_commande = "termine"', [idSession]);
    return res.first['total'] as int? ?? 0;
  }
}
