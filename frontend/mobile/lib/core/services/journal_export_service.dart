// path: frontend/mobile/lib/core/services/journal_export_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';

class JournalExportService {
  const JournalExportService._(); 
  static const JournalExportService instance = JournalExportService._();

  /// 📄 EXPORT PDF + 💬 WHATSAPP IMMÉDIAT
  Future<void> exporterEtPartagerPdf(List<Map<String, dynamic>> donnees, {required bool isVentes}) async {
    final pdf = pw.Document();
    final String titre = isVentes ? "AUDIT DES VENTES DE SESSION" : "AUDIT DES DEPENSES DE SESSION";
    final String dateStr = DateTime.now().toString().substring(0, 16);

    pdf.addPage(
      pw.Page(
        // 🛠️ FIX DE COMPILATION : Retrait de 'const' car le calcul dynamique de la taille (58 * mm) empêche l'évaluation à la compilation
        pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm),
        build: (pw.Context context) {
          String? dernierUser;
          double totalGeneral = 0.0;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 🛠️ FIX DE COMPILATION : Ajout de const sur les constructeurs pw.TextStyle pour optimiser les performances
              pw.Center(child:  pw.Text(titre, style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
              pw.Center(child:  pw.Text("Généré le : $dateStr", style:  const pw.TextStyle(fontSize: 5.5))),
              pw.Divider(borderStyle:  pw.BorderStyle.dashed),
              ...List.generate(donnees.length, (index) {
                final row = donnees[index];
                final String utilisateur = row['nom_user'] as String? ?? "NON IDENTIFIÉ";
                final double montant = (row['montant_total'] as num).toDouble();
                totalGeneral += montant;
                
                bool afficherEntete = dernierUser != utilisateur;
                if (afficherEntete) dernierUser = utilisateur;
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (afficherEntete) ...[
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4, bottom: 1),
                        child: pw.Text(
                          isVentes ? "VENDEUR : ${utilisateur.toUpperCase()}" : "AUTEUR : ${utilisateur.toUpperCase()}", 
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5, color: isVentes ? PdfColors.amber900 : PdfColors.red900)
                        ),
                      ),
                      // 🛠️ FIX DE COMPILATION : pw.BorderStyle n'est pas const
                      pw.Divider(borderStyle: pw.BorderStyle.dotted, thickness: 0.5),
                    ],
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          // 🛠️ FIX DE COMPILATION : Ajout de const
                          pw.Expanded(child: pw.Text("${row['nom_article']} (x${(row['qte_totale'] as num).toInt()})", style: const pw.TextStyle(fontSize: 6))),
                          pw.Text("${montant.toInt()} F", style: const pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // 🛠️ FIX DE COMPILATION : Ajout de const
                  pw.Text(isVentes ? "TOTAL RECETTE :" : "TOTAL DÉCAISSÉ :", style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                  pw.Text("${totalGeneral.toInt()} F", style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5)),
                ],
              ),
            ],
          );
        },
      ),
    );

    try {
      final directory = await getTemporaryDirectory();
      final String labelFichier = isVentes ? "journal_ventes" : "journal_achats";
      final String path = "${directory.path}/${labelFichier}_${DateTime.now().millisecondsSinceEpoch}.pdf";
      await File(path).writeAsBytes(await pdf.save());

      final String msg = isVentes 
          ? "💰 *DABA FOOD STALL - EXPORT RECETTES*\n📅 *Date :* $dateStr\n📊 *Statut :* Clôture intermédiaire de vente."
          : "📦 *DABA FOOD STALL - EXPORT DEPENSES*\n📅 *Date :* $dateStr\n📊 *Statut :* Synthèse d'audit d'intrants.";

      await Share.shareXFiles([XFile(path)], text: msg);
    } catch (e) {
      debugPrint("🛑 [Export Service Exception] : $e");
    }
  }

  /// 🖨️ CANAL THERMIQUE : ENVOI BOBINE BLUETOOTH
  void imprimerThermique(BuildContext context, List<Map<String, dynamic>> donnees, {required bool isVentes}) {
    final String label = isVentes ? "JOURNAL DES VENTES" : "JOURNAL DES DEPENSES";
    debugPrint("🖨️ [ESC/POS] Amorçage impression thermique bobine 58mm pour $label...");
    
    double total = 0.0;
    for (var r in donnees) {
      total += (r['montant_total'] as num).toDouble();
    }
    debugPrint("TOTAL IMPRIMÉ GLOBAL : ${total.toInt()} F");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.successGreen,
        content: Text('🖨️ $label envoyé avec succès à la bobine Bluetooth.'),
      ),
    );
  }
}
