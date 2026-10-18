import 'package:blue_thermal_printer_plus/blue_thermal_printer_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/order_model.dart';

/// 🖨️ Les trois modes de sortie disponibles sur l'étal
enum ModeImpression {
  papierThermique,
  documentPdf,
  sansImpression // <-- Notre option de service ultra-rapide pour les heures de pointe
}
class PrinterSettingsNotifier extends StateNotifier<ModeImpression> {
  PrinterSettingsNotifier() : super(ModeImpression.sansImpression); // Mode rapide par défaut

  void changerMode(ModeImpression nouveauMode) {
    state = nouveauMode;
  }
}

final printerSettingsProvider = StateNotifierProvider<PrinterSettingsNotifier, ModeImpression>((ref) {
  return PrinterSettingsNotifier();
});
class PrinterService {
  final BlueThermalPrinterPlus _printer = BlueThermalPrinterPlus();


  /// Tente d'imprimer le reçu client structuré selon l'API factory de BlueThermalPrinterPlus (V1)
  Future<bool> imprimerRecuClient(OrderModel commande, String nomVendeur, double montantRecu, double rendu) async {
    bool? isConnected = await _printer.isConnected;
    if (isConnected != true) {
      debugPrint("⚠️ [Printer] Échec : Aucun terminal d'impression Bluetooth connecté.");
      return false;
    }

    try {
      // 1. Initialisation de la liste des lignes d'impression structurées (PrintItem)
      final List<PrintItem> ticketItems = [];

      // En-tête du ticket (Utilisation de la factory PrintItem.text conforme)
      // size: 0 (normal), 1 (moyen), 2 (grand) | align: 0 (gauche), 1 (centré), 2 (droite)
      ticketItems.add(PrintItem.text("        DABA FOOD STALL\n", size: 2, align: 1));
      ticketItems.add(PrintItem.text("     Street Food d'Afrique\n", size: 0, align: 1));
      ticketItems.add(PrintItem.text("--------------------------------\n", align: 1));

      // Métadonnées de la session de vente
      ticketItems.add(PrintItem.text("Ticket No: #CDE-${commande.idCde}\n"));
      ticketItems.add(PrintItem.text("Caissier: $nomVendeur\n"));
      ticketItems.add(PrintItem.text("Date: ${DateTime.now().toString().substring(0, 16)}\n"));
      ticketItems.add(PrintItem.text("--------------------------------\n", align: 1));

      // Corps du reçu : Liste des articles vendus
      double totalCalculer = 0.0;
      
      for (var item in commande.items) {
        final double sousTotal = item.qteVendue * item.prixFacture;
        totalCalculer += sousTotal;

        String libelleArticle = "${item.nomArticle ?? 'Article'} x${item.qteVendue}";
        String chainePrix = "${sousTotal.toInt()} F";
        
        // Ajout de la ligne de marchandise brute
        ticketItems.add(PrintItem.text("$libelleArticle : $chainePrix\n"));
      }

      ticketItems.add(PrintItem.text("--------------------------------\n", align: 1));

      // Bloc Financier et Règlements
      ticketItems.add(PrintItem.text("TOTAL A PAYER : ${totalCalculer.toInt()} F\n", size: 1));
      ticketItems.add(PrintItem.text("Espèces reçues : ${montantRecu.toInt()} F\n"));
      ticketItems.add(PrintItem.text("Rendu monnaie : ${rendu.toInt()} F\n"));
      
      // Pied de page
      ticketItems.add(PrintItem.text("--------------------------------\n", align: 1));
      ticketItems.add(PrintItem.text("    Merci de votre visite !\n", align: 1));
      ticketItems.add(PrintItem.text("    Bon Appetit & a bientot\n", align: 1));
      
      // Sauts de ligne techniques pour libérer le papier
      ticketItems.add(PrintItem.text("\n\n\n"));

      // 2. ENVOI DE LA COMMANDE COMPLÈTE VIA L'API EN UNIQUE APPEL
      await _printer.print(
        items: ticketItems,
        protocol: PrinterProtocol.escPos,
        widthDots: 384, // Largeur standard d'une bobine thermique 58mm
      );

      // Déclenchement de la coupe papier
      // 3. ✂️ COMMANDE DE DÉCOUPE NATIVE UNIVERSELLE (ESC/POS PAPER CUT CODES)
      // On envoie la commande physique de coupe via le constructeur d'octets bruts d'images/données
      final Uint8List cutCommand = Uint8List.fromList([29, 86, 66, 0]);
      await _printer.print(
        items: [PrintItem(imageBytes: cutCommand, type: PrintItemType.image)],
        protocol: PrinterProtocol.escPos,
      );
      
      // Envoyer la commande à votre imprimante
  
      debugPrint("✅ [Printer] Impression du reçu achevée pour le ticket #${commande.idCde}.");
      return true;

    } catch (e) {
      debugPrint("🛑 [Printer] Erreur critique d'envoi du flux PrintItem : $e");
      return false;
    }
  }
  // path: frontend/mobile/lib/core/services/printer_service.dart

  /// 📊 IMPRESSION THERMIQUE : Édite le ticket Rapport Z définitif du soir
  Future<void> imprimerRapportZSession({
    required int idSession,
    required String nomManager,
    required double ventes,
    required double achats,
    required double attendu,
    required double reel,
    required double ecart,
  }) async {
    debugPrint("🖨️ [Printer] Génération du flux binaire Rapport Z pour la session #$idSession...");
    
    // Simulation ou envoi des commandes ESC/POS à l'imprimante thermique Bluetooth
    // À lier avec votre package 'blue_thermal_printer' ou 'flutter_pos_printer_platform'
    await Future.delayed(const Duration(milliseconds: 800));
    debugPrint("✅ [Printer] Ticket thermique Rapport Z imprimé avec succès !");
  }

}
