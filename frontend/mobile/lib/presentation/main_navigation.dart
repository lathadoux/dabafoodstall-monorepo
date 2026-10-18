import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../../domain/entities/user.dart'; // Import nécessaire pour l'entité de droits
import '../presentation/close/close_screen.dart';
import '../presentation/sale/sale_screen.dart';
import '../presentation/sale/sync_ui_provider.dart'; // Intégration du notificateur réseau
import '../presentation/status/status_screen.dart';
import '../presentation/auth/cashier_pin_screen.dart';

// 🛠️ INCLUSION DU DASHBOARD DU GESTIONNAIRE V1
import 'manager/manager_dashboard_screen.dart'; 

class MainNavigation extends ConsumerStatefulWidget {
  final User currentUser;

  const MainNavigation({
    super.key,
    required this.currentUser,
  });

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentTabIndex = 0;
  late List<Widget> _screens;
  late List<BottomNavigationBarItem> _navItems;

  // 🔒 VERROU DE NAVIGATION RÉACTIF #MIGRATION_NATIVE_DABA_V1
  // Permet de piloter la méthode d'agrégation de la clôture depuis cet écran parent
  final GlobalKey<CloseScreenState> _closeScreenKey = GlobalKey<CloseScreenState>();

  @override
  void initState() {
    super.initState();
    _buildMenuSelonDroits();
  }

  /// Construit dynamiquement les accès tactiles selon le profil figé du groupe connecté
  void _buildMenuSelonDroits() {
    _screens = [];
    _navItems = [];

    // 🍔 RÈGLE VENDEUR : Caisse/Vente tactile et Clôture du soir exclusivement
    if (widget.currentUser.isVendor) {
      _screens.addAll([
        const SaleScreen(),
        // 🛠️ CORRECTIF : Injection de la clé globale sur le composant de clôture
        CloseScreen(key: _closeScreenKey),
      ]);
      _navItems.addAll([
        const BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_checkout), label: 'Ventes 🍔'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.lock), label: 'Clôture 🔒'),
      ]);
    }
    // 📊 RÈGLE GESTIONNAIRE / MANAGER : Intégration du Dashboard et des Statistiques analytiques
    else if (widget.currentUser.isManager) {
      _screens.addAll([
        // 🟢 PREMIER ÉCRAN : Le tableau de bord de supervision (Synchro, Catalogues, Achats)
        ManagerDashboardScreen(managerName: widget.currentUser.nomUser),
        const StatusScreen(),
      ]);
      _navItems.addAll([
        const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_customize_outlined), label: 'Supervision 👨‍💼'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined), label: 'Rapports 📊'), 
      ]);
    }
    // ⚙️ RÈGLE ADMINISTRATEUR : Accès au panneau des configurations globales du Tenant
    else if (widget.currentUser.isAdmin) {
      _screens.add(const Center(
        child: Text(
          '⚙️ Espace Paramètres Globaux & Devises\n(Réservé Administrateur)', 
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), 
        ),
      ));
      _navItems.add(const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings), label: 'Configuration ⚙️')); 
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🛠️ Écoute réactive en temps réel de l'état de la connectivité et du statut de synchro
    final syncState = ref.watch(syncUiProvider); 

    return Scaffold(
      // Barre supérieure fixe avec indicateur d'état local (Offline-First)
      appBar: AppBar(
        title: Text('DabaFoodStall - ${widget.currentUser.nomUser}'), 
        elevation: 2, 
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.alertRed), 
            tooltip: 'Déconnexion du Stand', 
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const CashierPinScreen()), 
                (route) => false, 
              );
            },
          ),
          
          // ===================================================================
          // BOUTON DE SYNCHRONISATION MANUELLE RÉACTIF (CONTRAT D'ÉCHANGE V1)
          // ===================================================================
          IconButton(
            icon: syncState.isSyncing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryAmber, strokeWidth: 2), 
                  )
                : Icon(
                    Icons.sync, 
                    color: syncState.isOnline 
                        ? AppTheme.cleanWhite 
                        : Colors.white38, 
                  ),
            tooltip: 'Forcer la synchronisation Cloud', 
            onPressed: syncState.isSyncing 
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context); 
                    await ref.read(syncUiProvider.notifier).triggerManualSync(); 
                    if (!context.mounted) return; 
                    messenger.showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 2), 
                        content: Text(ref.read(syncUiProvider).lastSyncMessage), 
                      ),
                    );
                  },
          ),

          // TÉMOIN VISUEL DE CONNECTIVITÉ PHYSIQUE (🟢 ONLINE / 🟡 OFFLINE)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0), 
            child: Row(
              children: [
                Text(
                  syncState.isOnline ? 'En ligne' : 'Local', 
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), 
                ),
                const SizedBox(width: 6), 
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: syncState.isOnline 
                        ? AppTheme.successGreen 
                        : AppTheme.primaryAmber, 
                    shape: BoxShape.circle, 
                    boxShadow: [
                      BoxShadow(
                        color: syncState.isOnline 
                            ? Colors.green.withValues(alpha: 0.4) 
                            : Colors.amber.withValues(alpha: 0.4), 
                        blurRadius: 4, 
                        spreadRadius: 1, 
                      )
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),

      // IndexedStack préserve l'état de vos paniers en cours lors des changements tactiles
      body: IndexedStack(
        index: _currentTabIndex,
        children: _screens, 
      ),

      // Barre de navigation basse massive adaptée aux contraintes du terrain
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex, 
        onTap: (index) {
          setState(() {
            _currentTabIndex = index; 
          });

          // ⚡ EXTRACTION COMPTABLE AUTOMATIQUE : Déclenchée lors de la bascule sur l'onglet Clôture
          if (widget.currentUser.isVendor && index == 1) {
            debugPrint("⚡ [Navigation Réactive] Onglet Clôture activé. Force le rafraîchissement SQLite...");
            // Consomme la clé pour appeler directement la fonction sans forcer l'utilisateur à cliquer sur le bouton
            _closeScreenKey.currentState?.chargerDonneesSession ();
          }
        },
        backgroundColor: AppTheme.darkCharcoal, 
        selectedItemColor: AppTheme.primaryAmber, 
        unselectedItemColor: Colors.white60, 
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), 
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12), 
        type: BottomNavigationBarType.fixed, 
        items: _navItems, 
      ),
    );
  }
}
