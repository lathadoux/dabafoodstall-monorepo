import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/database_helper.dart';

class CatalogManagementScreen extends StatefulWidget {
  const CatalogManagementScreen({super.key});

  @override
  State<CatalogManagementScreen> createState() => _CatalogManagementScreenState();
}

class _CatalogManagementScreenState extends State<CatalogManagementScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _articleFormKey = GlobalKey<FormState>();
  final _familleFormKey = GlobalKey<FormState>();

  final _nomArticleController = TextEditingController();
  final _prixController = TextEditingController();
  final _nomFamilleController = TextEditingController();

  final String _selectedUnit = 'pcs';
   String _selectedType = 'vente';
  int? _selectedFamilleId;
  List<Map<String, dynamic>> _familles = [];
  
  @override
  void initState() {
    super.initState();
    _chargerFamilles();
  }

  Future<void> _chargerFamilles() async {
    final db = await _dbHelper.database;
    final res = await db.query('familles', where: 'id_tenant = 1');
    setState(() => _familles = res);
  }

  Future<void> _creerFamille() async {
    if (!_familleFormKey.currentState!.validate()) return;
    final db = await _dbHelper.database;
    try {
      await db.insert('familles', {
        'id_tenant': 1, 
        'nom_famille': _nomFamilleController.text.trim()
      });
      _nomFamilleController.clear();
      _chargerFamilles();
      
      // ===================================================================
      // 🔒 GARDE SÉCURITÉ : VÉRIFICATION DU BLOCAGE ASYNCHRONE
      // ===================================================================
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.successGreen, // 🛠️ Casse corrigée
          content: Text('Famille ajoutée !'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.alertRed, // 🛠️ Casse corrigée
          content: Text('Erreur : Cette famille existe déjà.'),
        ),
      );
    }
  }

  Future<void> _creerArticle() async {
    if (!_articleFormKey.currentState!.validate()) return;
    final db = await _dbHelper.database;
    
    await db.insert('articles', {
      'id_tenant': 1,
      'id_famille': _selectedFamilleId,
      'nom_article': _nomArticleController.text.trim(),
      'prix_unitaire': double.parse(_prixController.text),
      'unite_mesure': _selectedUnit,
    });
    
    _nomArticleController.clear();
    _prixController.clear();
    
    // ===================================================================
    // 🔒 GARDE SÉCURITÉ : VÉRIFICATION DU BLOCAGE ASYNCHRONE
    // ===================================================================
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.successGreen, // 🛠️ Casse corrigée
        content: Text('📦 Article ajouté au catalogue !'),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('Gestion Catalogue V1')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- BLOC 1 : AJOUT DE FAMILLE ---
            Card(
              color: AppTheme.cleanWhite,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _familleFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('📁 Créer une Famille d\'Articles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nomFamilleController,
                        decoration: const InputDecoration(labelText: 'Nom de la famille (ex: Boissons)', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Entrez un nom.' : null,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _creerFamille, child: const Text('AJOUTER LA FAMILLE')),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- BLOC 2 : AJOUT D'ARTICLE ---
            Card(
              color: AppTheme.cleanWhite,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _articleFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('📦 Ajouter un Nouvel Article', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: 'Famille associée', border: OutlineInputBorder()),
                        initialValue: _selectedFamilleId,
                        items: _familles.map((f) => DropdownMenuItem<int>(value: f['id_famille'] as int, child: Text(f['nom_famille'].toString()))).toList(),
                        onChanged: (v) => setState(() => _selectedFamilleId = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nomArticleController,
                        decoration: const InputDecoration(labelText: 'Désignation de l\'article', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Entrez une désignation.' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Flux', border: OutlineInputBorder()),
                              initialValue: _selectedType,
                              items: const [DropdownMenuItem(value: 'vente', child: Text('À la Vente')), DropdownMenuItem(value: 'achat', child: Text('À l\'Achat'))],
                              onChanged: (v) => setState(() => _selectedType = v!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _prixController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Prix unitaire (F)', border: OutlineInputBorder()),
                              validator: (v) => v!.isEmpty ? 'Entrez un montant.' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.darkCharcoal, foregroundColor: AppTheme.cleanWhite),
                        onPressed: _creerArticle, 
                        child: const Text('VALIDER L\'INSCRIPTION DE L\'ARTICLE'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
