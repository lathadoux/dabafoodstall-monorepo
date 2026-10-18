// path: frontend/mobile/lib/presentation/manager/widgets/cash_mvt_dialog.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/database_helper.dart';

class CashMvtDialog extends StatefulWidget {
  final int idUser;
  final int idSession;

  const CashMvtDialog({super.key, required this.idUser, required this.idSession});

  static void afficher(BuildContext context, {required int idUser, required int idSession}) {
    showDialog(
      context: context,
      builder: (context) => CashMvtDialog(idUser: idUser, idSession: idSession),
    );
  }

  @override
  State<CashMvtDialog> createState() => _CashMvtDialogState();
}

class _CashMvtDialogState extends State<CashMvtDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String _typeMouvement = 'RETRAIT'; // 'APPORT'  ou 'RETRAIT' (Versement)

  void _enregistrerMouvement() async {
    if (!_formKey.currentState!.validate()) return;

    final double montantSaisi = double.parse(_amountController.text.trim());
    final int idArticleMvt = _typeMouvement == 'APPORT' ? 901 : 902;

    try {
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        // 1. Insertion de la commande maîtresse d'infrastructure
        final int orderId = await txn.insert('orders', {
          'id_session': widget.idSession,
          'date_heure_cde': DateTime.now().toIso8601String(),
          'statut_commande': _typeMouvement == 'APPORT' ? 'termine' : 'achat', // 'termine' pour entrée, 'achat' pour sortie
          'statut_sync': 0,
          'id_user': widget.idUser,
          'mode_reglement': 'Cash',
          'total_amount': montantSaisi,
          'tag_commande': '💸 Flux Propriétaire: $_typeMouvement',
        });

        // 2. Insertion de la ligne de dictionnaire associée
        await txn.insert('order_items', {
          'id_cde': orderId,
          'id_article': idArticleMvt,
          'qte_vendue': montantSaisi, // Qte calée sur le montant car Prix Unitaire = 1 F
          'prix_facture': 1.0,
        });
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.successGreen,
          content: Text('🪙 Mouvement de coffre enregistré : $_typeMouvement de ${montantSaisi.toInt()} F'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.alertRed, content: Text('🛑 Erreur écriture coffre : $e')),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Text('🪙', style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Expanded( // 🚀 SÉCURISATION : Force le texte à s'adapter et à passer à la ligne sur petit écran
            child: Text(
              'Mouvements de Caisse Apport/Retrait', 
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),      
      content: Form(
        key: _formKey,
        // 🚀 SÉCURISATION ANTI-DÉBORDEMENT : Ajout du défilement lorsque le clavier est visible
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SÉLECTEUR DE TYPE DE FLUX
              DropdownButtonFormField<String>(
                initialValue: _typeMouvement,
                isExpanded: true, // Conserve le correctif de largeur précédent
                decoration: const InputDecoration(
                  border: OutlineInputBorder(), 
                  labelText: 'Nature du flux propriétaire'
                ),
                items: const [
                   DropdownMenuItem(
                    value: 'RETRAIT', 
                    child:  Text('⬇️ Versement (Sortie)', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'APPORT', 
                    child: Text('⬆️ Appro Caisse (Entrée)', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (val) => setState(() => _typeMouvement = val!),
              ),
              const SizedBox(height: 16),
              // CHAMP DE SAISIE DU MONTANT CASH DIRECT
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Montant du transfert (FCFA)', 
                  border: OutlineInputBorder(), 
                  prefixIcon: Icon(Icons.payments)
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Veuillez renseigner le montant.';
                  if (double.tryParse(val.trim()) == null || double.parse(val.trim()) <= 0) return 'Montant invalide.';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.darkCharcoal, foregroundColor: Colors.white),
          onPressed: _enregistrerMouvement,
          child: const Text('Valider l\'écriture', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
