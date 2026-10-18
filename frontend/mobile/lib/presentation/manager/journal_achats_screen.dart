// path: frontend/mobile/lib/presentation/journal/journal_achats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/datasources/analytics_data_source.dart';
import '../../core/services/journal_export_service.dart';
//import '../../data/datasources/sales_data_source.dart';

class JournalAchatsScreen extends ConsumerStatefulWidget {
  const JournalAchatsScreen({super.key});

  @override
  ConsumerState<JournalAchatsScreen> createState() => _JournalAchatsScreenState();
}

class _JournalAchatsScreenState extends ConsumerState<JournalAchatsScreen> {
  late Future<List<Map<String, dynamic>>> _achatsFuture;
  int _nombreBons = 0;

  @override
  void initState() {
    super.initState();
    _rafraichirJournal();
  }

  void _rafraichirJournal() async {
    setState(() {
      _achatsFuture = ref.read(analyticsDataSourceProvider).getJournalAchatsConsolideSession();
    });
    final int bons = await ref.read(analyticsDataSourceProvider).getNombreBonsAchatsSessionActive();
    if (mounted) setState(() => _nombreBons = bons);
  }

  String _formater(double mnt) => mnt.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m.group(1)} ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Journal des Dépenses & Intrants', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkCharcoal,
        foregroundColor: AppTheme.cleanWhite,
// path: frontend/mobile/lib/presentation/manager/journal_achats_screen.dart

        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent), 
            onPressed: () async {
              final d = await _achatsFuture; 
              if (d.isNotEmpty) JournalExportService.instance.exporterEtPartagerPdf(d, isVentes: false);
            }
          ),
// path: frontend/mobile/lib/presentation/manager/journal_achats_screen.dart

          IconButton(
            icon: const Icon(Icons.print, color: AppTheme.primaryAmber), 
            onPressed: () async {
              final d = await _achatsFuture; 
              
              // 🛠️ FIX DE COMPILATION RECTIFIÉ : Validation directe de l'intégrité du BuildContext
              if (!context.mounted) return; 
              
              if (d.isNotEmpty) JournalExportService.instance.imprimerThermique(context, d, isVentes: false);
            }
          ),

          IconButton(icon: const Icon(Icons.refresh), onPressed: _rafraichirJournal)
        ],

      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _achatsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber));
          if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('🛑 Erreur journal des achats.'));
          final List<Map<String, dynamic>> lignes = snapshot.data!;
          if (lignes.isEmpty) return const Center(child: Text('💸 Aucune dépense enregistrée.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)));

          final Map<String, Map<String, List<Map<String, dynamic>>>> structure = {};
          final Map<String, double> totaux = {};
          double totalGeneral = 0.0;

          for (var r in lignes) {
            final String aut = r['nom_user'] as String? ?? "NON IDENTIFIÉ";
            final String fam = r['nom_famille'] as String;
            final double mnt = (r['montant_total'] as num).toDouble();
            structure.putIfAbsent(aut, () => {}).putIfAbsent(fam, () => []).add(r);
            totaux[aut] = (totaux[aut] ?? 0.0) + mnt;
            totalGeneral += mnt;
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: structure.keys.length,
                  itemBuilder: (context, idx) {
                    final String aut = structure.keys.elementAt(idx);
                    final double totalAut = totaux[aut]!;
                    return Card(
                      color: AppTheme.cleanWhite,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text("SORTIE PAR : ${aut.toUpperCase()}", style: const TextStyle(color: AppTheme.alertRed, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('${_formater(totalAut)} F', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ]),
                            const Divider(height: 20),
                            ...structure[aut]!.keys.map((fam) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(fam.toUpperCase(), style: const TextStyle(color: AppTheme.primaryAmber, fontWeight: FontWeight.bold, fontSize: 11)),
                              ...structure[aut]![fam]!.map((art) => Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
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
                color: const Color(0xFF2A1414),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    const Text('TOTAL SORTIES DE CAISSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Volume Global : $_nombreBons bon(s)', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                  ]),
                  Text('${_formater(totalGeneral)} FCFA', style: const TextStyle(color: AppTheme.cleanWhite, fontWeight: FontWeight.w900, fontSize: 18)),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
