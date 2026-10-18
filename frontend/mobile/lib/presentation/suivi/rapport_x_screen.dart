import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/datasources/analytics_data_source.dart';

class RapportXScreen extends ConsumerStatefulWidget {
  const RapportXScreen({super.key});

  @override
  ConsumerState<RapportXScreen> createState() => _RapportXScreenState();
}

class _RapportXScreenState extends ConsumerState<RapportXScreen> {
  late Future<Map<String, dynamic>> _rapportFuture;

  @override
  void initState() {
    super.initState();
    _rafraichirRapport();
  }

  void _rafraichirRapport() {
    setState(() {
      _rapportFuture = ref.read(analyticsDataSourceProvider).calculerRapportX();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Rapport X (Lecture Instantanée)'),
        backgroundColor: AppTheme.darkCharcoal,
        foregroundColor: AppTheme.cleanWhite,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _rafraichirRapport,
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _rapportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('🛑 Erreur lors du calcul du rapport local.'));
          }

          final data = snapshot.data!;

          if (data['statut'] == 'AUCUNE_SESSION') {
            return const Center(
              child: Text(
                '🏪 Aucune session de caisse n’est actuellement ouverte.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Entête d'information de session
                _buildHeaderCard(data),
                const SizedBox(height: 16),

                // Section Flux Financiers
                const Text("Flux du jour", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal)),
                const SizedBox(height: 8),
                _buildStatRow("Total des Ventes (Entrées)", "${data['total_ventes'].toInt()} F", Colors.green, Icons.arrow_upward),
                _buildStatRow("Total des Achats (Dépenses)", "-${data['total_achats'].toInt()} F", AppTheme.alertRed, Icons.arrow_downward),
                
                const SizedBox(height: 24),

                // Section Solde Coffre / Tiroir caisse
                const Text("Situation des Tiroirs (Théorique)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal)),
                const SizedBox(height: 8),
                _buildBalanceCard(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> data) {
    return Card(
      color: AppTheme.cleanWhite,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Session Active : #${data['id_session']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text("Ouverte le : ${data['date_ouverture'].toString().substring(0, 16)}", style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const Icon(Icons.assessment, color: AppTheme.primaryAmber, size: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color, IconData icon) {
    return Card(
      color: AppTheme.cleanWhite,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ),
    );
  }

  Widget _buildBalanceCard(Map<String, dynamic> data) {
    return Card(
      color: AppTheme.darkCharcoal,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildBalanceRow("Fond de caisse initial :", "${data['montant_init'].toInt()} F", Colors.white70),
            const Divider(color: Colors.white24),
            _buildBalanceRow("Espèces attendues en caisse :", "${data['solde_especes_theo'].toInt()} F", Colors.white),
            _buildBalanceRow("Mobile Money virtuel :", "${data['solde_mobile_theo'].toInt()} F", Colors.white),
            const Divider(color: Colors.white54, thickness: 1.2),
            _buildBalanceRow(
              "SOLDE TOTAL THÉORIQUE :", 
              "${data['solde_total_theo'].toInt()} F", 
              AppTheme.primaryAmber,
              isBold: true
            ),
          ],
        ),
      ),
    );
  }

Widget _buildBalanceRow(String label, String value, Color textColor, {bool isBold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 🛠️ FIX : Seul le premier Text (le label) doit être Expanded pour pousser le montant vers la droite
        Expanded(
          child: Text(
            label, 
            overflow: TextOverflow.ellipsis, // Sécurité si le texte est trop long sur petit écran
            style: TextStyle(
              color: textColor, 
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal, 
              fontSize: isBold ? 15 : 14,
            ),
          ),
        ),
        const SizedBox(width: 8), // Petit espace tampon de sécurité
        
        // Le montant reste fixe et s'aligne proprement à droite
        Text(
          value, 
          style: TextStyle(
            color: textColor, 
            fontWeight: FontWeight.bold, 
            fontSize: isBold ? 18 : 15,
          ),
        ),
      ],
    ),
  );
}
}