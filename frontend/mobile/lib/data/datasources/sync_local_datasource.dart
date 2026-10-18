// path: frontend/mobile/lib/data/datasources/sync_local_datasource.dart
//import 'dart:convert'; // Enlevé du commentaire, requis pour d'éventuels encodages
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import 'security_data_source.dart';

// 🔑 PROVIDER RIVERPOD SÉPARÉ POUR LA SOURCE DE DONNÉES DE SYNC
final syncLocalDataSourceProvider = Provider<SyncLocalDataSource>((ref) {
  return SyncLocalDataSource(ref);
});

class SyncLocalDataSource {
  final Ref _ref;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  SyncLocalDataSource(this._ref);

  /// 📊 Extraction 1 : Métadonnées d'en-tête de la Session
  Future<Map<String, dynamic>> _extraireMetadonneesSession(int idSession) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> res = await db.query(
      'cash_sessions',
      where: 'id_session = ?',
      whereArgs: [idSession],
      limit: 1,
    );
    if (res.isEmpty) throw Exception("Session #$idSession introuvable.");
    final s = res.first;
    return {
      'id_session_local': s['id_session'],
      'id_user_auteur': s['id_user'],
      'date_ouverture': s['date_heure_ouv'],
      'date_cloture': s['date_heure_clot'],
      'montant_initial': (s['montant_init'] as num).toDouble(),
      'montant_reel_compte': (s['montant_reel'] as num).toDouble(),
      'montant_theorique_attendu': (s['montant_theo'] as num).toDouble(),
    };
  }

  /// 📉 Extraction 2 : Rapport Z d'Audit
  Future<Map<String, dynamic>> _extraireRapportZ(int idSession) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> res = await db.query(
      'rapports_z',
      where: 'id_session = ?',
      whereArgs: [idSession],
      limit: 1,
    );
    if (res.isEmpty) throw Exception("Rapport Z non scellé pour la session #$idSession.");
    final r = res.first;
    return {
      'id_rapport_z_local': r['id_rapport_z'],
      'total_ventes': (r['total_ventes'] as num).toDouble(),
      'total_achats': (r['total_achats'] as num).toDouble(),
      'solde_especes': (r['solde_especes'] as num).toDouble(),
      'ecart_caisse': (r['ecart_caisse'] as num).toDouble(),
      'signature_hash': r['signature_hash']
    };
  }

  /// 🧾 Extraction 3 : Journal Analytique (Ventes ou Achats selon le statut)
  Future<List<Map<String, dynamic>>> _extraireJournalParStatut(int idSession, String statutCommande) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT u.nom_user, f.nom_famille, a.nom_article, a.unite_mesure, 
             SUM(oi.qte_vendue) as qte_totale, SUM(oi.qte_vendue * oi.prix_facture) as montant_total
      FROM order_items oi
      JOIN orders o ON oi.id_cde = o.id_cde
      JOIN articles a ON oi.id_article = a.id_article
      JOIN familles f ON a.id_famille = f.id_famille
      JOIN users u ON o.id_user = u.id_user
      WHERE o.id_session = ? AND o.statut_commande = ?
      GROUP BY u.id_user, f.id_famille, a.id_article
    ''', [idSession, statutCommande]);
  }

  /// 👥 Extraction 4 : Synthèse des Manquants RH de la session
  Future<List<Map<String, dynamic>>> _extraireManquantsRH(int idSession) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT u.id_user, u.nom_user, u.role_user, rz.ecart_caisse
      FROM rapports_z rz
      JOIN users u ON rz.id_user = u.id_user
      WHERE rz.id_session = ? AND rz.ecart_caisse < 0
    ''', [idSession]);
  }

  /// 🔀 Extraction 5 : Arbre Complet des Commandes et Lignes d'Articles (Orders & OrderItems)
  Future<List<Map<String, dynamic>>> _extraireFluxTransactionsBrutes(int idSession) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> orders = await db.query(
      'orders',
      where: 'id_session = ?',
    );

    List<Map<String, dynamic>> transactionsBundle = [];
    for (var o in orders) {
      final int idCde = o['id_cde'] as int;
      final List<Map<String, dynamic>> items = await db.rawQuery('''
        SELECT oi.id_article, a.nom_article, oi.qte_vendue, oi.prix_facture 
        FROM order_items oi
        JOIN articles a ON oi.id_article = a.id_article
        WHERE oi.id_cde = ?
      ''', [idCde]);

      transactionsBundle.add({
        'id_cde_local': idCde,
        'date_heure_cde': o['date_heure_cde'],
        'statut_commande': o['statut_commande'],
        'tag_commande': o['tag_commande'],
        'mode_reglement': o['mode_reglement'],
        'total_amount': (o['total_amount'] as num).toDouble(),
        'articles_details': items.map((i) => {
          'id_article': i['id_article'],
          'nom_article': i['nom_article'],
          'quantite': (i['qte_vendue'] as num).toDouble(),
          'prix_facture': (i['prix_facture'] as num).toDouble(),
        }).toList()
      });
    }
    return transactionsBundle;
  }

  /// 🚀 FONCTION CENTRALE : Orchestration de l'empaquetage #DABA_SYNC_PUSH_V1
  Future<Map<String, dynamic>> genererPayloadClotureZ(int idSession) async {
    // Récupération de l'empreinte matérielle autonome
    final String fingerprint = await _ref.read(securityDataSourceProvider).generateDeviceFingerprint();
    
    // 🔑 RÉCUPÉRATION SIMULÉE DES CONFIGURATIONS D'ACTIVATION MULTI-POS (À aligner avec vos Providers réels)
    // Nous lisons ici des valeurs de tests, remplacez par vos instances d'enrôlement réelles.
    const int tenantId = 10; 
    const int idPos = 2;

    // Appels individualisés asynchrones en parallèle pour maximiser la vitesse sur le terminal Android 13
    final resultats = await Future.wait([
      _extraireMetadonneesSession(idSession),
      _extraireRapportZ(idSession),
      _extraireJournalParStatut(idSession, 'termine'), // Ventes
      _extraireJournalParStatut(idSession, 'achat'),    // Achats
      _extraireManquantsRH(idSession),
      _extraireFluxTransactionsBrutes(idSession),
    ]);

    final Map<String, dynamic> sessionMeta = resultats[0] as Map<String, dynamic>;
    final int clotureParUserId = sessionMeta['id_user_auteur'] as int;

    return {
      'protocol_version': 'DABA_SYNC_PUSH_V1',
      'timestamp_export': DateTime.now().toIso8601String(),
      
      // 🔑 BLOC RACINE DE SÉCURITÉ CONFORME À POSTGRESQL 15
      'metadata': {
        'tenant_id': tenantId,
        'id_pos': idPos,
        'device_fingerprint': fingerprint,
        'id_session_local': idSession,
        'cloture_par_user_id': clotureParUserId,
        'date_cloture_locale': sessionMeta['date_cloture'] ?? DateTime.now().toIso8601String(),
      },
      
      'session_metadonnees': sessionMeta,
      'audit_rapport_z': resultats[1],
      'journaux_analytiques': {
        'journal_ventes': (resultats[2] as List).map((v) => {
          'vendeur': v['nom_user'], 'famille': v['nom_famille'], 'article': v['nom_article'],
          'unite': v['unite_mesure'], 'quantite_totale': (v['qte_totale'] as num).toDouble(),
          'montant_total': (v['montant_total'] as num).toDouble(),
        }).toList(),
        'journal_achats': (resultats[3] as List).map((a) => {
          'acheteur': a['nom_user'], 'famille': a['nom_famille'], 'article': a['nom_article'],
          'unite': a['unite_mesure'], 'quantite_totale': (a['qte_totale'] as num).toDouble(),
          'montant_total': (a['montant_total'] as num).toDouble(),
        }).toList(),
      },
      'synthese_manquants_rh': (resultats[4] as List).map((m) => {
        'id_user_responsable': m['id_user'], 'nom_responsable': m['nom_user'],
        'role_responsable': m['role_user'], 'montant_manquant': (m['ecart_caisse'] as num).toDouble().abs(),
      }).toList(),
      'flux_transactions': resultats[5]
    };
  }
}
