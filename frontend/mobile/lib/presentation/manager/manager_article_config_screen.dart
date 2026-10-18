import 'package:flutter/material.dart';
//import 'package:sqflite/sqflite.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/article_model.dart';

class ManagerArticleConfigScreen extends StatefulWidget {
  const ManagerArticleConfigScreen({super.key});

  @override
  State<ManagerArticleConfigScreen> createState() => _ManagerArticleConfigScreenState();
}

class _ManagerArticleConfigScreenState extends State<ManagerArticleConfigScreen> {
  List<ArticleModel> _articles = [];
  List<Map<String, dynamic>> _familles = []; // 🛠️ Stockage des familles de vente dynamiques
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshCatalog();
  }

  /// Lecture combinée des familles de Vente et des articles configurés en base locale SQLite
  Future<void> _refreshCatalog() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      
      // 1. 🔒 FILTRAGE STRICT : Charger uniquement les familles de VENTE
      final List<Map<String, dynamic>> famMaps = await db.query(
        'familles', 
        where: 'type_famille = ? AND id_famille != ?', 
        whereArgs: ['vente', 10], 
        orderBy: 'id_famille ASC',
      );
      
      // 2. Charger l'ensemble des articles
      final List<Map<String, dynamic>> maps = await db.query('articles');
      
      if (!mounted) return;
      setState(() {
        _familles = famMaps;
        // 🛠️ FIX TYPE NULL : Utilisation directe du constructeur fromSql durci
        _articles = maps.map((m) => ArticleModel.fromSql(m)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("🛑 [Manager Catalog] Erreur : $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Boîte de dialogue pour modifier le prix ou les informations d'un article
  void _showEditDialog(ArticleModel article) {
    final priceController = TextEditingController(text: article.prixUnitaire?.toInt().toString());
    final nameController = TextEditingController(text: article.nomArticle);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🛠️ Paramétrer : ${article.nomArticle}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Désignation de l'article"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Prix de vente unitaire (FCFA)", suffixText: "F"),
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
              final double? newPrice = double.tryParse(priceController.text);
              if (newPrice == null || newPrice < 0 || nameController.text.trim().isEmpty) return;

              final db = await DatabaseHelper.instance.database;
              
              // 💾 MISE À JOUR DIRECTE DE LA TABLE ARTICLES DANS SQLITE
              await db.update(
                'articles',
                {
                  'nom_article': nameController.text.trim(),
                  'prix_unitaire': newPrice,
                },
                where: 'id_article = ?',
                whereArgs: [article.idArticle],
              );

              if (!context.mounted) return;
              Navigator.pop(context);
              _refreshCatalog(); // Rechargement dynamique instantané
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(backgroundColor: AppTheme.successGreen, content: Text('✅ Catalogue mis à jour avec succès !')),
              );
            },
            child: const Text('Sauvegarder', style: TextStyle(color: AppTheme.darkCharcoal)),
          ),
        ],
      ),
    );
  }

  /// Action de retrait définitif ou suppression de l'étal
  Future<void> _deleteArticle(int idArticle) async {
    final db = await DatabaseHelper.instance.database;
    try {
      await db.delete('articles', where: 'id_article = ?', whereArgs: [idArticle]);
      _refreshCatalog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppTheme.alertRed, content: Text('🔴 Article retiré de la vente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('Impossible de supprimer : l\'article est lié à un historique de vente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cas de secours : Si aucune famille n'est encore synchronisée en local
    if (!_isLoading && _familles.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestion du Panneau d\'Articles')),
        body: const Center(child: Text("Aucune famille d'articles de vente disponible. Veuillez synchroniser.")),
      );
    }

    return _isLoading
        ? Scaffold(
            backgroundColor: Colors.grey.shade100,
            appBar: AppBar(title: const Text('Gestion du Panneau d\'Articles')),
            body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber)),
          )
        : DefaultTabController(
            length: _familles.length,
            child: Scaffold(
              backgroundColor: Colors.grey.shade100,
              appBar: AppBar(
                title: const Text('Gestion du Panneau d\'Articles'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppTheme.successGreen, size: 28),
                    tooltip: 'Ajouter un article',
                    onPressed: () {
                      // Option d'ajout rapide à implémenter en V2
                    },
                  )
                ],
                // 🛠️ IMPLÉMENTATION DES VOLETS DE NAVIGATION (VENTE)
                bottom: TabBar(
                  isScrollable: true,
                  indicatorColor: AppTheme.primaryAmber,
                  labelColor: AppTheme.primaryAmber,
                  unselectedLabelColor: Colors.white70,
                  tabs: _familles.map((famille) {
                    final String nomFamille = famille['nom_famille'] ?? famille['nom_family'] ?? 'Inconnu';
                    return Tab(
                      child: Text(
                        nomFamille.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // 🔄 CORPS FILTRÉ PAR VOLET ACTIF
              body: TabBarView(
                children: _familles.map((famille) {
                  final int idFamille = famille['id_famille'];
                  
                  // Filtrage strict en mémoire des articles du volet courant
                  final List<ArticleModel> articlesFiltres = _articles
                      .where((article) => article.idFamille == idFamille)
                      .toList();

                  if (articlesFiltres.isEmpty) {
                    return const Center(
                      child: Text(
                        'Aucun article dans cette famille.',
                        style: TextStyle(color: Colors.grey, fontSize: 15),
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
                            backgroundColor: AppTheme.primaryAmber,
                            child: Text(
                              article.nomArticle.isNotEmpty ? article.nomArticle[0].toUpperCase() : '?', 
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(article.nomArticle, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            article.prixUnitaire != null
                                ? 'Prix : ${article.prixUnitaire!.toInt()} F / Unité : ${article.uniteMesure}'
                                : 'Prix : Variable (Au montant) / Unité : ${article.uniteMesure}',
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