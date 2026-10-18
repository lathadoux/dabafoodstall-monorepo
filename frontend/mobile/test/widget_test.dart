//import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dabafoodstall/main.dart'; // 🛠️ Match parfait avec le "name:" du pubspec
import 'package:dabafoodstall/core/services/license_security_service.dart';

void main() {
  testWidgets('Test de conformité allumage V1', (WidgetTester tester) async {
    // Charge l'application dans l'environnement de test
// 🟢 CORRECTIF : Injection de paramètres fictifs d'usine pour valider le compilateur de tests
await tester.pumpWidget(
  const DabaFoodStallApp(
    initialStatus: LicenseStatus.active, // On simule un état fonctionnel
    dfp: "TEST_DFP_EMULATEUR_LOCAL_64_CHARS_MOCK", // Empreinte de test
  ),
);


    // Vérifie que le texte d'accueil du clavier PIN est bien visible à l'allumage
    expect(find.text('Saisissez votre code PIN Vendeur'), findsOneWidget);
  });
}
