// path: frontend/mobile/lib/presentation/close/close_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/database_helper.dart';
import 'widgets/cloture_header_card.dart';
import 'widgets/cloture_dialog_manager.dart';

class CloseScreen extends ConsumerStatefulWidget {
  const CloseScreen({super.key});

  @override
  ConsumerState<CloseScreen> createState() => CloseScreenState();
}

class CloseScreenState extends ConsumerState<CloseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cashPhysiqueController = TextEditingController();

  bool _isLoading = true;
  int _idSessionActive = 0;
  String _dateOuvertureSession = '';
  double _soldeTheoriqueAttendu = 0.0;
  double _chiffreAffairesTheorique = 0.0;
  double _totalAchatsCaisse = 0.0;
  double _ecartDeCaisse = 0.0;

  @override
  void initState() {
    super.initState();
    chargerDonneesSession();
  }

  Future<void> chargerDonneesSession() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> lastSession = await db.rawQuery(
          'SELECT id_session, montant_init, date_heure_ouv FROM cash_sessions WHERE date_heure_clot IS NULL ORDER BY id_session DESC LIMIT 1');

      if (lastSession.isNotEmpty) {
        _idSessionActive = lastSession.first['id_session'] as int;
        _dateOuvertureSession = lastSession.first['date_heure_ouv'] as String? ?? '';
        final double init = (lastSession.first['montant_init'] as num?)?.toDouble() ?? 0.0;

        final List<Map<String, dynamic>> queryVentes = await db.rawQuery('SELECT COALESCE(SUM(total_amount), 0.0) as total FROM orders WHERE id_session = ? AND statut_commande = "termine"', [_idSessionActive]);
        final List<Map<String, dynamic>> queryAchats = await db.rawQuery('SELECT COALESCE(SUM(oi.prix_facture * oi.qte_vendue), 0.0) as total FROM order_items oi JOIN orders o ON oi.id_cde = o.id_cde WHERE o.id_session = ? AND o.statut_commande = "achat"', [_idSessionActive]);

        _chiffreAffairesTheorique = (queryVentes.first['total'] as num?)?.toDouble() ?? 0.0;
        _totalAchatsCaisse = (queryAchats.first['total'] as num?)?.toDouble() ?? 0.0;
        _soldeTheoriqueAttendu = init + _chiffreAffairesTheorique - _totalAchatsCaisse;
      }
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("🛑 [Clôture Erreur] Agrégation échouée : $e");
      setState(() => _isLoading = false);
    }
  }

  void _calculerEcartCaisse(String value) {
    final double cashSaisi = double.tryParse(value.trim()) ?? 0.0;
    setState(() {
      _ecartDeCaisse = value.trim().isEmpty ? 0.0 : cashSaisi - _soldeTheoriqueAttendu;
    });
  }

  @override
  void dispose() {
    _cashPhysiqueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Clôture du Soir & Comptage', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkCharcoal,
        foregroundColor: AppTheme.cleanWhite,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClotureHeaderCard(idSession: _idSessionActive, dateOuverture: _dateOuvertureSession),
                      const SizedBox(height: 16),
                      Card(
                        margin: EdgeInsets.zero,
                        color: AppTheme.cleanWhite,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('🪙 Comptage du Cash Réel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal)),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _cashPhysiqueController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Montant total physique compté (F)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.monetization_on, size: 20)),
                                onChanged: _calculerEcartCaisse,
                                validator: (val) => val == null || val.trim().isEmpty ? 'Le montant physique est obligatoire.' : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_cashPhysiqueController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildIndicateurEcart(),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.darkCharcoal, foregroundColor: AppTheme.cleanWhite, minimumSize: const Size.fromHeight(50)),
                        icon: const Icon(Icons.lock_outline, size: 18),
                        label: const Text('VALIDER LA CLÔTURE DU STAND (RAPPORT Z)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          ClotureDialogManager.ouvrirBoiteScellement(
                            context: context,
                            ref: ref,
                            idSessionActive: _idSessionActive,
                            soldeTheoriqueAttendu: _soldeTheoriqueAttendu,
                            chiffreAffairesTheorique: _chiffreAffairesTheorique,
                            totalAchatsCaisse: _totalAchatsCaisse,
                            cashPhysiqueSaisi: double.parse(_cashPhysiqueController.text.trim()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildIndicateurEcart() {
    final bool isParfait = _ecartDeCaisse == 0;
    final bool isBonus = _ecartDeCaisse > 0;
    Color cardColor = isParfait ? AppTheme.successGreen : (isBonus ? AppTheme.primaryAmber : AppTheme.alertRed);
    String msg = isParfait ? "✅ Caisse parfaite ! Aucun écart constaté." : (isBonus ? "⚠️ Surplus constaté : +${_ecartDeCaisse.toInt()} F" : "🛑 Manquant constaté : ${_ecartDeCaisse.toInt()} F");
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: cardColor, width: 1.2)),
      child: Text(msg, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isParfait ? AppTheme.successGreen : (isBonus ? Colors.amber.shade900 : AppTheme.alertRed))),
    );
  }
}
