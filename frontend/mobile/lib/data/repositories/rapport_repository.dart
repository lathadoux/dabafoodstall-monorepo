// path: frontend/mobile/lib/data/repositories/rapport_repository.dart
import '../database/database_helper.dart';

class RapportRepository {
  const RapportRepository._();
  static const RapportRepository instance = RapportRepository._();

  /// 📊 RAPPORT X : Synthèse à chaud de la session active
  Future<Map<String, dynamic>> calculerRapportX() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> sessionQuery = await db.query('cash_sessions', where: 'date_heure_clot IS NULL', orderBy: 'id_session DESC', limit: 1);
    if (sessionQuery.isEmpty) return {'statut': 'AUCUNE_SESSION'};

    final session = sessionQuery.first;
    final int idSession = session['id_session'] as int;
    final double montantInit = (session['montant_init'] as num).toDouble();

    final List<Map<String, dynamic>> queryVentes = await db.rawQuery('SELECT COALESCE(SUM(total_amount), 0.0) as total FROM orders WHERE id_session = ? AND statut_commande = "termine"', [idSession]);
    final List<Map<String, dynamic>> queryAchats = await db.rawQuery('SELECT COALESCE(SUM(oi.prix_facture * oi.qte_vendue), 0.0) as total FROM order_items oi JOIN orders o ON oi.id_cde = o.id_cde WHERE o.id_session = ? AND o.statut_commande = "achat"', [idSession]);

    final double totalVentes = (queryVentes.first['total'] as num).toDouble();
    final double totalAchats = (queryAchats.first['total'] as num).toDouble();
    return {
      'statut': 'OK', 'id_session': idSession, 'date_ouverture': session['date_heure_ouv'], 'montant_init': montantInit,
      'total_ventes': totalVentes, 'total_achats': totalAchats, 'solde_especes_theo': montantInit + totalVentes - totalAchats,
      'solde_mobile_theo': 0.0, 'solde_total_theo': montantInit + totalVentes - totalAchats,
    };
  }

  /// 📊 RAPPORT Z : Statistiques de clôture théorique avant scellement
  Future<Map<String, dynamic>> calculerDonneesClotureTheorique(int idSession) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> queryVentes = await db.rawQuery('SELECT COALESCE(SUM(total_amount), 0.0) as total FROM orders WHERE id_session = ? AND statut_commande = "termine"', [idSession]);
    final List<Map<String, dynamic>> queryAchats = await db.rawQuery('SELECT COALESCE(SUM(oi.prix_facture * oi.qte_vendue), 0.0) as total FROM order_items oi JOIN orders o ON oi.id_cde = o.id_cde WHERE o.id_session = ? AND o.statut_commande = "achat"', [idSession]);
    final List<Map<String, dynamic>> resultSession = await db.query('cash_sessions', columns: ['montant_init'], where: 'id_session = ?', whereArgs: [idSession]);

    double init = resultSession.isNotEmpty ? (resultSession.first['montant_init'] as num).toDouble() : 0.0;
    double ventes = (queryVentes.first['total'] as num).toDouble();
    double achats = (queryAchats.first['total'] as num).toDouble();
    return {'fonds_initial': init, 'total_ventes': ventes, 'total_achats': achats, 'fonds_caisse_attendu': init + ventes - achats};
  }
}
