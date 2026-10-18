// path: frontend/mobile/lib/presentation/screens/splash_screen.dart
import 'package:flutter/material.dart';
import '../../data/database/database_helper.dart';
import '../../data/database/database_seeder.dart';
import '../../core/services/license_security_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = "Vérification de la licence GENZO-POS...";

  @override
  void initState() {
    super.initState();
    _executeRouteGuardPipeline();
  }

  Future<void> _executeRouteGuardPipeline() async {
    try {
      // Étape A : Audit d'intégrité de l'horloge et de la licence locale
      LicenseStatus status = await LicenseSecurityService.verifyLicenseIntegrity();

      if (status == LicenseStatus.active || status == LicenseStatus.warningNearExpiry) {
        await _bootAndSeedDatabase();
        return;
      }

      // Étape B : Si non enregistré ou expiré localement, tentative de scellage via l'APK
      if (status == LicenseStatus.unregistered || status == LicenseStatus.expired) {
        setState(() => _statusMessage = "Vérification et scellage avec le Cloud distant...");
        
        final String? embeddedFingerprint = await LicenseSecurityService.getEmbeddedFingerprint();
        
        if (embeddedFingerprint != null) {
          bool success = await LicenseSecurityService.triggerAutoActivation(embeddedFingerprint);
          if (success) {
            await _bootAndSeedDatabase();
            return;
          }
        }
      }

      // Étape C : Blocage en cas de fraude d'horloge détectée ou d'échec d'activation cloud
      _navigateTo('/lock');

    } catch (e) {
      debugPrint("🛑 [SplashScreen Crash] : $e");
      _navigateTo('/lock');
    }
  }

  Future<void> _bootAndSeedDatabase() async {
    if (!mounted) return;
    setState(() => _statusMessage = "Mise en place de vos données de caisse...");

    try {
      final db = await DatabaseHelper.instance.database;
      await DatabaseSeeder.seedDatabaseFromManifest(db);
      _navigateTo('/home');
    } catch (dbError) {
      debugPrint("🛑 [SplashScreen Error BDD] : $dbError");
      _navigateTo('/lock');
    }
  }

  void _navigateTo(String routeName) {
    if (mounted) {
      Navigator.pushReplacementNamed(context, routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "GENZO-POS",
              style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3),
            ),
            const SizedBox(height: 6),
            const Text(
              "BY GENZOSOFT",
              style: TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 50),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent)),
            ),
            const SizedBox(height: 32),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
