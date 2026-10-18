// path: frontend/mobile/lib/presentation/manager/status_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/datasources/analytics_data_source.dart';

class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key});

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> {
  double _soldeCaisse = 0.0;
  List<Map<String, dynamic>> _ventesJour = [];
  List<Map<String, dynamic>> _reglementsJour = [];
  List<Map<String, dynamic>> _achatsJour = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerBilansAdate();
  }

  Future<void> _chargerBilansAdate() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Dans l'app finale, l'id de session actif sera récupéré dynamiquement
    const int sessionActiveId = 1; 
    
    try {
      final analyticsData = ref.read(analyticsDataSourceProvider);
      
      final solde = await analyticsData.getSoldeCaisseTempsReel(sessionActiveId);
      final vJour = await analyticsData.getVentesVentilees(deLaJourneeSeule: true, idSessionCourante: sessionActiveId);
      final rJour = await analyticsData.getReglementsVentiles(deLaJourneeSeule: true, idSessionCourante: sessionActiveId);
      final aJour = await analyticsData.getAchatsVentiles(deLaJourneeSeule: true, idSessionCourante: sessionActiveId);

      if (!mounted) return;
      setState(() {
        _soldeCaisse = solde;
        _ventesJour = vJour;
        _reglementsJour = rJour;
        _achatsJour = aJour;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("🛑 [StatusScreen] Erreur d'extraction analytique : $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryAmber,
        onPressed: _chargerBilansAdate,
        child: const Icon(Icons.refresh, color: AppTheme.darkCharcoal),
      ),
      // 🔑 FIX LINTER : Consommation de _isLoading pour gérer l'affichage asynchrone
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =================================================================
                // INDICATEUR 1 : LE COMPTAGE EN TEMPS RÉEL (MONTANT À DATE)
                // =================================================================
                Card(
                  color: AppTheme.darkCharcoal,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('💰 CAISSE EN TEMPS RÉEL :', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                        Text('${_soldeCaisse.toInt()} F', style: const TextStyle(color: AppTheme.primaryAmber, fontSize: 24, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // =================================================================
                // INDICATEUR 2 : VENTILATION DES VENTES
                // =================================================================
                const Text('📊 Journal des Ventes (Plats & Boissons)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal)),
                const SizedBox(height: 8),
                _ventesJour.isEmpty 
                  ? const Text("Aucune vente enregistrée aujourd'hui.", style: TextStyle(color: Colors.grey))
                  : _buildAggregationTable(_ventesJour, 'designation', 'quantite', 'total'),
                
                const SizedBox(height: 24),

                // =================================================================
                // INDICATEUR 3 : MODES DE RÈGLEMENTS
                // =================================================================
                const Text('💳 Ventilation des Encaissements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal)),
                const SizedBox(height: 8),
                _reglementsJour.isEmpty
                  ? const Text("Aucun flux financier détecté.", style: TextStyle(color: Colors.grey))
                  : _buildFinancesList(_reglementsJour, 'mode_reglement', 'total', true),

                const SizedBox(height: 24),

                // =================================================================
                // INDICATEUR 4 : VENTILATION DES ACHATS
                // =================================================================
                const Text('🛒 Dépenses et Achats Directs sur Caisse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal)),
                const SizedBox(height: 8),
                _achatsJour.isEmpty 
                  ? const Text("Aucune dépense enregistrée sur cette session.", style: TextStyle(color: Colors.grey))
                  : _buildAggregationTable(_achatsJour, 'designation', 'quantite', 'total', isExpense: true),
              ],
            ),
          ),
    );
  }

  Widget _buildAggregationTable(List<Map<String, dynamic>> data, String labelKey, String qtyKey, String amountKey, {bool isExpense = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: AppTheme.cleanWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: DataTable(
        horizontalMargin: 12,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Article')),
          DataColumn(label: Text('Qte')),
          DataColumn(label: Text('Total')),
        ],
        rows: data.map((row) {
          return DataRow(cells: [
            DataCell(Text(row[labelKey].toString())),
            DataCell(Text(row[qtyKey].toString())),
            DataCell(Text('${(row[amountKey] as num).toInt()} F', style: TextStyle(fontWeight: FontWeight.bold, color: isExpense ? AppTheme.alertRed : AppTheme.successGreen))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildFinancesList(List<Map<String, dynamic>> data, String labelKey, String amountKey, bool isDebit) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppTheme.cleanWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        children: data.map((row) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(row[labelKey].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            trailing: Text(
              '${(row[amountKey] as num).toInt()} FCFA',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isDebit ? AppTheme.successGreen : AppTheme.alertRed),
            ),
          );
        }).toList(),
      ),
    );
  }
}
