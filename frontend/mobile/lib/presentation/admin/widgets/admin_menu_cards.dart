// path: frontend/mobile/lib/presentation/admin/widgets/admin_menu_cards.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../data/datasources/sales_data_source.dart';
import '../../../data/datasources/session_data_source.dart';
import '../../../data/datasources/security_data_source.dart';
import '../../auth/session_provider.dart';
import '../../auth/auth_provider.dart'; 
import '../admin_sync_screen.dart';
import '../manquants_pro_panel.dart';

class AdminMenuCards extends ConsumerWidget {
  final WidgetRef ref;
  final VoidCallback onActionComplete;
 // final LocalDataSource localDataSource = LocalDataSource();
  final SalesDataSource salesDataSource = SalesDataSource();
  final SessionDataSource sessionDataSource = SessionDataSource();
  
  AdminMenuCards({super.key, required this.ref, required this.onActionComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed, foregroundColor: Colors.white),
                onPressed: () => _confirmerAction(context, "Purger les ACHATS", () => ref.read(sessionDataSourceProvider).purgerAchatsSession()),
                child: const Text('Purger Achats', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed, foregroundColor: Colors.white),
                onPressed: () => _confirmerAction(context, "Purger les VENTES", () => ref.read(sessionDataSourceProvider).purgerVentesSession()),
                child: const Text('Purger Ventes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          color: Colors.black38,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.white12)),
          child: ListTile(
            dense: true,
            leading: const Text('🛡️', style: TextStyle(fontSize: 18)),
            title: const Text('Suivi des Manquants Imputés', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
            subtitle: const Text('Consulter les dettes des chefs d\'équipe et purger après versement', style: TextStyle(fontSize: 11, color: Colors.white60)),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.primaryAmber, size: 20),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ManquantsProPanel())).then((_) => onActionComplete());
            },
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade900, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(42)),
          icon: const Icon(Icons.cloud_sync, size: 18, color: AppTheme.primaryAmber),
          label: const Text('ACCÉDER À LA CONSOLE DE SYNCHRONISATION CLOUD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSyncScreen())).then((_) => onActionComplete());
          },
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF660000), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(42)),
          icon: const Icon(Icons.delete_forever, size: 18),
          label: const Text('RESET TOTAL EN CASCADE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          onPressed: () => _confirmerAction(context, "RESET TOTAL EN CASCADE", () async {
            await ref.read(localDataSourceProvider).purgerToutEnCascade();
            await ref.read(sessionProvider.notifier).verifierSessionAChaud();
          }),
        ),
      ],
    );
  }

  void _confirmerAction(BuildContext context, String label, Future<void> Function() action) {
    final bool estPurgeTotale = label.contains("RESET");
    final TextEditingController pwdController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text("⚠️ $label", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Form(
          key: dialogFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                estPurgeTotale 
                    ? "🚨 ACTION CRITIQUE : Suppression totale du Grand Livre local. Saisissez votre MOT DE PASSE ADMIN :" 
                    : "Cette action effacera immédiatement les lignes ciblées dans SQLite. Confirmer ?",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              if (estPurgeTotale) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: pwdController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Mot de passe', labelStyle: TextStyle(color: Colors.white60), border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                ),
              ]
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () { pwdController.dispose(); Navigator.pop(ctx); }, child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () async {
              if (estPurgeTotale) {
                if (!dialogFormKey.currentState!.validate()) return;
                // Récupérer l'ID de l'admin en cours d'utilisation
                final operatorState = ref.read(currentOperatorProvider);
                // 🔑 Ajout du ! pour convertir le int? en int
                final int idAdminConnecte = operatorState.idUser!;

                final res = await ref.read(securityDataSourceProvider).verifierPasswordManagerDynamique(
                  pwdController.text.trim(),
                  idAdminConnecte,
                );               
                if (res == null || res['role_user'] != 'admin') {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: AppTheme.alertRed, content: Text('🛑 Mot de passe Administrateur invalide.')));
                  return;
                }
              }
              await action();
              pwdController.dispose();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              onActionComplete();
            },
            child: const Text("Purger"),
          )
        ],
      ),
    );
  }
}
