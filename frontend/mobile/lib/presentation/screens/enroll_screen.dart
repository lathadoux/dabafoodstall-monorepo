import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../../core/services/license_security_service.dart';

class EnrollScreen extends StatefulWidget {
  final String deviceFingerprint; 

  const EnrollScreen({super.key, required this.deviceFingerprint});

  @override
  State<EnrollScreen> createState() => _EnrollScreenState(); // 🟢 FIX 1 : Pointe maintenant sur la bonne classe d'état
}

// 🟢 FIX 2 : Renommé en _EnrollScreenState pour correspondre au StatefulWidget ci-dessus
class _EnrollScreenState extends State<EnrollScreen> {
  bool _isLoading = false; 
  String _statusMessage = "Analyse des signatures de pré-enrôlement...";
  String _errorMessage = "";
  String _wfpExtracted = "";
  String _initialExpiryExtracted = "";

  @override
  void initState() {
    super.initState();
    _extractAndEnrollDevice();
  }

  Future<void> _extractAndEnrollDevice() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final String manifestContent = await rootBundle.loadString('assets/term_params.json');
      final Map<String, dynamic> manifestData = jsonDecode(manifestContent);

      _wfpExtracted = manifestData['web_fingerprint'] ?? "";
      _initialExpiryExtracted = manifestData['date_expiration'] ?? "";

      if (_wfpExtracted.isEmpty || _initialExpiryExtracted.isEmpty) {
        throw Exception("Signature d'enrôlement corrompue ou incomplète dans l'APK.");
      }

      setState(() {
        _statusMessage = "Signature Web détectée.\nScellage de l'empreinte matérielle (DFP) sur le serveur...";
      });

      final response = await http.post(
        Uri.parse("https://ngrok-free.dev"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'web_fingerprint': _wfpExtracted,
          'device_fingerprint': widget.deviceFingerprint,
        }),
      );

      if (!mounted) return;

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = "Synchronisation du grand livre local...";
        });

        final String serverExpiration = result['date_expiration'] ?? _initialExpiryExtracted;
        await LicenseSecurityService.saveNewExpiration(serverExpiration);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🎉 Enrôlement réussi ! Votre terminal est désormais rattaché à votre point de vente."),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      } else {
        setState(() {
          _errorMessage = result['message'] ?? "Le serveur a refusé le scellage matériel.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Impossible de lier l'appareil au serveur central.\n"
            "Vérifiez votre connexion réseau Moov/MTN/Orange ou utilisez un code d'activation local.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, 
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.app_registration, size: 72, color: Colors.orange),
                const SizedBox(height: 24),
                const Text(
                  "SÉCURISATION DU TERMINAL",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.1),
                ),
                const SizedBox(height: 16),
                if (_errorMessage.isEmpty) ...[
                  const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.orange)),
                  const SizedBox(height: 20),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
                  ),
                ] else ...[
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: _isLoading 
                        ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.orange)))
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _extractAndEnrollDevice,
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            label: const Text("Réessayer l'activation", style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                  ),
                  const SizedBox(height: 12),
                  if (!_isLoading)
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil('/lock-screen', (route) => false);
                      },
                      child: const Text("Utiliser un code d'activation hors-ligne", style: TextStyle(color: Colors.orange)),
                    ),
                ],
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  "DFP MATÉRIELLE : ${widget.deviceFingerprint.substring(0, 12)}...",
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
