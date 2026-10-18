// path: frontend/mobile/lib/presentation/journal/journal_ventes_screen.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/analytics_data_source.dart';
//import '../../data/database/database_helper.dart';
import '../../core/services/journal_export_service.dart';

class JournalVentesScreen extends ConsumerStatefulWidget {
  const JournalVentesScreen({super.key});

  @override
  ConsumerState<JournalVentesScreen> createState() => _JournalVentesScreenState();
}

class _JournalVentesScreenState extends ConsumerState<JournalVentesScreen> {
  late Future<List<Map<String, dynamic>>> _journalFuture;
  int _nombreTickets = 0;

  @override
  void initState() {
    super.initState();
    _rafraichirJournal();
  }

  void _rafraichirJournal() async {
    setState(() {
      _journalFuture = ref.read(analyticsDataSourceProvider).getJournalVentesConsolideSession();
    });
    final int tks = await ref.read(analyticsDataSourceProvider).getNombreTicketsSessionActive();
    if (mounted) setState(() => _nombreTickets = tks);
  }

  String _formater(double mnt) => mnt.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m.group(1)} ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Journal des Ventes de Session', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkCharcoal,
        foregroundColor: AppTheme.cleanWhite,
// path: frontend/mobile/lib/presentation/manager/journal_ventes_screen.dart

        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent), 
            onPressed: () async {
              final d = await _journalFuture; 
              if (d.isNotEmpty) JournalExportService.instance.exporterEtPartagerPdf(d, isVentes: true);
            }
          ),
// path: frontend/mobile/lib/presentation/manager/journal_ventes_screen.dart

          IconButton(
            icon: const Icon(Icons.print, color: AppTheme.primaryAmber), 
            onPressed: () async {
              final d = await _journalFuture; 
              
              // 🛠️ FIX DE COMPILATION RECTIFIÉ : Validation directe de l'intégrité du BuildContext
              if (!context.mounted) return; 
              
              if (d.isNotEmpty) JournalExportService.instance.imprimerThermique(context, d, isVentes: true);
            }
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _rafraichirJournal)
        ],

      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _journalFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber));
          if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('🛑 Erreur journal local.'));
          final List<Map<String, dynamic>> lignes = snapshot.data!;
          if (lignes.isEmpty) return const Center(child: Text('🏪 Aucune vente enregistrée.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)));

          final Map<String, Map<String, List<Map<String, dynamic>>>> structure = {};
          final Map<String, double> totaux = {};
          double totalGeneral = 0.0;

          for (var r in lignes) {
            final String vnd = r['nom_user'] as String? ?? "NON IDENTIFIÉ";
            final String fam = r['nom_famille'] as String;
            final double mnt = (r['montant_total'] as num).toDouble();
            structure.putIfAbsent(vnd, () => {}).putIfAbsent(fam, () => []).add(r);
            totaux[vnd] = (totaux[vnd] ?? 0.0) + mnt;
            totalGeneral += mnt;
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: structure.keys.length,
                  itemBuilder: (context, idx) {
                    final String vnd = structure.keys.elementAt(idx);
                    final double totalVnd = totaux[vnd]!;
                    return Card(
                      color: AppTheme.cleanWhite,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text("👤 ${vnd.toUpperCase()}", style: const TextStyle(color: AppTheme.darkCharcoal, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('${_formater(totalVnd)} F', style: const TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.w900, fontSize: 14)),
                            ]),
                            const Divider(height: 20),
                            ...structure[vnd]!.keys.map((fam) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(fam.toUpperCase(), style: const TextStyle(color: AppTheme.primaryAmber, fontWeight: FontWeight.bold, fontSize: 11)),
                              ...structure[vnd]![fam]!.map((art) => Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Expanded(child: Text("${art['nom_article']} (x${(art['qte_totale'] as num).toInt()} ${art['unite_mesure']})", style: const TextStyle(fontSize: 12))),
                                Text("${_formater((art['montant_total'] as num).toDouble())} F", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              ])))
                            ]))
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.darkCharcoal,
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    const Text('TOTAL RECETTE NETTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Volume : $_nombreTickets ticket(s)', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                  ]),
                  Text('${_formater(totalGeneral)} FCFA', style: const TextStyle(color: AppTheme.primaryAmber, fontWeight: FontWeight.w900, fontSize: 18)),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
