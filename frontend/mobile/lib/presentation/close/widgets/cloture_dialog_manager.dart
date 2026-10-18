// path: frontend/mobile/lib/presentation/close/widgets/cloture_dialog_manager.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart'; 
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/security_data_source.dart';
import '../../auth/auth_provider.dart'; 
import '../../auth/session_provider.dart';
import '../../manager/manager_dashboard_screen.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../data/datasources/session_data_source.dart';
import '../../../data/database/database_helper.dart';

class ClotureDialogManager {
  static void ouvrirBoiteScellement({
    required BuildContext context,
    required WidgetRef ref,
    required int idSessionActive,
    required double soldeTheoriqueAttendu,
    required double chiffreAffairesTheorique,
    required double totalAchatsCaisse,
    required double cashPhysiqueSaisi,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _ClotureDialogContent(
          ref: ref,
          idSessionActive: idSessionActive,
          soldeTheoriqueAttendu: soldeTheoriqueAttendu,
          chiffreAffairesTheorique: chiffreAffairesTheorique,
          totalAchatsCaisse: totalAchatsCaisse,
          cashPhysiqueSaisi: cashPhysiqueSaisi,
          parentContext: context,
        );
      },
    );
  }
}

class _ClotureDialogContent extends StatefulWidget {
  final WidgetRef ref;
  final int idSessionActive;
  final double soldeTheoriqueAttendu;
  final double chiffreAffairesTheorique;
  final double totalAchatsCaisse;
  final double cashPhysiqueSaisi;
  final BuildContext parentContext;

  const _ClotureDialogContent({
    required this.ref,
    required this.idSessionActive,
    required this.soldeTheoriqueAttendu,
    required this.chiffreAffairesTheorique,
    required this.totalAchatsCaisse,
    required this.cashPhysiqueSaisi,
    required this.parentContext,
  });

  @override
  State<_ClotureDialogContent> createState() => _ClotureDialogContentState();
}

class _ClotureDialogContentState extends State<_ClotureDialogContent> {
  final _passwordController = TextEditingController();
  final _dialogFormKey = GlobalKey<FormState>();
  bool _isPasswordObscured = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Text('⚠️', style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Text('Sécurisation Clôture Z', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'La clôture est définitive. Saisissez votre MOT DE PASSE GESTIONNAIRE pour sceller le rapport d\'audit :', 
                  style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.3)
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _isPasswordObscured,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe complet', 
                    border: const OutlineInputBorder(), 
                    prefixIcon: const Icon(Icons.lock, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordObscured = !_isPasswordObscured;
                        });
                      },
                    ),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Le mot de passe est obligatoire.' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed),
          child: const Text('Confirmer & Sceller', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          onPressed: () async {
            if (!_dialogFormKey.currentState!.validate()) return;
            
            final messenger = ScaffoldMessenger.of(widget.parentContext);
            final navigator = Navigator.of(widget.parentContext);
            final dialogNavigator = Navigator.of(context);

            final String pwdEspaceNettoye = _passwordController.text.trim();
            final operatorState = widget.ref.read(currentOperatorProvider);
            final int idUserConnecte = operatorState.idUser ?? 1;

            // 🔍 1. DIAGNOSTIC CONSOLE : Visualisation des saisies IHM
            debugPrint("🔍 [DEBUG CLÔTURE] Saisie gérant - ID Opérateur Connecté: $idUserConnecte | Mot de passe: '$pwdEspaceNettoye' | Session: #${widget.idSessionActive}");

            try {
              // 🔍 2. DIAGNOSTIC CONSOLE : Examen de la table SQLite locale
              final db = await DatabaseHelper.instance.database;
              final List<Map<String, dynamic>> tousLesGerants = await db.query(
                'users', 
                where: "role_user IN ('manager', 'admin')"
              );
              
              debugPrint("🗄️ [DEBUG SQLITE] Liste des comptes autorisés en base locale :");
              for (var u in tousLesGerants) {
                debugPrint("   -> ID: ${u['id_user']} | Nom: ${u['nom_user']} | Rôle: ${u['role_user']} | PWD en base: '${u['password_user']}' | PIN: '${u['pin_user']}'");
              }

              // 🔐 3. AUTHENTIFICATION DYNAMIQUE CIBLÉE (2 paramètres requis par votre DataSource)
              final Map<String, dynamic>? managerIdentifie = await widget.ref
                  .read(securityDataSourceProvider)
                  .verifierPasswordManagerDynamique(pwdEspaceNettoye, idUserConnecte);
                  
              if (managerIdentifie == null) {
                debugPrint("🛑 [DEBUG AUTH REJET] Le mot de passe ou l'ID ($idUserConnecte) ne correspond à aucun profil dans SQLite.");
                messenger.showSnackBar(const SnackBar(backgroundColor: AppTheme.alertRed, content: Text('🛑 Mot de passe ou compte invalide. Clôture refusée.')));
                return;
              }

              final int idGerant = managerIdentifie['id_user'] as int;
              final String nomGerant = managerIdentifie['nom_user'] as String;
              final double ecartFinal = widget.cashPhysiqueSaisi - widget.soldeTheoriqueAttendu;

              debugPrint("✅ [DEBUG AUTH SUCCESS] Authentification validée pour $nomGerant (ID: $idGerant). Écart calculé : $ecartFinal F.");

              // 🧱 4. EXECUTION DU SCELLAGE TRANSACTIONNEL LOCAL
              await widget.ref.read(sessionDataSourceProvider).executerClotureEtScellementSessionZ(
                idSessionActive: widget.idSessionActive,
                idGerant: idGerant,
                cashPhysiqueSaisi: widget.cashPhysiqueSaisi,
                soldeTheoriqueAttendu: widget.soldeTheoriqueAttendu,
                chiffreAffairesTheorique: widget.chiffreAffairesTheorique,
                totalAchatsCaisse: widget.totalAchatsCaisse,
                ecartFinal: ecartFinal,
              );

              await widget.ref.read(sessionProvider.notifier).verifierSessionAChaud();

              // ===================================================================
              // 🖨️ DISPATCH DES IMPRESSIONS IMPLÉMENTÉES
              // ===================================================================
              final modeActuel = widget.ref.read(printerSettingsProvider);

              if (modeActuel == ModeImpression.papierThermique) {
                await PrinterService().imprimerRapportZSession(
                  idSession: widget.idSessionActive,
                  nomManager: nomGerant,
                  ventes: widget.chiffreAffairesTheorique,
                  achats: widget.totalAchatsCaisse,
                  attendu: widget.soldeTheoriqueAttendu,
                  reel: widget.cashPhysiqueSaisi,
                  ecart: ecartFinal
                );
              } else if (modeActuel == ModeImpression.documentPdf) {
                await PdfService.instance.genererRapportZPdf(
                  idSession: widget.idSessionActive,
                  nomManager: nomGerant,
                  nomPOS: operatorState.nomPOS,
                  totalVentes: widget.chiffreAffairesTheorique,
                  totalAchats: widget.totalAchatsCaisse,
                  fondsAttendu: widget.soldeTheoriqueAttendu,
                  fondsReel: widget.cashPhysiqueSaisi,
                  ecart: ecartFinal
                );
              }

              // ===================================================================
              // 💬 EXPORTATION COMPTABLE POUR LE PATRON SUR WHATSAPP
              // ===================================================================
final String emojiEcart = ecartFinal == 0 ? "✅ (Équilibre)" : (ecartFinal > 0 ? "⚠️ (Surplus)" : "🚨 (Manquant)");
final String messageWhatsApp =
"📝 DABA FOOD STALL - RAPPORT Z DE CAISSE\n"
"-------------------------------------------\n"
"🏪 Point de Vente : ${operatorState.nomPOS}\n"
"🔢 Session Clôturée : #${widget.idSessionActive}\n"
"👤 Responsable Audit : $nomGerant\n"
"📅 Date : ${DateTime.now().toString().substring(0, 16)}\n"
"-------------------------------------------\n"
"💰 Chiffre d'Affaires (+): ${widget.chiffreAffairesTheorique.toInt()} FCFA\n"
"📉 Dépenses d'Achats (-): ${widget.totalAchatsCaisse.toInt()} FCFA\n"
"🧮 Solde Théorique Attendu : ${widget.soldeTheoriqueAttendu.toInt()} FCFA\n"
"💵 Comptage Physique Réel : ${widget.cashPhysiqueSaisi.toInt()} FCFA\n"
"-------------------------------------------\n"
"ÉCART DE CAISSE : ${ecartFinal.toInt()} FCFA $emojiEcart\n\n"
"🔐 Rapport d'audit scellé et signé numériquement en local via SQLite.";
await Share.share(messageWhatsApp, subject: 'Rapport Z Session #${widget.idSessionActive}');
dialogNavigator.pop();
messenger.showSnackBar(SnackBar(backgroundColor: AppTheme.successGreen, content: Text('✅ Clôture validée par $nomGerant. Rapport Z exporté !')));
navigator.pushAndRemoveUntil(
MaterialPageRoute(builder: (context) => ManagerDashboardScreen(managerName: nomGerant)),
(route) => false,
);
} catch (e) {
// 🔑 RESTAURATION DE LA CLAUSE CATCH MANQUANTE
debugPrint("🛑 [Rapport Z Échec Critique] Interception : $e");
messenger.showSnackBar(SnackBar(backgroundColor: AppTheme.alertRed, content: Text('🛑 Erreur technique lors du scellage : $e')));
}
},
),
],
);
}
}