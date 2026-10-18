import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../auth/session_provider.dart';

class OuvertureCaisseScreen extends ConsumerStatefulWidget {
  const OuvertureCaisseScreen({super.key});

  @override
  ConsumerState<OuvertureCaisseScreen> createState() => _OuvertureCaisseScreenState();
}

class _OuvertureCaisseScreenState extends ConsumerState<OuvertureCaisseScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fondCaisseController = TextEditingController(text: "10000"); // Standard d'étal (10 000 F)

  /// Ajoute un montant rapide au fond de caisse existant
  void _ajouterMontantRapide(int valeur) {
    final int courant = int.tryParse(_fondCaisseController.text) ?? 0;
    setState(() {
      _fondCaisseController.text = (courant + valeur).toString();
    });
  }

  /// Initialisation physique de la journée en base locale SQLite
  void _validerEtOuvrirCaisse() async {
    if (!_formKey.currentState!.validate()) return;

    final double? montantSaisi = double.tryParse(_fondCaisseController.text);
    if (montantSaisi == null || montantSaisi < 0) return;

    // 💾 Mutation de l'état global et insertion automatique dans cash_sessions via Riverpod
    await ref.read(sessionProvider.notifier).initCaisse(
          montantSaisi, // Fond de caisse initial
          1,            // idTenant pilote
          1,            // idUser (Manager actuel)
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.successGreen,
        content: Text('🏪 Stand Initialisé ! Nouvelle session ouverte avec ${montantSaisi.toInt()} F.'),
      ),
    );

    // Évacuation de l'écran d'ouverture pour dévoiler le tableau de bord prêt
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _fondCaisseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Ouverture du Matin & Trésorerie'),
        backgroundColor: AppTheme.darkCharcoal,
        foregroundColor: AppTheme.cleanWhite,
        automaticallyImplyLeading: false, // Force le manager à prendre une décision
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Center(
                  child: Text('🪙', style: TextStyle(fontSize: 64)),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Initialisation du Stand",
                  textAlign: TextAlign.center, // 🛠️ FIX : Remplacement de Center par TextAlign.center
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Veuillez compter l'argent liquide physique (monnaie et billets) présent dans le tiroir-caisse avant de démarrer les ventes de la journée.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 32),

                // 🎯 Champ d'IHM principal pour le montant initial
                TextFormField(
                  controller: _fondCaisseController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'FONDS DE CAISSE INITIAL',
                    labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: OutlineInputBorder(),
                    suffixText: "FCFA",
                    suffixStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal),
                    filled: true,
                    fillColor: AppTheme.cleanWhite,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez saisir le montant de départ.';
                    }
                    final double? n = double.tryParse(value);
                    if (n == null || n < 0) {
                      return 'Veuillez renseigner un chiffre positif valide.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ⚡ RACCOURCIS DE MONTANTS RAPIDES POUR ACCÉLÉRER LA SAISIE
                const Text(
                  "Ajouter rapidement au tiroir-caisse :",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildRaccourciButton("+500 F", 500)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRaccourciButton("+1 000 F", 1000)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRaccourciButton("+2 000 F", 2000)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRaccourciButton("+5 000 F", 5000)),
                  ],
                ),
                
                const SizedBox(height: 48),

                // 🔥 Bouton massif d'engagement du service (🛠️ FIX : styleFrom nettoyé de tout const parent invalide)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                    foregroundColor: AppTheme.cleanWhite,
                    minimumSize: const Size.fromHeight(55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _validerEtOuvrirCaisse,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_open, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Text(
                        'INITIALISER ET OUVRIR LA CAISSE',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Bouton de sécurité annexe pour vider le champ
                TextButton(
                  onPressed: () => setState(() => _fondCaisseController.text = "0"),
                  child: const Text("Remettre à zéro le compteur", style: TextStyle(color: AppTheme.alertRed, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRaccourciButton(String label, int valeur) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.darkCharcoal,
        foregroundColor: AppTheme.cleanWhite,
        padding: const EdgeInsets.symmetric(vertical: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: () => _ajouterMontantRapide(valeur),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
