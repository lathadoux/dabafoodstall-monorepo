// path: frontend/mobile/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart'; // 🔑 REQUIS : Pour la méthode join() sur les chemins de fichiers

// Services techniques de licences et de mocks
import 'core/mocks/fake_license_mock.dart';
import 'core/services/device_fingerprint_service.dart';
import 'core/services/license_security_service.dart';

// Thème et Sources de données
import 'core/theme/app_theme.dart';
import 'data/datasources/local_data_source.dart';

// Écrans de l'écosystème de caisse et de bridage
import 'presentation/auth/auth_provider.dart';
import 'presentation/auth/cashier_pin_screen.dart';
import 'presentation/screens/fraud_screen.dart';
import 'presentation/screens/lock_screen.dart';
import 'presentation/common/bandeau_session.dart';
import 'presentation/common/bandeau_licence_crm.dart';


void main() async {
  // 1. Garantie l'initialisation des liaisons natives de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 🛠️ MOCK TEMPORAIRE DE DÉPLACEMENT : Force l'injection du forfait valide en local
  await FakeLicenseMock.injectFakeSubscription();

  // 2. Initialisation et Seeding de la base SQLite locale de test
  final localData = LocalDataSource();
  Map<String, dynamic> extractedParams = {};
  Database? activeDatabase;
  
  try {
    debugPrint("🚀 [Main] Initialisation et peuplement automatique de la base SQLite...");
    await localData.seedTestData();
    
    // 🔑 RÉSOLUTION COMPILATEUR : Accès au fichier physique SQLite direct pour contourner l'absence de getter
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'dabapos_local.db'); 
    activeDatabase = await openDatabase(path);
    
    // 🛡️ SÉCURISATION : Appel garanti sans condition de nullité
    final List<Map<String, dynamic>> maps = await activeDatabase.query('term_params', limit: 1);
    if (maps.isNotEmpty) {
      extractedParams = maps.first;
    }
    
    debugPrint("✅ [Main] Base de données et paramètres d'activation prêts pour l'utilisation.");
  } catch (e) {
    debugPrint("⚠️ [Main] Erreur lors de l'initialisation ou extraction des données : $e");
  }

  // 3. Analyse chirurgicale du matériel (DFP) et de l'état de la licence
  String deviceFingerprint = "";
  LicenseStatus licenseStatus = LicenseStatus.unregistered;

  try {
    deviceFingerprint = await DeviceFingerprintService.generateDFP();
    debugPrint("🤖 [DabaPOS Material Shield] DFP du terminal : $deviceFingerprint");

    licenseStatus = await LicenseSecurityService.verifyLicenseIntegrity();
  } catch (e) {
    debugPrint("❌ Erreur critique lors de l'initialisation matérielle : $e");
    licenseStatus = LicenseStatus.expired;
  }

  // En cas d'échec de récupération de la base, instanciation d'un conteneur de secours pour éviter le crash
  activeDatabase ??= await openDatabase('dabapos_rescue.db');

  // 4. Allumage de l'application encapsulée dans le conteneur d'états Riverpod
  runApp(
    ProviderScope(
      child: DabaFoodStallApp(
        initialStatus: licenseStatus,
        dfp: deviceFingerprint,
        termParams: extractedParams, 
        database: activeDatabase,    
      ),
    ),
  );
}

class DabaFoodStallApp extends ConsumerWidget {
  final LicenseStatus initialStatus;
  final String dfp;
  final Map<String, dynamic>? termParams; 
  final Database? database;              

  const DabaFoodStallApp({
    super.key,
    required this.initialStatus,
    required this.dfp,
    this.termParams,
    this.database,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operatorState = ref.watch(currentOperatorProvider);

    return MaterialApp(
      title: 'DabaFoodStall',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      
      builder: (context, child) {
        if (initialStatus == LicenseStatus.expired || initialStatus == LicenseStatus.fraudDetected) {
          return Material(child: child!);
        }

        return Material(
          child: Column(
            children: [
              BandeauLicenceCrm(dfp: dfp, database: database), 
              BandeauSession(
                nomPOS: operatorState.nomPOS,
                nomUtilisateur: operatorState.nomUtilisateur,
                role: operatorState.role,
                licenseStatus: initialStatus, 
              ),
              Expanded(child: child!), 
            ],
          ),
        );
      },      
      
      home: _getInitialScreen(),
    );
  }

  Widget _getInitialScreen() {

      // 🔑 RÉSOLUTION TYPAGE : Si termParams est nul (mode test), on injecte un dictionnaire par défaut non nul
    final Map<String, dynamic> secureParams = termParams ?? {
      'code_activation_court': '000-000-000',
      'date_expiration': DateTime.now().toIso8601String()
    };  
    switch (initialStatus) {
      case LicenseStatus.active:
      case LicenseStatus.warningNearExpiry:
        return const CashierPinScreen();
        
      case LicenseStatus.expired:
        return LockScreen(
          imeiAppareil: dfp,
          termParams: secureParams,
          database: database!,
        );
        
      case LicenseStatus.fraudDetected:
        return const FraudScreen();
        
      case LicenseStatus.unregistered:
        return LockScreen(
          imeiAppareil: dfp,
          termParams: secureParams,
          database: database!,
        ); 
    }
  }
}
