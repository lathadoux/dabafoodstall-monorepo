// path: frontend/mobile/lib/presentation/sale/widgets/pending_orders_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/sales_data_source.dart';

import '../../../data/models/order_model.dart'; // 🛠️ FIX IMPORT : Pour compiler OrderItemModel
import '../../sale/sale_provider.dart';

class PendingOrdersModal {
  static void afficher(BuildContext context, WidgetRef ref, int activeSessionId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (modalContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('📥 Commandes en Attente de Règlement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal)),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: ref.read(salesDataSourceProvider).getCommandesEnAttente(activeSessionId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Plus aucun panier en attente."));
                  
                  return Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final cde = snapshot.data![index];
                        final int idCde = cde['id_cde'] as int;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.access_time, color: Colors.white)),
                            title: Text(
                              // 🛠️ AFFICHAGE DU TAG DYNAMIQUE : Si l'aide mémoire est renseigné, on l'affiche en priorité
                              cde['tag_commande'] != null && cde['tag_commande'].toString().isNotEmpty
                                  ? "🏷️ ${cde['tag_commande']}"
                                  : "Commande #$idCde",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              cde['tag_commande'] != null && cde['tag_commande'].toString().isNotEmpty
                                  ? "Commande #$idCde • ${cde['nbr_articles']} articles • ${cde['date_heure_cde'].toString().substring(11, 16)}"
                                  : "${cde['nbr_articles']} articles • ${cde['date_heure_cde'].toString().substring(11, 16)}",
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("${(cde['total'] as num).toInt()} F", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.alertRed),
                                  onPressed: () async {
                                    final localData = ref.read(salesDataSourceProvider);
                                    await localData.deleteOrderItems(idCde);
                                    await localData.deleteOrder(idCde);

                                    // 🔒 FIX ASYNC GAP : Vérification stricte du montage de la modale
                                    if (!modalContext.mounted) return;
                                    Navigator.pop(modalContext);
                                  },
                                ),
                              ],
                            ),

                          onTap: () async {
                            final List<Map<String, dynamic>> itemsQuery = await ref.read(salesDataSourceProvider).getItemsDeCommande(idCde);
                            
                            // 🛠️ ALIGNEMENT DU PANIER AVEC VOTRE STRATÉGIE DE RECHARGEMENT
                            ref.read(salesCartProvider.notifier).setInitialItems(itemsQuery.map((m) {
                              return OrderItemModel(
                                idArticle: m['id_article'] as int,
                                qteVendue: (m['qte_vendue'] as num).toInt(),
                                prixFacture: (m['prix_facture'] as num).toDouble(),
                              );
                            }).toList());

                            final localData =  ref.read(salesDataSourceProvider);
                            await localData.deleteOrderItems(idCde);
                            await localData.deleteOrder(idCde);

                            if (!modalContext.mounted) return;
                            Navigator.pop(modalContext);
                          },

                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (!context.mounted) return; // 🔒 Protection sur le parent
      (context as Element).markNeedsBuild();
    });
  }
}
