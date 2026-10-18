// path: frontend/mobile/lib/presentation/manager/manager_purchase_article_config_screen.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/article_model.dart';

class ManagerPurchaseArticleConfigScreen extends StatefulWidget {
  const ManagerPurchaseArticleConfigScreen({super.key});

  @override
  State<ManagerPurchaseArticleConfigScreen> createState() => _ManagerPurchaseArticleConfigScreenState();
}

class _ManagerPurchaseArticleConfigScreenState extends State<ManagerPurchaseArticleConfigScreen> {
  List<ArticleModel> _articlesAchats = [];
  List<Map<String, dynamic>> _famillesAchats = []; // 🛠️ Stockage des familles d'achat dynamiques
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshPurchaseCatalog();
  }

  /// Lecture combinée des familles d'ACHAT et des articles configurés en base locale SQLite
  Future<void> _refreshPurchaseCatalog() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      
      // 1. 🔒 FILTRAGE STRICT : Charger uniquement les familles d'ACHAT
      final List<Map<String, dynamic>> famMaps = await db.query(
        'familles', 
        where: 'type_famille = ?', 
        whereArgs: ['achat'], 
        orderBy: 'id_famille ASC',
      );
      
      // 2. Charger l'ensemble des articles de type achat
      final List<Map<String, dynamic>> maps = await db.query(
        'articles',
        where: 'type_article = ?',
        whereArgs: ['achat'],
      );
      
      if (!mounted) return;
      setState(() {
        _famillesAchats = famMaps;
        _articlesAchats = maps.map((m) => ArticleModel.fromSql(m)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("🛑 [Manager Purchase Catalog] Erreur : $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Boîte de dialogue pour modifier le prix d'achat ou le libellé d'un ingrédient
  void _showEditDialog(ArticleModel article) {
    // Si le prix d'achat initial est nul (achat au montant), on affiche une chaîne vide
    final String initialPriceText = article.prixUnitaire != null ? article.prixUnitaire!.toInt().toString() : "";
    final priceController = TextEditingController(text: initialPriceText);
    final nameController = TextEditingController(text: article.nomArticle);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🛠️ Configurer l\'achat : ${article.nomArticle}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Désignation de la ressource"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Prix d'achat unitaire par défaut (FCFA)", 
                suffixText: "F",
                hintText: "Laisser vide si prix variable au marché"
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAmber),
            onPressed: () async {
              final String finalName = nameController.text.trim();
              if (finalName.isEmpty) return;

              // Gestion du prix optionnel pour les matières au vrac/montant
              double? newPrice;
              if (priceController.text.trim().isNotEmpty) {
                newPrice = double.tryParse(priceController.text.trim());
                if (newPrice == null || newPrice < 0) return;
              }

              final db = await DatabaseHelper.instance.database;
              
              // 💾 MISE À JALON DIRECTE DANS SQLITE LOCAL
              await db.update(
                'articles',
                {
                  'nom_article': finalName,
                  'prix_unitaire': newPrice, // Peut être NULL pour les achats au montant
                },
                where: 'id_article = ?',
                whereArgs: [article.idArticle],
              );

              if (!context.mounted) return;
              Navigator.pop(context);
              _refreshPurchaseCatalog(); // Rechargement à chaud instantané
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppTheme.successGreen, 
                  content: Text('✅ Prix et libellés d\'achat synchronisés localement !')
                ),
              );
            },
            child: const Text('Sauvegarder', style: TextStyle(color: AppTheme.darkCharcoal)),
          ),
        ],
      ),
    );
  }

  /// Action de retrait d'un article de la liste des dépenses autorisées
  Future<void> _deleteArticle(int idArticle) async {
    final db = await DatabaseHelper.instance.database;
    try {
      await db.delete('articles', where: 'id_article = ?', whereArgs: [idArticle]);
      _refreshPurchaseCatalog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppTheme.alertRed, content: Text('🔴 Ressource retirée du panneau d\'achat.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('Impossible de supprimer : cet article est lié à un historique de dépenses.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _famillesAchats.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuration Prix d\'Achat')),
        body: const Center(child: Text("Aucune famille d'articles d'achat configurée. Veuillez vérifier le catalogue.")),
      );
    }

    return _isLoading
        ? Scaffold(
            backgroundColor: Colors.grey.shade100,
            appBar: AppBar(title: const Text('Configuration Prix d\'Achat')),
            body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber)),
          )
        : DefaultTabController(
            length: _famillesAchats.length,
            child: Scaffold(
              backgroundColor: Colors.grey.shade100,
              appBar: AppBar(
                title: const Text('Configuration Prix d\'Achat'),
                bottom: TabBar(
                  isScrollable: true,
                  indicatorColor: AppTheme.primaryAmber,
                  labelColor: AppTheme.primaryAmber,
                  unselectedLabelColor: Colors.white70,
                  tabs: _famillesAchats.map((famille) {
                    final String nomFamille = famille['nom_famille'] ?? 'Inconnu';
                    return Tab(
                      child: Text(
                        nomFamille.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    );
                  }).toList(),
                ),
              ),
              body: TabBarView(
                children: _famillesAchats.map((famille) {
                  final int idFamille = famille['id_famille'];
                  
                  // Filtrage strict en mémoire des articles d'achat liés à ce volet
                  final List<ArticleModel> articlesFiltres = _articlesAchats
                      .where((article) => article.idFamille == idFamille)
                      .toList();

                  if (articlesFiltres.isEmpty) {
                    return const Center(
                      child: Text(
                        'Aucun ingrédient référencé dans cette famille.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: articlesFiltres.length,
                    itemBuilder: (context, index) {
                      final article = articlesFiltres[index];

                      return Card(
                        color: AppTheme.cleanWhite,
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey,
                            child: Text(
                              article.nomArticle.isNotEmpty ? article.nomArticle[0].toUpperCase() : '⚙️', 
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(article.nomArticle, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            article.prixUnitaire != null && article.prixUnitaire! > 0
                                ? 'Coût usine : ${article.prixUnitaire!.toInt()} F / Unité : ${article.uniteMesure}'
                                : 'Coût : Variable (Saisie au montant) / Unité : ${article.uniteMesure}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
    onPressed: () => _showEditDialog(article),
      ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.alertRed),
            onPressed: () => _deleteArticle(article.idArticle!),
                    ),
                    ],
                    ),
                    ),
                    );
                    },
                    );
                    }).toList(),
                    ),
                    ),
              );
        }
}