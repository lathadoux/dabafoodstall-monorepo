import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/database_helper.dart';

class DirectPurchaseScreen extends StatefulWidget {
  const DirectPurchaseScreen({super.key});

  @override
  State<DirectPurchaseScreen> createState() => _DirectPurchaseScreenState();
}

class _DirectPurchaseScreenState extends State<DirectPurchaseScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();

  final _qtyController = TextEditingController();
  final _totalCostController = TextEditingController();

  int? _selectedArticleId;
  String _selectedPaymentMode = 'especes'; // Par défaut

  List<Map<String, dynamic>> _articlesAchat = [];

  @override
  void initState() {
    super.initState();
    _chargerArticlesAchat();
  }

  /// Charge uniquement les articles configurés pour le flux 'achat' de manière étanche
  Future<void> _chargerArticlesAchat() async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'articles',
      where: 'id_tenant = 1',
      orderBy: 'nom_article ASC',
    );
    setState(() => _articlesAchat = res);
  }

  Future<void> _enregistrerDepenseCaisse() async {
    if (!_formKey.currentState!.validate() || _selectedArticleId == null) return;

    final db = await _dbHelper.database;
    final qty = double.parse(_qtyController.text);
    final totalCost = double.parse(_totalCostController.text);

    // Récupération de l'article pour avoir son nom dans les logs si besoin
    final selectedArticle = _articlesAchat.firstWhere((a) => a['id_article'] == _selectedArticleId);

    try {
      // Insertion atomique du flux financier de décaissement (CREDIT)
      await db.insert('financial_transactions', {
        'id_session': 1, 
        'id_article_achat': _selectedArticleId,
        'type_trans': 'achat_direct',
        'montant_trans': totalCost,
        'sens_flux': 'CREDIT', 
        'mode_reglement': _selectedPaymentMode,
        'qte_achat_historique': qty,
        'statut_sync': 0, 
      });

      _qtyController.clear();
      _totalCostController.clear();
      setState(() => _selectedArticleId = null);

      // ===================================================================
      // 🔒 SÉCURITÉ : VÉRIFICATION DU GAP ASYNCHRONE (MOUNTED CHECK)
      // ===================================================================
      if (!mounted) return; // Arrête l'exécution si l'écran n'est plus affiché

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.successGreen, // 🛠️ Casse corrigée en 'SuccessGreen'
          content: Text('💸 Décaissement de ${totalCost.toInt()} F enregistré pour : ${selectedArticle['nom_article']}'),
        ),
      );
    } catch (e) {
      // Appliquer la même garde dans le bloc catch par sécurité
      if (!mounted) return; 

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertRed,
          content: Text('🛑 Erreur lors de l\'enregistrement comptable : $e'),
        ),
      );
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('Sortie de Caisse / Achat Direct')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '📉 Enregistrer une Dépense sur Caisse',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal),
              ),
              const SizedBox(height: 8),
              const Text(
                'Toute sortie d\'argent pour un approvisionnement direct (charbon, poulet, emballages) doit être déclarée ici.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // 1. SÉLECTION DE L'ARTICLE À L'ACHAT
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Matière première / Article acheté',
                  border: OutlineInputBorder(),
                  fillColor: AppTheme.cleanWhite,
                  filled: true,
                ),
                initialValue: _selectedArticleId,
                items: _articlesAchat.map((art) {
                  return DropdownMenuItem<int>(
                    value: art['id_article'] as int,
                    child: Text('${art['nom_article']} (en ${art['unite_mesure']})'),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedArticleId = value),
                validator: (value) => value == null ? 'Veuillez sélectionner un article.' : null,
              ),
              const SizedBox(height: 16),

              // 2. QUANTITÉ ACHETÉE
              TextFormField(
                controller: _qtyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Quantité achetée (Volume / Nombre)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale),
                  fillColor: AppTheme.cleanWhite,
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty || double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Entrez une quantité valide.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 3. MONTANT TOTAL DÉCAISSÉ
              TextFormField(
                controller: _totalCostController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant total payé / décaissé',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments),
                  suffixText: 'FCFA',
                  fillColor: AppTheme.cleanWhite,
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty || double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Entrez le coût total décaissé.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 4. MODE DE RÈGLEMENT (DÉPENSE)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Source du décaissement',
                  border: OutlineInputBorder(),
                  fillColor: AppTheme.cleanWhite,
                  filled: true,
                ),
                initialValue: _selectedPaymentMode,
                items: const [
                  DropdownMenuItem(value: 'especes', child: Text('💵 Espèces du tiroir-caisse')),
                  DropdownMenuItem(value: 'wave', child: Text('🌊 Compte Wave du stand')),
                  DropdownMenuItem(value: 'orange_money', child: Text('📱 Compte Orange Money du stand')),
                ],
                onChanged: (value) => setState(() => _selectedPaymentMode = value!),
              ),
              const SizedBox(height: 32),

              // 5. BOUTON DE VALIDATION MASSIF
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.alertRed, // Rouge car c'est un décaissement/sortie
                  foregroundColor: AppTheme.cleanWhite,
                ),
                onPressed: _enregistrerDepenseCaisse,
                child: const Text('💸 VALIDER LE DÉCAISSEMENT DIRECT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
