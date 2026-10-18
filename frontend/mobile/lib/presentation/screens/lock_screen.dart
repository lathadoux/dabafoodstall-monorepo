// path: frontend/mobile/lib/presentation/auth/lock_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

class LockScreen extends StatefulWidget {
  final String imeiAppareil; 
  final Map<String, dynamic> termParams; // 🔑 INCORPORATION : Paramètres SQLite contenant la date et le code court
  final Database database;              // Requis pour persister la prolongation localement

  const LockScreen({
    super.key, 
    required this.imeiAppareil, 
    required this.termParams,
    required this.database,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = "";

  /// 📡 RECONNAISSANCE ET SYNC FLASH (Option B du diagramme de séquence)
  /// Interroge le Cloud en arrière-plan à l'aide de la DFP matérielle pour capter le renouvellement
  Future<void> _checkLicenseOnline() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      // Routage sur l'API Gateway unifiée et isolée de production
      final url = Uri.parse('https://ngrok-free.dev');
      
      // Injection de l'empreinte DFP cryptographique dans les en-têtes HTTP de sécurité
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'x-device-dfp': widget.imeiAppareil
      });

      if (!mounted) return; // Garde de sécurité (Async Gaps)

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success' && jsonResponse['data'] != null) {
          final dataCloud = jsonResponse['data'][0];
          
          final String expirationCloud = dataCloud['date_expiration_cloud'];
          final DateTime dateCloud = DateTime.parse(expirationCloud);

          // Si le paiement est effectif sur le Cloud, la date est supérieure à l'horloge courante
          if (dateCloud.isAfter(DateTime.now())) {
            // Recalage instantané de la date d'expiration locale dans SQLite (Étape 11)
            await widget.database.update(
              'term_params',
              {'date_expiration': expirationCloud},
              where: 'device_fingerprint = ?',
              whereArgs: [widget.imeiAppareil],
            );

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("🎉 Paiement détecté ! Votre caisse a été prolongée et débridée."),
                backgroundColor: Color(0xFF137333), // Vert Material Design
              ),
            );
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            return;
          }
        }
      }
      
      setState(() {
        _errorMessage = "Aucun renouvellement de licence détecté sur le Cloud pour ce terminal.";
        _isLoading = false;
      });

    } catch (error_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Erreur réseau : Impossible de joindre la passerelle centrale Daba.";
        _isLoading = false;
      });
    }
  }

  void _attemptLocalUnlock() {
    final codeSaisi = _tokenController.text.trim();
    if (codeSaisi.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    // Simulation d'un code de secours d'urgence pour le commercial hors-ligne
    Future.delayed(const Duration(milliseconds: 600), () async {
      if (!mounted) return;

      if (codeSaisi == "GENZO_TEST_7J" || codeSaisi.toUpperCase().contains("DABA")) {
        // Prolongation artificielle locale d'une semaine de secours
        final dateSecours = DateTime.now().add(const Duration(days: 7)).toIso8601String();
        await widget.database.update(
          'term_params',
          {'date_expiration': dateSecours},
          where: 'device_fingerprint = ?',
          whereArgs: [widget.imeiAppareil],
        );

        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      } else {
        setState(() {
          _errorMessage = "Code d'activation ou de secours invalide.";
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Extraction sécurisée du code unique à 3x4 chiffres (Ex: 452-891-324)
    final String shortCode = widget.termParams['code_activation_court'] ?? "000-000-000";

    return PopScope(
      canPop: false, // 🛡️ SÉCURITÉ : Bloque le retour arrière physique Android
      child: Scaffold(
        backgroundColor: const Color(0xFFD32F2F), 
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gavel_rounded, size: 64, color: Color(0xFFD32F2F)),
                    const SizedBox(height: 16),
                    const Text(
                      "APPLICATION BRIDÉE",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    
                    // 🚨 LE BANDEAU DE RAPPEL DE SÉCURITÉ OBLIGATOIRE (Option A du diagramme)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0), // Orange alerte léger
                        border: Border.all(color: const Color(0xFFFFB74D)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Votre forfait est expiré. Renseignez ce code unique sur le portail de paiement Wave/Orange pour reconduire vos accès :",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            shortCode,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFFE65100)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    TextField(
                      controller: _tokenController,
                      decoration: const InputDecoration(
                        labelText: "Saisir un code de débridage manuel",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.vpn_key),
                      ),
                    ),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(_errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 20),
                    
                    _isLoading
                        ? const CircularProgressIndicator()
                        : Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF137333), // Vert Material
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: _checkLicenseOnline,
                                  icon: const Icon(Icons.refresh, color: Colors.white),
                                  label: const Text("Vérifier le règlement Cloud", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFD32F2F)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: _attemptLocalUnlock,
                                  child: const Text("Valider code manuel", style: TextStyle(color: Color(0xFFD32F2F), fontSize: 14)),
                                ),
                              ),
                            ],
                            ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const Text(
                          "EMPREINTE MATÉRIELLE IDENTIFIANTE (DFP) :",
                          style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(height: 4),
                        SelectableText(
                        widget.imeiAppareil,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}