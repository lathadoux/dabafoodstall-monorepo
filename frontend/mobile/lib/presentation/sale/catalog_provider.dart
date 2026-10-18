import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/article_model.dart';

// Modèle temporaire ou structure pour lier les familles lues de SQLite
class FamilleModel {
  final int idFamille;
  final String nomFamille;
  final String typeFamille;

  FamilleModel({required this.idFamille, required this.nomFamille, required this.typeFamille});

  factory FamilleModel.fromSql(Map<String, dynamic> map) {
    return FamilleModel(
      idFamille: map['id_famille'] as int,
      nomFamille: map['nom_famille'] as String,
      typeFamille: map['type_famille'] as String,
    );
  }
}

class LocalCatalogNotifier extends StateNotifier<List<ArticleModel>> {
  LocalCatalogNotifier() : super([]) {
    loadSalesArticles();
  }

  Future<void> loadSalesArticles() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> maps = await db.query('articles');
      state = maps.map((m) => ArticleModel.fromSql(m)).toList();
    } catch (e) {
      state = [];
    }
  }
}

// Provider des articles
final localCatalogProvider = StateNotifierProvider<LocalCatalogNotifier, List<ArticleModel>>((ref) {
  return LocalCatalogNotifier();
});

// ⚡ NOUVEAU PROVIDER : Extrait les familles dynamiquement pour les onglets TabBar
final localFamillesProvider = FutureProvider<List<FamilleModel>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final List<Map<String, dynamic>> maps = await db.query('familles');
  return maps.map((m) => FamilleModel.fromSql(m)).toList();
});


// 📱 ⚡ NOUVEAU PROVIDER FILTRÉ : Alimente les onglets de vente du vendeur (Exclut le coffre)
final famillesVenteVisiblesProvider = Provider<AsyncValue<List<FamilleModel>>>((ref) {
  final toutesLesFamillesAsync = ref.watch(localFamillesProvider);
  
  return toutesLesFamillesAsync.whenData((liste) => liste
      .where((f) => f.typeFamille == 'vente' && f.idFamille != 10) // 🛡️ SÉCURITÉ : id_famille 10 masqué
      .toList());
});