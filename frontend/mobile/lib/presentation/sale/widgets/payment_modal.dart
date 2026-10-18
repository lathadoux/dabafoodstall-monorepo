import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PaymentModal extends StatefulWidget {
  final double totalAmount;
  final VoidCallback onPaymentValidated;

  const PaymentModal({
    super.key,
    required this.totalAmount,
    required this.onPaymentValidated,
  });

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  double _montantRecu = 0.0;
  String _modeReglement = "ESPECES"; // "ESPECES", "MOBILE_MONEY", "CARTE"

  // Listes des coupures officielles de la zone FCFA (Spécifications Terrain V1)
  final List<int> _pieces = [50,100, 200, 500];
  final List<int> _billets = [500, 1000, 2000, 5000,10000];

  double get _renduMonnaie {
    if (_montantRecu < widget.totalAmount) return 0.0;
    return _montantRecu - widget.totalAmount;
  }

  /// Incrémente le montant reçu lorsqu'on clique sur une pièce ou un billet
  void _ajouterCoupure(int valeur) {
    setState(() {
      _montantRecu += valeur;
    });
  }

  @override
  Widget build(BuildContext context) {
    // S'ajuste automatiquement si le clavier système s'allume
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête de l'IHM d'encaissement
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '⚡ Règlement Commande',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const Divider(),

            // Affichage du Net à Payer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('NET A PAYER :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  '${widget.totalAmount.toInt()} F',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primaryAmber),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Sélecteur de mode de règlement (Onglets tactiles)
            Row(
              children: [
                _buildModeButton("ESPECES", Icons.money, "Espèces"),
                const SizedBox(width: 8),
                _buildModeButton("MOBILE_MONEY", Icons.phone_android, "Momo"),
                const SizedBox(width: 8),
                _buildModeButton("CARTE", Icons.credit_card, "Carte"),
              ],
            ),
            const SizedBox(height: 20),

            // ===================================================================
            // SECTION ESPÈCES : CLAVIER DE COUPURES FCFA DYNAMIQUE
            // ===================================================================
            if (_modeReglement == "ESPECES") ...[
              const Text('🪙 Pièces (FCFA) :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              Row(
                children: _pieces.map((p) => _buildCoupureChip(p, isBillet: false)).toList(),
              ),
              const SizedBox(height: 12),

              const Text('💵 Billets (FCFA) :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _billets.map((b) => _buildCoupureChip(b, isBillet: true)).toList(),
              ),
              const SizedBox(height: 16),

              // Zone de saisie manuelle alternative & indicateurs comptables
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Montant reçu', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('${_montantRecu.toInt()} F', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _renduMonnaie > 0 ? Colors.green.withValues(alpha: 0.05) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _renduMonnaie > 0 ? AppTheme.successGreen : Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rendu monnaie', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            '${_renduMonnaie.toInt()} F', 
                            style: TextStyle(
                              fontSize: 20, 
                              fontWeight: FontWeight.bold, 
                              color: _renduMonnaie > 0 ? AppTheme.successGreen : AppTheme.darkCharcoal
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Bouton d'effacement rapide de la monnaie reçue
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _montantRecu = 0.0),
                  icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
                  label: const Text('Réinitialiser la monnaie', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Bouton de validation finale du ticket de caisse
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkCharcoal,
                foregroundColor: AppTheme.cleanWhite,
                minimumSize: const Size.fromHeight(50),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              // Désactivé en espèces si le compte n'y est pas
              onPressed: (_modeReglement == "ESPECES" && _montantRecu < widget.totalAmount)
                  ? null
                  : () {
                      widget.onPaymentValidated();
                      Navigator.pop(context);
                    },
              child: Text(
                _modeReglement == "ESPECES"
                    ? 'VALIDER ET IMPRIMER LE REÇU (Rendu : ${_renduMonnaie.toInt()} F)'
                    : 'VALIDER L\'ENCAISSEMENT DIRECT',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String mode, IconData icon, String label) {
    final bool isSelected = _modeReglement == mode;
    return Expanded(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? AppTheme.darkCharcoal : AppTheme.cleanWhite,
          foregroundColor: isSelected ? AppTheme.cleanWhite : AppTheme.darkCharcoal,
          side: BorderSide(color: isSelected ? AppTheme.darkCharcoal : Colors.grey.shade300, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          setState(() {
            _modeReglement = mode;
            // Si on bascule hors espèces, on pré-remplit le montant exact pour la carte/momo
            if (mode != "ESPECES") _montantRecu = widget.totalAmount;
          });
        },
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCoupureChip(int valeur, {required bool isBillet}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        onTap: () => _ajouterCoupure(valeur),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isBillet ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isBillet ? AppTheme.successGreen.withValues(alpha: 0.4) : AppTheme.primaryAmber.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Text('$valeur F',style: TextStyle(fontSize: 14,fontWeight: FontWeight.bold,color: isBillet ? AppTheme.successGreen : AppTheme.darkCharcoal,),
          ),
          ),
          ),
          );
          }
          }