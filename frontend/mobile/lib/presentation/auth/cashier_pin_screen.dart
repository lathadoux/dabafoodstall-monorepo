import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
//import '../../data/database/database_helper.dart';
//import '../../main.dart'; // Pour consommer le currentOperatorProvider et OperatorState
import '../manager/manager_dashboard_screen.dart'; // Votre écran cible Manager
import '../sale/sale_screen.dart'; // Votre écran cible Vendeur (si existant)
import '../admin/admin_dashboard_screen.dart'; // Votre écran cible Admin
// 🛠️ SÉCURITÉ : Importation directe et propre du provider délocalisé
import '../auth/auth_provider.dart'; 
import '../auth/session_provider.dart'; // Pour vérifier l'état de la session
import '../../data/datasources/local_data_source.dart'; // Pour interroger la base locale Sqflite

class CashierPinScreen extends ConsumerStatefulWidget {
  const CashierPinScreen({super.key});

  @override
  ConsumerState<CashierPinScreen> createState() => _CashierPinScreenState();
}

class _CashierPinScreenState extends ConsumerState<CashierPinScreen> {
  String _pinCode = "";
  final int _pinLength = 4;
 // 🛠️ FIX : AJOUT DE LA MÉTHODE INITSTATE POUR PURGER LE NOM DE L'UTILISATEUR AU LOGOUT
  @override
  void initState() {
    super.initState();
    
    // Le PostFrameCallback attend que l'écran soit dessiné pour modifier l'état Riverpod sans crash
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentOperatorProvider.notifier).state = const OperatorState(
        isAuthenticated: false,
        nomPOS: "Étal Pilote Abidjan",
        idUser: null,
        nomUtilisateur: null, // Efface le nom persistant
        role: null,           // Remet le badge au rouge LOCK
      );
    });
  }
  /// Logique de traitement du code PIN saisi
  void _onKeyPress(String value) {
    if (_pinCode.length < _pinLength) {
      setState(() {
        _pinCode += value;
      });
    }

    // 🔒 Dès que le code PIN est complet (4 chiffres), on déclenche la vérification
    if (_pinCode.length == _pinLength) {
      _verifierAuthentification();
    }
  }

  void _onDelete() {
    if (_pinCode.isNotEmpty) {
      setState(() {
        _pinCode = _pinCode.substring(0, _pinCode.length - 1);
      });
    }
  }

    /// 🛡️ Vérification dynamique des rôles via la base Sqflite locale
  Future<void> _verifierAuthentification() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // 1. Interrogation de la base de données locale pour authentifier le PIN
      final Map<String, dynamic>? user = 
          await ref.read(localDataSourceProvider).verifierPinUtilisateur(_pinCode);

      if (user == null) {
        _reinitialiserFormulaire();
        messenger.showSnackBar(
          const SnackBar(backgroundColor: AppTheme.alertRed, content: Text('🛑 Code PIN incorrect. Accès refusé.')),
        );
        return;
      }

      // Extraction des propriétés réelles de la ligne SQL
      final int idUser = user['id_user'] as int;
      final String nomUser = user['nom_user'] as String;
      final String roleUser = user['role_user'] as String;

      // Extraction dynamique du nom de l'établissement (Tenant / POS) depuis la base
      final Map<String, dynamic> posParams = await ref.read(localDataSourceProvider).getConfigurationParams();
      final String nomPOSEffectif = posParams['nom_pos']; 

      // 2. Mutation unifiée et dynamique du State de l'opérateur connecté
      ref.read(currentOperatorProvider.notifier).state = OperatorState(
        isAuthenticated: true, 
        nomPOS: nomPOSEffectif, 
        idUser: idUser, 
        nomUtilisateur: nomUser, 
        role: roleUser, 
      );

      // 3. Aiguillage dynamique avec barrière de licence souveraine Sync Engine V2
      switch (roleUser) {
         case 'admin':
          // 🔑 NETTOYAGE & SÉCURITÉ : Appel de la méthode encapsulée de LocalDataSource
          final bool isBackofficeAllowed = 
              await ref.read(localDataSourceProvider).verifierLicenceBackOffice();

          // Si la licence n'est pas active (Option non souscrite ou expirée)
          if (!isBackofficeAllowed) {
            _reinitialiserFormulaire();
            messenger.showSnackBar(
              const SnackBar(
                backgroundColor: AppTheme.alertRed, 
                content: Text('🔒 Accès Refusé : L\'option BackOffice n\'est pas active sur ce terminal. Veuillez régulariser votre abonnement.')
              ),
            );
            return;
          }

          // Si la licence est valide, l'accès à l'IHM est déverrouillé
          navigator.pushReplacement(
            MaterialPageRoute(builder: (context) => AdminDashboardScreen(adminName: nomUser)),
          );
          break;


        case 'manager':
          navigator.pushReplacement(
            MaterialPageRoute(builder: (context) => ManagerDashboardScreen(managerName: nomUser)),
          );
          break;

        case 'vendor':
          await ref.read(sessionProvider.notifier).verifierSessionAChaud();
          final freshSessionState = ref.read(sessionProvider);

          if (!freshSessionState.hasActiveSession) {
            _reinitialiserFormulaire();
            messenger.showSnackBar(
              const SnackBar(
                backgroundColor: AppTheme.alertRed,
                content: Text('🔒 Stand Verrouillé : Veuillez demander au Manager d’ouvrir la caisse du matin.'),
              ),
            );
            return;
          }

          messenger.showSnackBar(
            SnackBar(backgroundColor: AppTheme.successGreen, content: Text('🔓 Bienvenue $nomUser. Prêt pour le service.')),
          );

          navigator.pushReplacement(
            MaterialPageRoute(builder: (context) => const SaleScreen()),
          );
          break;

        default:
          _reinitialiserFormulaire();
          messenger.showSnackBar(
            const SnackBar(backgroundColor: AppTheme.alertRed, content: Text('🛑 Rôle utilisateur non reconnu par l\'infrastructure.')),
          );
          break;
      }

    } catch (e) {
      debugPrint("🛑 [PIN Screen Erreur] Échec authentification Sqflite : \$e");
      _reinitialiserFormulaire();
    }
  }






  void _reinitialiserFormulaire() {
    setState(() {
      _pinCode = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Saisir le Code PIN",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal),
            ),
            const SizedBox(height: 8),
            const Text(
              "Authentification requise pour déverrouiller le stand",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // 🎯 Visualisation des puces de code PIN (cercles pleins ou vides)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _pinCode.length ? AppTheme.darkCharcoal : Colors.grey.shade300,
                    border: Border.all(color: AppTheme.darkCharcoal, width: 1.5),
                  ),
                );
              }),
            ),
            const SizedBox(height: 48),

            // 🕹️ Grille du pavé numérique d'authentification (Corrigé avec BoxConstraints)
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280), // 🛠️ FIX : Utilisation correcte de BoxConstraints
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    if (index == 9) {
                      return const SizedBox.shrink(); // Case vide gauche
                    }
                    if (index == 11) {
                      // Bouton effacer / Retour arrière
                      return IconButton(
                        icon: const Icon(Icons.backspace_outlined, size: 26, color: AppTheme.darkCharcoal),
                        onPressed: _onDelete,
                      );
                    }

                    // Mapping des touches numériques : 1-9 puis 0
                    final String number = index == 10 ? "0" : (index + 1).toString();

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cleanWhite,
                        foregroundColor: AppTheme.darkCharcoal,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      onPressed: () => _onKeyPress(number),
                      child: Text(number, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
