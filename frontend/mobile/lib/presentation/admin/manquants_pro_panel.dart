// path: frontend/mobile/lib/presentation/admin/manquants_pro_panel.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local_data_source.dart';
//import '../../data/datasources/sales_data_source.dart';


class ManquantsProPanel extends ConsumerStatefulWidget  {
  const ManquantsProPanel({super.key});

  @override
  ConsumerState<ManquantsProPanel> createState() => _ManquantsProPanelState();
}

class _ManquantsProPanelState extends ConsumerState<ManquantsProPanel> {
  late Future<List<Map<String, dynamic>>> _manquantsFuture;

  @override
  void initState() {
    super.initState();
    _chargerSyntheseRH();
  }

  void _chargerSyntheseRH() {
    setState(() {
      _manquantsFuture = ref.read(localDataSourceProvider).getSyntheseManquantsParResponsable();
    });
  }

  void _confirmerPurgeDette(BuildContext context, int idUser, String nomUser, int montantManquant) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('🪙 Solder un Manquant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Confirmez-vous avoir reçu le remboursement en espèces de ${montantManquant.abs()} F de la part de $nomUser ? Cela remettra son compteur de dettes à zéro.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
            onPressed: () async {
              await ref.read(localDataSourceProvider).purgerEtSolderManquantsResponsable(idUser);
              _chargerSyntheseRH();
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(backgroundColor: AppTheme.successGreen, content: Text('🧼 Compteur soldé pour $nomUser.')),
              );
            },
            child: const Text('Confirmer le Versement', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Gouvernance RH : Imputation des Manquants', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkCharcoal,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _manquantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber));
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('🎉 Caisse propre ! Aucun manquant imputé aux chefs d\'équipe.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)));
          }

          final list = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final row = list[index];
              final int totalDette = (row['total_manquants_cumules'] as num).toInt();

              return Card(
                color: Colors.white,
                elevation: 2,
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: AppTheme.alertRed, child: Text('👤', style: TextStyle(color: Colors.white))),
                  title: Text(row['nom_user'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('Rôle : ${row['role_user']} • ${row['nbr_clotures_deficitaires']} clôture(s) avec écart'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${totalDette.abs()} F', style: const TextStyle(color: AppTheme.alertRed, fontWeight: FontWeight.w900, fontSize: 15)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: AppTheme.successGreen),
                        tooltip: 'Solder et purger la dette',
                        onPressed: () => _confirmerPurgeDette(context, row['id_user'] as int, row['nom_user'].toString(), totalDette),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
