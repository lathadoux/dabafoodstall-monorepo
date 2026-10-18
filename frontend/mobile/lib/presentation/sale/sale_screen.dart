// path: frontend/mobile/lib/presentation/sale/sale_screen.dart
import 'package:dabafoodstall/data/datasources/sales_data_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
//import '../../data/database/database_helper.dart';
import '../auth/auth_provider.dart';
import '../auth/cashier_pin_screen.dart';
import '../sale/sale_provider.dart';
import 'widgets/article_grid_panel.dart';
import 'widgets/cart_summary_panel.dart';
import 'widgets/pending_orders_modal.dart';

class SaleScreen extends ConsumerWidget {
  const SaleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(salesCartProvider);
    final double availableWidth = MediaQuery.of(context).size.width;
    final bool isTabletOrLandscape = availableWidth > 600;

    // 🔒 Lecture synchrone du contexte global Riverpod
    final appContext = ref.watch(activeSessionContextContext);
    final int currentSessionId = appContext['idSession']!;
    final int currentUserId = appContext['idUser']!;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Prise de commande & Encaissement', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkCharcoal,
        foregroundColor: AppTheme.cleanWhite,
        automaticallyImplyLeading: false,
        actions: [
          // 🎰 1. Le Badge numérique des commandes en attente
          FutureBuilder<List<Map<String, dynamic>>>(
            future: ref.read(salesDataSourceProvider).getCommandesEnAttente(currentSessionId),
            builder: (context, snapshot) {
              final int count = snapshot.hasData ? snapshot.data!.length : 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.layers_outlined, size: 26),
                    onPressed: count == 0 
                      ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗳️ Aucune commande en attente.')))
                      : () => PendingOrdersModal.afficher(context, ref, currentSessionId),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6, top: 6,
                      child: CircleAvatar(
                        radius: 8, backgroundColor: AppTheme.alertRed,
                        child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    )
                ],
              );
            },
          ),
          const SizedBox(width: 8),
          // 🚪 2. Bouton de déconnexion sécurisée (Logout)
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.alertRed, size: 24),
            onPressed: () {
              ref.read(currentOperatorProvider.notifier).state = const OperatorState(isAuthenticated: false, nomPOS: "Étal Pilote Abidjan", idUser: null);
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const CashierPinScreen()), (route) => false);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: isTabletOrLandscape 
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CartSummaryPanel(width: 310, idUser: currentUserId, idSession: currentSessionId, cartState: cartState),
                Container(width: 1, color: Colors.grey.shade300),
                const Expanded(child: ArticleGridPanel()),
              ],
            )
          : Column(
              children: [
                const Expanded(flex: 4, child: ArticleGridPanel()),
                Container(height: 1, color: Colors.grey.shade300),
                Expanded(flex: 3, child: CartSummaryPanel(width: double.infinity, idUser: currentUserId, idSession: currentSessionId, cartState: cartState)),
              ],
            ),
      ),
    );
  }
}
