// path: frontend/mobile/lib/presentation/screens/activation_screen.dart
import 'package:flutter/material.dart';
import '../.././core/services/activation_service.dart'; // Ajustez l'import selon votre arborescence

class ActivationScreen extends StatefulWidget {
  // ✅ Correction use_super_parameters
  const ActivationScreen({super.key}); 

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _codeController = TextEditingController();
  final _activationService = ActivationService();
  bool _isLoading = false;
  String _errorMessage = "";

  void _handleActivation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    // Appel asynchrone vers le serveur (Async gap)
    bool success = await _activationService.activateDevice(_codeController.text.trim());

    // ✅ Correction use_build_context_synchronously : Sécurisation du contexte
    if (!mounted) return; 

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        _errorMessage = "Activation échouée. Vérifiez le code ou la connexion.";
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "GENZO-POS",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 48),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: "Code d'activation Cloud",
                border: OutlineInputBorder(),
                hintText: "Ex: 1793-5270-6395",
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleActivation,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("Lier l'appareil"),
            ),
          ],
        ),
      ),
    );
  }
}
