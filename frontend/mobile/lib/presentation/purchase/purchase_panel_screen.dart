import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/database_helper.dart';
import '../auth/auth_provider.dart'; // Pour lire le currentOperatorProvider
import '../../data/models/article_model.dart';
import '../sale/catalog_provider.dart'; // Consommation du localFamillesProvider

class PurchasePanelScreen extends ConsumerStatefulWidget {
  const PurchasePanelScreen({super.key});

  @override
  ConsumerState<PurchasePanelScreen> createState() => _PurchasePanelScreenState();
}

class _PurchasePanelScreenState extends ConsumerState<PurchasePanelScreen> {
  List<ArticleModel> _allArticles = [];
  bool _isLoading = true;
  int _activeSessionId = 1;

  @override
  void initState() {
    super.initState();
    _initialiserDonnees();
  }

  Future<void> _initialiserDonnees() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> activeSessionQuery = await db.rawQuery(
        'SELECT id_session FROM cash_sessions WHERE date_heure_clot IS NULL ORDER BY id_session DESC LIMIT 1'
      );
      if (activeSessionQuery.isNotEmpty) {
        _activeSessionId = activeSessionQuery.first['id_session'] as int;
      }

      final List<Map<String, dynamic>> maps = await db.query('articles');
      if (!mounted) return;
      setState(() {
        _allArticles = maps.map((m) => ArticleModel.fromSql(m)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPurchaseDialog(ArticleModel article) {
    final isAmountOnly = article.prixUnitaire == null;
    final inputController = TextEditingController();
    final qteController = TextEditingController(text: "1");

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isAmountOnly ? '💸 Achat : ${article.nomArticle}' : '📦 Approvisionner : ${article.nomArticle}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAmountOnly) ...[
                TextField(
                  controller: inputController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Montant total déboursé (FCFA)", suffixText: "F", border: OutlineInputBorder()),
                ),
              ] else ...[
                Text("Prix fixe catalogue : ${article.prixUnitaire!.toInt()} F / ${article.uniteMesure}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: qteController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Quantité achetée", border: OutlineInputBorder()),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed),
              onPressed: () async {
                double totalTransaction = 0.0;
                double qteHistorique = 1.0;

                if (isAmountOnly) {
                  final parsedAmount = double.tryParse(inputController.text);
                  if (parsedAmount == null || parsedAmount <= 0) return;
                  totalTransaction = parsedAmount;
                } else {
                  final parsedQte = double.tryParse(qteController.text);
                  if (parsedQte == null || parsedQte <= 0) return;
                  qteHistorique = parsedQte;
                  totalTransaction = article.prixUnitaire! * qteHistorique;
                }

                final db = await DatabaseHelper.instance.database;
                
                // 🔒 LECTURE DYNAMIQUE DE L'USER CONNECTÉ DANS RIVERPOD
                final operatorState = ref.read(currentOperatorProvider);
                final int currentUserId = operatorState.idUser ?? 1; // Repli ID 1 si non détecté

                // 🔑 CORRECTION SYMÉTRIQUE : Écriture dans le circuit orders / order_items
                await db.transaction((txn) async {
                  // 1. Création de l'en-tête du bon d'achat
                  final int idCde = await txn.insert('orders', {
                    'id_session': _activeSessionId,
                    'id_user': currentUserId,
                    'date_heure_cde': DateTime.now().toIso8601String(),
                    'statut_commande': 'achat', // Libère instantanément pour le journal et le X
                    'tag_commande': 'Dépense : ${article.nomArticle}',
                    'mode_reglement': 'Cash',
                    'total_amount': totalTransaction,
                    'statut_sync': 0,
                  });

                  // 2. Création de la ligne d'intrant associée
                  await txn.insert('order_items', {
                    'id_cde': idCde,
                    'id_article': article.idArticle,
                    'qte_vendue': qteHistorique,
                    'prix_facture': isAmountOnly ? totalTransaction : article.prixUnitaire!,
                  });

                  // 3. Optionnel : Doubler dans financial_transactions pour le suivi des flux de caisse bruts
                  await txn.insert('financial_transactions', {
                    'id_session': _activeSessionId,
                    'id_user': currentUserId,
                    'id_cde': idCde,
                    'id_article_achat': article.idArticle,
                    'type_trans': 'achat_direct',
                    'montant_trans': totalTransaction,
                    'sens_flux': 'DEBIT',
                    'mode_reglement': 'especes',
                    'qte_achat_historique': qteHistorique,
                    'statut_sync': 0,
                  });
                });
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppTheme.darkCharcoal, 
                    content: Text('💸 Dépense enregistrée par ${operatorState.nomUtilisateur ?? "Auteur"} : -${totalTransaction.toInt()} F')
                  ),
                );
              },

              child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final famillesAsync = ref.watch(localFamillesProvider);
    // Filtrage des articles de type achat
    final purchaseArticles = _allArticles;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Panneau d\'Achats & Dépenses'),
        backgroundColor: AppTheme.darkCharcoal,
        foregroundColor: AppTheme.cleanWhite,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber))
          : famillesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber)),
              error: (err, stack) => Center(child: Text('🛑 Erreur : $err')),
              data: (allFamilles) {
                // 🔒 FILTRAGE STRICT SUR type_famille : Uniquement les familles d'ACHAT
                final purchaseFamilles = allFamilles.where((f) => f.typeFamille == 'achat' && f.idFamille != 10).toList();

                if (purchaseArticles.isEmpty || purchaseFamilles.isEmpty) {
                  return const Center(child: Text('💸 Aucun article ou famille d\'achat disponible.'));
                }

                return DefaultTabController(
                  length: purchaseFamilles.length,
                  child: Column(
                    children: [
                      Container(
                        color: Colors.blue.shade900,
                        child: TabBar(
                          isScrollable: true,
                          indicatorColor: AppTheme.primaryAmber,
                          labelColor: AppTheme.primaryAmber,
                          unselectedLabelColor: Colors.white60,
                          tabs: purchaseFamilles.map((f) => Tab(text: f.nomFamille.toUpperCase())).toList(),
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: purchaseFamilles.map((famille) {
                            final articlesDeLaFamille = purchaseArticles.where((a) => a.idFamille == famille.idFamille).toList();

                            if (articlesDeLaFamille.isEmpty) {
                              return const Center(child: Text('ℹ️ Aucun article d\'achat dans cette famille.'));
                            }

                            return GridView.builder(
                              padding: const EdgeInsets.all(10),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.3,
                              ),
                              itemCount: articlesDeLaFamille.length,
                              itemBuilder: (context, index) {
                                final article = articlesDeLaFamille[index];
                                final isVariable = article.prixUnitaire == null;

                                return Card(
                                  color: AppTheme.cleanWhite,
                                  elevation: 2,
                                  child: InkWell(
                                    onTap: () => _showPurchaseDialog(article),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(article.nomArticle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 8),
                                          Text(isVariable ? "Montant libre" : "${article.prixUnitaire!.toInt()} F", style: TextStyle(color: isVariable ? Colors.purple : Colors.blue.shade800, fontWeight: FontWeight.bold)),
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
            ),
    );
  }
}