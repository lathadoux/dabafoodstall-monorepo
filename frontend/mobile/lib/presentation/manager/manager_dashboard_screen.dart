import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import '../../core/theme/app_theme.dart';
import 'manager_article_config_screen.dart';
import 'manager_purchase_article_config_screen.dart';
import 'manager_sync_screen.dart'; 
import '../purchase/purchase_panel_screen.dart';
import '../suivi/rapport_x_screen.dart'; 
import '../auth/auth_provider.dart'; 
import '../auth/session_provider.dart'; 
import '../manager/ouverture_caisse_screen.dart'; 
import '../auth/cashier_pin_screen.dart'; 
import '../close/close_screen.dart';
import 'journal_ventes_screen.dart';
import 'journal_achats_screen.dart';
import 'historique_sessions_screen.dart';
import  'widgets/cash_mvt_dialog.dart';

class ManagerDashboardScreen extends ConsumerStatefulWidget {
  final String managerName;

  const ManagerDashboardScreen({
    super.key,
    required this.managerName,
  });

  @override
  ConsumerState<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends ConsumerState<ManagerDashboardScreen> {
  bool _aVerifieSession = false; 

  @override
  Widget build(BuildContext context) {
    // ⚡ RÉCUPÉRATION RÉACTIVE DE L'ÉTAT (STATE) DEPUIS VOS PROVIDERS DE CONTEXTE
  final operatorState = ref.watch(currentOperatorProvider);
  final sessionState = ref.watch(sessionProvider);

  // Extraction sécurisée des identifiants typés
// 1. Extraction de l'ID User (Utilise la propriété 'idUser' de votre OperatorState)
  final int idUserActive = operatorState.idUser ?? 0;

  // 2. Extraction de l'ID Session (Lit directement la clé dans votre structure d'état active)
   final int idSessionActive = sessionState.idSession ?? 1; 


    if (!sessionState.isLoading && !sessionState.hasActiveSession && !_aVerifieSession) {
      _aVerifieSession = true; 
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const OuvertureCaisseScreen()),
        );
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Espace Gestion & Pilotage'),
        backgroundColor: AppTheme.darkCharcoal,
        foregroundColor: AppTheme.cleanWhite,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.alertRed),
            tooltip: 'Fermer Session Manager',
            onPressed: () {
              setState(() {
                _aVerifieSession = true;
              });

              ref.read(currentOperatorProvider.notifier).state = const OperatorState(
                isAuthenticated: false,
                nomPOS: "Étal Pilote Abidjan",
                idUser: null,
                nomUtilisateur: null,
                role: null,
              );

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const CashierPinScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Bandeau de bienvenue personnalisé
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cleanWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Text('👨‍💼', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bienvenue, ${widget.managerName}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Statut : Manager de Stand (Droits Étendus V1)',
                            style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 📊 ACCÈS AUX JOURNAUX ANALYTIQUES EN RECTANGLE ÉPROUVÉ
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.darkCharcoal,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const JournalVentesScreen()),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('📋 ', style: TextStyle(fontSize: 16)),
                          Text('Ventes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12), // Espacement équilibré entre les boutons
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF331919), 
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const JournalAchatsScreen()),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('💸 ', style: TextStyle(fontSize: 16)),
                          Text('Dépenses', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                '🕹️ Actions de Supervision',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal),
              ),
              const SizedBox(height: 12),

              // Grille des modules d'administration tactiles
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.80,
                children: [
                  _buildMenuCard(
                    context: context,
                    icon: '🔄',
                    title: 'Centre de Synchro',
                    subtitle: 'Gestion des imports de catalogues et exports de tickets',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ManagerSyncScreen()),
                      );
                    },
                  ),

                  _buildMenuCard(
                    context: context,
                    icon: '🍔',
                    title: 'Panneau Articles',
                    subtitle: 'Mise à jour des prix, ajouts et retraits',
                    color: AppTheme.primaryAmber,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ManagerArticleConfigScreen()),
                      );
                    },
                  ),
                  // 🔑 INTEGRATION : LE NOUVEAU MODULE DE CONFIGURATION DES PRIX D'ACHATS
                  _buildMenuCard(
                    context: context,
                    icon: '📦',
                    title: 'Prix Achats',
                    subtitle: 'Ajustement des coûts matières, charbon et intrants',
                    color: Colors.blueGrey,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ManagerPurchaseArticleConfigScreen()),
                      );
                    },
                  ),
                  
                  _buildMenuCard(
                    context: context,
                    icon: '📊',
                    title: 'Rapport X (Direct)',
                    subtitle: 'Consultation à chaud du solde théorique de caisse',
                    color: AppTheme.successGreen,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RapportXScreen()),
                      );
                    },
                  ),

                  // À insérer dans les enfants de votre GridView ou ListView de menus :
                  _buildMenuCard(
                    context: context,
                    icon: '🪙',
                    title: 'Mouvements Coffre',
                    subtitle: 'Gestion des appro caisse et versements',
                    color: Colors.amber.shade800,
                    onTap: () {
                      // 🛠️ OUVERTURE DE LA FENÊTRE CONTEXTUELLE FILTRÉE DÉDIÉE
                      // Assurez-vous d'avoir les variables idUserActive et idSessionActive chargées depuis vos providers de session
                      CashMvtDialog.afficher(
                        context,
                        idUser: idUserActive, 
                        idSession: idSessionActive,
                      );
                    },
                  ),
                  
                  _buildMenuCard(
                    context: context,
                    icon: '🔒',
                    title: 'Clôture Z (Soir)',
                    subtitle: 'Comptage physique du cash et scellement du Rapport Z',
                    color: AppTheme.alertRed,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CloseScreen()),
                      );
                    },
                  ),
                  
                  _buildMenuCard(
                    context: context,
                    icon: '💸',
                    title: 'Panneau Achats',
                    subtitle: 'Saisie des dépenses de matières premières',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
						MaterialPageRoute(builder: (context) => const PurchasePanelScreen()),
						);
						},
						),
						// 🛠️ REAJUSTEMENT DE L'ACCÈS HISTORIQUE SELON VOTRE PREFERENCE TACTILE
						_buildMenuCard(
						context: context,
						icon: '📁',
						title: 'Historique Clôtures',
						subtitle: 'Relecture et partage des anciens Rapports Z archivés',
						color: Colors.teal,
						onTap: () {
						Navigator.push(
						context,
						MaterialPageRoute(builder: (context) => const HistoriqueSessionsScreen()),
						);
						},
						),
						],
						),
						],
						),
						),
						),
						);
						}
						Widget _buildMenuCard({
						required BuildContext context,
						required String icon,
						required String title,
						required String subtitle,
						required Color color,
						required VoidCallback onTap,
						}) {
						return Card(
						elevation: 3,
						margin: EdgeInsets.zero,
						color: AppTheme.cleanWhite,
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
						child: InkWell(
						onTap: onTap,
						borderRadius: BorderRadius.circular(12),
						child: Padding(
						padding: const EdgeInsets.all(12.0),
						child: Column(
						mainAxisAlignment: MainAxisAlignment.start,
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
						Container(
						padding: const EdgeInsets.all(8),
						decoration: BoxDecoration(
						color: color.withValues(alpha: 0.1),
						borderRadius: BorderRadius.circular(8),
						),
						child: Text(icon, style: const TextStyle(fontSize: 24)),
						),
						const SizedBox(height: 12),
						Expanded(
						child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						mainAxisSize: MainAxisSize.min,
						children: [
						Text(
						title,
						maxLines: 1,
						overflow: TextOverflow.ellipsis,
						style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal),
						),
						const SizedBox(height: 4),
						Text(
						subtitle,
						maxLines: 2,
						overflow: TextOverflow.ellipsis,
						style: const TextStyle(fontSize: 10, color: Colors.grey, height: 1.2),
						),
						],
						),
						),
						],
						),
						),
						),
						);
						}
						}