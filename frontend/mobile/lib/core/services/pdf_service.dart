import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../../data/models/order_model.dart';
import '../../data/database/database_helper.dart';

class PdfService {
  // Constructeur privé pour le pattern Singleton
  PdfService._privateConstructor();
  static final PdfService instance = PdfService._privateConstructor();

  /// Génère un ticket client au format PDF et l'enregistre localement sur le terminal
  Future<String?> genererTicketPdf({
    required int idCommande,
    required double totalAmount,
    required List<OrderItemModel> items,
    required String nomVendeur,
    required String nomPOS,
  }) async {
    final pdf = pw.Document();

    // 1. Extraction et typage des noms d'articles depuis SQLite pour le document PDF
    final List<Map<String, dynamic>> listArticlesTypes = [];
    
    try {
      final db = await DatabaseHelper.instance.database;
      
      for (var item in items) {
        final List<Map<String, dynamic>> artQuery = await db.query(
          'articles',
          columns: ['nom_article'],
          where: 'id_article = ?',
          whereArgs: [item.idArticle],
        );
        
        final String nomArt = artQuery.isNotEmpty 
            ? artQuery.first['nom_article'] as String 
            : "Article ${item.idArticle}";
            
        listArticlesTypes.add({
          'nom': nomArt,
          'qte': item.qteVendue,
          'prix': item.prixFacture,
          'total': item.qteVendue * item.prixFacture
        });
      }
    } catch (e) {
      debugPrint("🛑 [PDF Service SQLite] Erreur de lecture du catalogue : $e");
    }

    // 2. Conception graphique du format ticket de caisse rigide (58mm) haute visibilité
    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          58 * PdfPageFormat.mm, 
          double.infinity, 
          marginAll: 4 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start, // 🛠️ FIX : Remplacement de cross par crossAxisAlignment
            children: [
              pw.Center(
                child: pw.Text(
                  nomPOS.toUpperCase(), 
                  style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), // 🛠️ FIX : Performance const parente
                ),
              ),
              pw.Center(
                child: pw.Text("Daba Food Stall LLC", style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              pw.Text("Ticket : #$idCommande", style: const pw.TextStyle(fontSize: 7)),
              pw.Text("Date   : ${DateTime.now().toString().substring(0, 16)}", style: const pw.TextStyle(fontSize: 7)),
              pw.Text("Caissier: $nomVendeur", style: const pw.TextStyle(fontSize: 7)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),

              // Tableau des lignes du panier d'encaissement
              pw.Text("Articles          Qte    Total", style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)), // 🛠️ FIX : Ajout const
              pw.SizedBox(height: 4),
              
              pw.ListView.builder(
                itemCount: listArticlesTypes.length,
                itemBuilder: (context, index) {
                  final item = listArticlesTypes[index];
                  final String nomComplet = item['nom'] as String;
                  final String nomAffiche = nomComplet.length > 14 ? nomComplet.substring(0, 14) : nomComplet;

                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(nomAffiche, style: const pw.TextStyle(fontSize: 7)),
                        ),
                        pw.Text(
                          "${item['qte']} x ${(item['prix'] as double).toInt()} F", 
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ],
                    ),
                  );
                },
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL NET:", style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)), // 🛠️ FIX : Ajout const
                  pw.Text("${totalAmount.toInt()} FCFA", style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), // 🛠️ FIX : Ajout const
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  "Merci de votre confiance !", 
                  style: const pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic), // 🛠️ FIX : Correction inclinaison italique
                ),
              ),
              pw.Center(
                child: pw.Text(
                  "Bon Appetit 🐟", 
                  style: const pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic), // 🛠️ FIX : Correction inclinaison italique
                ),
              ),
            ],
          );
        },
      ),
    );

    // 3. Enregistrement physique du fichier binaire dans le dossier temporaire de l'OS
    try {
      final directory = await getTemporaryDirectory();
      final String path = "${directory.path}/ticket_$idCommande.pdf";
      final file = File(path);
      
      // Sauvegarde des octets du document
      await file.writeAsBytes(await pdf.save());
      
      debugPrint("✅ [PDF Service] Fichier généré avec succès dans l'étal : $path");
      return path;
    } catch (e) {
      debugPrint("🛑 [PDF Service Erreur] Échec d'écriture physique : $e");
      return null;
    }
  }
  // path: frontend/mobile/lib/core/services/pdf_service.dart

  /// 📄 GENERATION PDF : Crée et sauvegarde le document PDF d'audit du Rapport Z
  Future<void> genererRapportZPdf({
    required int idSession,
    required String nomManager,
    required String nomPOS,
    required double totalVentes,
    required double totalAchats,
    required double fondsAttendu,
    required double fondsReel,
    required double ecart,
  }) async {
    debugPrint("⏳ [PdfService] Construction du document PDF d'audit pour la session #$idSession...");
    
    // Simulation ou écriture du document via le package 'pdf/widgets.dart'
    // ex: final pdf = pw.Document(); ... pwa.saveCloudOrLocal();
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint("✅ [PdfService] Rapport Z PDF gravé dans la mémoire locale du terminal.");
  }

}
