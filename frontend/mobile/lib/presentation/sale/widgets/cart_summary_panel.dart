// path: frontend/mobile/lib/presentation/sale/widgets/cart_summary_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/datasources/sales_data_source.dart';
import '../../auth/auth_provider.dart'; // 🛠️ FIX IMPORT : Pour compiler currentOperatorProvider
import '../../sale/sale_provider.dart';
import '../../sale/widgets/payment_modal.dart';
import '../../../data/models/article_model.dart';
import '../../../data/models/order_model.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/services/pdf_service.dart';

class CartSummaryPanel extends ConsumerWidget {
  final double width;
  final int idUser;
  final int idSession;
  final SalesCartState cartState;

  const CartSummaryPanel({
    super.key,
    required this.width,
    required this.idUser,
    required this.idSession,
    required this.cartState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: width,
      color: AppTheme.cleanWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: AppTheme.darkCharcoal,
            child: const Text('🛒 Panier Actuel', style: TextStyle(color: AppTheme.cleanWhite, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          
          // Le panneau du milieu défile si les lignes d'articles s'accumulent
          Expanded(
            child: cartState.items.isEmpty
                ? const Center(child: Text('Panier vide', style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: cartState.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                        final item = cartState.items[index];
                        return ListTile(
                          dense: true,
                          title: Text(item.nomArticle ?? 'Article', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('${item.qteVendue} x ${item.prixFacture.toInt()} F', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: AppTheme.alertRed, size: 20),
                                onPressed: () => ref.read(salesCartProvider.notifier).removeArticle(ArticleModel(idArticle: item.idArticle, nomArticle: item.nomArticle ?? '', typeArticle: 'vente', prixUnitaire: item.prixFacture, idTenant: 1, uniteMesure: 'pcs')),
                              ),
                              Text('${item.qteVendue}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: AppTheme.successGreen, size: 20),
                                onPressed: () => ref.read(salesCartProvider.notifier).addArticle(ArticleModel(idArticle: item.idArticle, nomArticle: item.nomArticle ?? '', typeArticle: 'vente', prixUnitaire: item.prixFacture, idTenant: 1, uniteMesure: 'pcs')),
                              ),
                              const SizedBox(width: 8),
                              Text('${(item.qteVendue * item.prixFacture).toInt()} F', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                    },
                  ),
          ),

          // ===================================================================
          // 🛠️ FIX DE SÉCURITÉ GRAPHIQUE RESPONSIVE ANTI-OVERFLOW (CADRAGE SCELLÉ)
          // ===================================================================
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Occupe uniquement l'espace nécessaire
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL NET:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('${cartState.totalAmount.toInt()} F', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.successGreen)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700, 
                            foregroundColor: Colors.white, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.pause, size: 18),
                          label: const Text("SUSPENDRE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: cartState.items.isEmpty ? null : () {
                            final TextEditingController tagController = TextEditingController();

                            // 🔔 Ouverture de la boîte de saisie pour le vendeur
                            showDialog(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                title: const Text('🏷️ Aide-mémoire du Panier', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                content: TextField(
                                  controller: tagController,
                                  autofocus: true,
                                  textCapitalization: TextCapitalization.sentences,
                                  decoration: const InputDecoration(
                                    hintText: 'Ex: Chapeau bleu, Table 3, Emporté...',
                                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext),
                                    child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
                                    onPressed: () async {
                                      final String noteAideMemoire = tagController.text.trim();
                                      Navigator.pop(dialogContext); // On ferme la saisie

                                      try {
                                        final db = await DatabaseHelper.instance.database;
                                        
                                        // Execution transactionnelle enrichie de 'tag_commande'
                                        await db.transaction((txn) async {
                                          final int orderId = await txn.insert('orders', {
                                            'id_session': idSession,
                                            'date_heure_cde': DateTime.now().toIso8601String(),
                                            'statut_commande': 'en_attente',
                                            'statut_sync': 0,
                                            'id_user': idUser,
                                            'tag_commande': noteAideMemoire.isNotEmpty ? noteAideMemoire : null, // 💾 LE FIX METIER
                                          });

                                          final batchItems = txn.batch();
                                          for (var item in cartState.items) {
                                            batchItems.insert('order_items', {
                                              'id_cde': orderId,
                                              'id_article': item.idArticle,
                                              'qte_vendue': item.qteVendue,
                                              'prix_facture': item.prixFacture, 
                                            });
                                          }
                                          await batchItems.commit(noResult: true);
                                        });

                                        ref.read(salesCartProvider.notifier).clearCart();
                                        
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: Colors.orange,
                                            content: Text('📥 Mis en attente : "${noteAideMemoire.isNotEmpty ? noteAideMemoire : 'Panier sans nom'}"')
                                            ),
                                            );
                                            } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppTheme.alertRed, content: Text('Erreur : $e')));
                                            }
                                            },
                                            child: const Text('Suspendre', style: TextStyle(fontWeight: FontWeight.bold)),
                                            ),
                                            ],
                                            ),
                                            );
                                            },
                                            ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                            flex: 3,
                                            child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryAmber,
                                            foregroundColor: AppTheme.darkCharcoal,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.flash_on, size: 18),
                                            label: const Text('ENCAISSER DIRECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            onPressed: cartState.items.isEmpty ? null : () async {
                                            debugPrint("🎯 [DEBUG 1] Clic sur ENCAISSER DIRECT. Ouverture du BottomSheet...");
                                            await showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            builder: (modalContext) => PaymentModal(
                                            totalAmount: cartState.totalAmount,
                                            onPaymentValidated: () async {
                                            debugPrint("🏁 [DEBUG 2] Début du callback onPaymentValidated.");
                                            try {
                                            final double montantTotalAImprimer = cartState.totalAmount;
                                            final operatorState = ref.read(currentOperatorProvider);
                                            debugPrint("ℹ️ [DEBUG 3] Infos chargées -> User: $idUser, Session: $idSession, Montant: $montantTotalAImprimer");
                                            final orderDataMock = OrderModel(
                                            idCde: DateTime.now().millisecondsSinceEpoch % 10000,
                                            idSession: idSession,
                                            idUser: idUser,
                                            items: List.from(cartState.items),
                                            );
                                            debugPrint("⏳ [DEBUG 4] Lancement de salesDataSource.finalizePaymentAndService()...");
                                            // 1. Enregistrement transactionnel local Sqflite
                                            await ref.read(salesDataSourceProvider).finalizePaymentAndService(
                                            sessionId: idSession,
                                            idUser: idUser,
                                            totalAmount: montantTotalAImprimer,
                                            cartItems: cartState.items,
                                            );
                                            debugPrint("🚀 [DEBUG 5] localDataSource.finalizePaymentAndService() exécuté avec succès !");
                                            // 🔒 2. REINITIALISATION SÉCURISÉE DU PANIER (HORS-FLUX GRAPHIC)
                                            Future.microtask(() {
                                            debugPrint("🧼 [DEBUG 8] Lancement sécurisé de clearCart()...");
                                            ref.read(salesCartProvider.notifier).clearCart();
                                            debugPrint("🧼 [DEBUG 9] clearCart() exécuté avec succès hors-flux !");
                                            });
                                            // 3. Routage des impressions
                                            final modeActuel = ref.read(printerSettingsProvider);
                                            debugPrint("🖨️ [DEBUG 10] Mode d'impression détecté : $modeActuel");
                                            if (modeActuel == ModeImpression.papierThermique) {
                                            await PrinterService().imprimerRecuClient(orderDataMock, operatorState.nomUtilisateur ?? "Vendeur Stand", montantTotalAImprimer, 0.0);
                                            } else if (modeActuel == ModeImpression.documentPdf) {
                                            if (!context.mounted) return;
                                            await PdfService.instance.genererTicketPdf(
                                            idCommande: orderDataMock.idCde!,
                                            totalAmount: montantTotalAImprimer,
                                            items: orderDataMock.items,
                                            nomVendeur: operatorState.nomUtilisateur ?? "Vendeur Stand",
                                            nomPOS: operatorState.nomPOS
                                            );
                                            }
                                            debugPrint("🏁 [DEBUG 14] Fin complète du flux d'encaissement direct.");
                                            } catch (e, stacktrace) {
                                            debugPrint("💥 [DEBUG CRASH] Une exception a été levée lors de l'encaissement : $e");
                                            debugPrint("💥 [DEBUG STACKTRACE] Details : $stacktrace");
                                            }
                                            },
                                            ),
                                            );
                                            },
                                            ),
                                            ),
                                            ],
                                            ),
                                            ],
                                            ),
                                            ),
                                            ),
                                            ],
                                            ),
                                            );
                                            }
                                            }