// path: frontend/mobile/lib/presentation/close/pages/historique_sessions_screen.dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/session_data_source.dart';
import '../../../core/services/printer_service.dart';
import '../../../data/services/sync_service.dart';

class HistoriqueSessionsScreen extends ConsumerStatefulWidget {
  const HistoriqueSessionsScreen({super.key});

  @override
  ConsumerState<HistoriqueSessionsScreen> createState() => _HistoriqueSessionsScreenState();
}

class _HistoriqueSessionsScreenState extends ConsumerState<HistoriqueSessionsScreen> {
  late Future<List<Map<String, dynamic>>> _historiqueFuture;

  @override
  void initState() {
    super.initState();
    _rafraichirHistorique();
  }

  void _rafraichirHistorique() {
    setState(() {
      _historiqueFuture = ref.read(sessionDataSourceProvider).getHistoriqueSessionsCloses();
    });
  }

  String _formaterMilliers(double montant) {
    return montant.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]} '
    );
  }

  Future<void> _declencherSynchronisationGlobale() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final Map<String, int> bilanSync = await ref.read(syncServiceProvider).executerSyncMontanteRapportsZ();
      final int synchro = bilanSync['synchronisés'] ?? 0;

      if (!mounted) return;
      if (synchro > 0) {
        _rafraichirHistorique();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.successGreen,
            content: Text("🚀 Succès : $synchro Rapport(s) Z répliqué(s) sur PostgreSQL Cloud !"),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text("📁 Le grand livre local de l'étal est déjà synchronisé.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(backgroundColor: AppTheme.alertRed, content: Text("⚠️ Échec réseau : ${e.toString().replaceAll('Exception: ', '')}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Archives des Rapports Z', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkCharcoal,
        foregroundColor: AppTheme.cleanWhite,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Synchroniser avec le Cloud',
            onPressed: _declencherSynchronisationGlobale,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir la liste',
            onPressed: _rafraichirHistorique,
          )
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historiqueFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('🛑 Erreur lors du chargement des archives locales.'));
          }

          final List<Map<String, dynamic>> sessions = snapshot.data!;

          if (sessions.isEmpty) {
            return const Center(
              child: Text(
                '📁 Aucun Rapport Z archivé pour le moment.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal),
              ),
            );
          }

          // 🔑 NETTOYAGE : Un seul ListView.builder légitime conservé ici
          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final s = sessions[index];
              final int idSession = s['id_session'] as int;
              final double ecart = (s['ecart_caisse'] as num? ?? 0.0).toDouble();
              final double reel = (s['montant_reel'] as num? ?? 0.0).toDouble();
              final String nomManager = s['nom_gerant']?.toString().toUpperCase() ?? 'INCONNU';
              final double ventes = (s['total_ventes'] as num? ?? 0.0).toDouble();
              final double achats = (s['total_achats'] as num? ?? 0.0).toDouble();
              final double attendu = (s['montant_theo'] as num? ?? 0.0).toDouble();
              final bool isSynchronized = s['statut_sync'] == 1;
              
              return Card(
                color: AppTheme.cleanWhite,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: ecart == 0 ? AppTheme.successGreen : (ecart < 0 ? AppTheme.alertRed : Colors.orange),
                    foregroundColor: Colors.white,
                    child: Text('#$idSession', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Fermeture par : $nomManager",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkCharcoal),
                        ),
                      ),
                      // 🔑 PASTILLE CLOUD INTERNE VISIBLE
                      Icon(
                        isSynchronized ? Icons.cloud_done : Icons.cloud_queue,
                        size: 20,
                        color: isSynchronized ? AppTheme.successGreen : Colors.grey.shade400,
                      ),
                    ],
                  ),
                  subtitle: Text(
                    "Le ${s['date_heure_clot'].toString().substring(0, 16).replaceAll('T', ' à ')}",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  trailing: Text(
                    "${_formaterMilliers(reel)} F",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.darkCharcoal),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLigneDetails("Fonds Initial :", "${_formaterMilliers((s['montant_init'] as num).toDouble())} F"),
                          _buildLigneDetails("Total Ventes (+):", "${_formaterMilliers(ventes)} F", color: AppTheme.successGreen),
                          _buildLigneDetails("Total Dépenses (-):", "${_formaterMilliers(achats)} F", color: AppTheme.alertRed),
                          const Divider(height: 16),
                          _buildLigneDetails("Solde Théorique :", "${_formaterMilliers(attendu)} F"),
                          _buildLigneDetails("Encaissé Réel :", "${_formaterMilliers(reel)} F", isBold: true),
                          _buildLigneDetails(
                            "Écart de caisse :", 
                            "${ecart > 0 ? '+' : ''}${_formaterMilliers(ecart)} F",
                            color: ecart == 0 ? AppTheme.successGreen : AppTheme.alertRed,
                            isBold: true
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.darkCharcoal,
                                    side: const BorderSide(color: AppTheme.darkCharcoal),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.print, size: 16),
                                  label: const Text("IMPRIMER TICKET", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    await PrinterService().imprimerRapportZSession(
                                      idSession: idSession,
                                      nomManager: s['nom_gerant']?.toString() ?? 'Manager',
                                      ventes: ventes,
                                      achats: achats,
                                      attendu: attendu,
                                      reel: reel,
                                      ecart: ecart,
                                    );
                                    messenger.showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppTheme.darkCharcoal,
                                        content: Text("🖨️ Ordre d'impression envoyé pour le Rapport Z #$idSession."),
                                      ),
);
},
),
),
const SizedBox(width: 10),
Expanded(
child: ElevatedButton.icon(
style: ElevatedButton.styleFrom(
backgroundColor: Colors.green.shade700,
foregroundColor: Colors.white,
padding: const EdgeInsets.symmetric(vertical: 12),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
),
icon: const Icon(Icons.share, size: 16),
label: const Text("ENVOYER WHATSAPP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
onPressed: () => _partagerRapportZArchives(s),
),
),
],
),
],
),
)
],
),
);
},
);
},
),
);
}
Widget _buildLigneDetails(String label, String valeur, {Color? color, bool isBold = false}) {
return Padding(
padding: const EdgeInsets.symmetric(vertical: 3),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
Text(
valeur,
style: TextStyle(
fontSize: 12,
fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
color: color ?? AppTheme.darkCharcoal
)
),
],
),
);
}
Future _partagerRapportZArchives(Map<String, dynamic> session) async {
final pdf = pw.Document();
final int idSession = session['id_session'] as int;
pdf.addPage(
pw.Page(
pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
build: (pw.Context context) {
return pw.Column(
crossAxisAlignment: pw.CrossAxisAlignment.start,
children: [
pw.Center(child: pw.Text("ARCHIVE RAPPORT Z", style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
pw.Center(child: pw.Text("SESSION #$idSession", style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
pw.Divider(borderStyle: pw.BorderStyle.dashed),
pw.Text("Ouvert le  : ${session['date_heure_ouv'].toString().substring(0, 16).replaceAll('T', ' ')}", style: const pw.TextStyle(fontSize: 7)),
pw.Text("Clôturé le : ${session['date_heure_clot'].toString().substring(0, 16).replaceAll('T', ' ')}", style: const pw.TextStyle(fontSize: 7)),
pw.Text("Signataire : ${session['nom_gerant'].toString().toUpperCase()}", style: const pw.TextStyle(fontSize: 7)),
pw.Divider(borderStyle: pw.BorderStyle.dashed),
_buildLignePdf("Fonds Initial :", "${session['montant_init'].toInt()} F"),
_buildLignePdf("Ventes (+)    :", "${(session['total_ventes'] ?? 0.0).toInt()} F"),
_buildLignePdf("Dépenses (-)  :", "${(session['total_achats'] ?? 0.0).toInt()} F"),
pw.Divider(borderStyle: pw.BorderStyle.dotted),
_buildLignePdf("Solde Théorique:", "${session['montant_theo'].toInt()} F"),
_buildLignePdf("Encaissé Réel  :", "${session['montant_reel'].toInt()} F"),
_buildLignePdf("Écart de Caisse:", "${session['ecart_caisse'].toInt()} F"),
pw.SizedBox(height: 10),
pw.Center(child: pw.Text("--- Archive Certifiée Étal ---", style: const pw.TextStyle(fontSize: 6, fontStyle: pw.FontStyle.italic))),
],
);
},
),
);
try {
final directory = await getTemporaryDirectory();
final String path = "${directory.path}/archive_rapport_z_session$idSession.pdf";
final file = File(path);
await file.writeAsBytes(await pdf.save());
await Share.shareXFiles(
[XFile(path)],
text: '📊 Rappel Archive Rapport Z - Session #$idSession\nSigné par : ${session['nom_gerant']}',
);
} catch (e) {
debugPrint("🛑 [Archive Export] Échec : $e");
}
}
pw.Widget _buildLignePdf(String label, String valeur) {
return pw.Padding(
padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
child: pw.Row(
mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
children: [
pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
pw.Text(valeur, style: const pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
],
),
);
}
}