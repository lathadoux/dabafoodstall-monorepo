import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../catalog_provider.dart';
import '../sale_provider.dart';

class ArticleGridPanel extends ConsumerWidget {
  const ArticleGridPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allArticles = ref.watch(localCatalogProvider);
    final famillesAsync = ref.watch(famillesVenteVisiblesProvider);

    return famillesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber)),
      error: (err, stack) => Center(child: Text('🛑 Erreur familles : $err')),
      data: (allFamilles) {
        // 🔒 FILTRAGE V1 : Uniquement les familles affectées au flux VENTE
        final salesFamilles = allFamilles.where((f) => f.typeFamille == 'vente').toList();
        final salesArticles = allArticles.where((a) => a.typeArticle == 'vente').toList();

        if (salesArticles.isEmpty || salesFamilles.isEmpty) {
          return const Center(
            child: Text('🍔 Aucun article ou famille de vente disponible.\nLancez l\'aspiration réseau.', textAlign: TextAlign.center),
          );
        }

        return DefaultTabController(
          length: salesFamilles.length,
          child: Column(
            children: [
              // 📑 BANDEAU DES ONGLETS DE FAMILLES (Garba, Attiéké, Boissons etc.)
              Container(
                color: AppTheme.darkCharcoal,
                child: TabBar(
                  isScrollable: true,
                  indicatorColor: AppTheme.primaryAmber,
                  labelColor: AppTheme.primaryAmber,
                  unselectedLabelColor: Colors.white60,
                  tabs: salesFamilles.map((f) => Tab(text: f.nomFamille.toUpperCase())).toList(),
                ),
              ),
              // 🎰 GRILLE DES ARTICLES FILTRÉE PAR ONGLET ACTIVÉ
              Expanded(
                child: TabBarView(
                  children: salesFamilles.map((famille) {
                    // Filtrage des articles appartenant strictement à cet ID de famille
                    final articlesDeLaFamille = salesArticles.where((a) => a.idFamille == famille.idFamille).toList();

                    if (articlesDeLaFamille.isEmpty) {
                      return const Center(child: Text('ℹ️ Aucun article dans cette famille.'));
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.3,
                      ),
                      itemCount: articlesDeLaFamille.length,
                      itemBuilder: (context, index) {
                        final article = articlesDeLaFamille[index];
                        return Card(
                          color: AppTheme.cleanWhite,
                          elevation: 2,
                          child: InkWell(
                            onTap: () => ref.read(salesCartProvider.notifier).addArticle(article),
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(article.nomArticle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 6),
                                  Text('${article.prixUnitaire!.toInt()} F', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
