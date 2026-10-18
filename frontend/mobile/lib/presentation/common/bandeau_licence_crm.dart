// path: frontend/mobile/lib/presentation/common/bandeau_licence_crm.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/license_refresh_engine.dart';

class BandeauLicenceCrm extends ConsumerWidget {
  final String dfp;
  final dynamic database;

  const BandeauLicenceCrm({super.key, required this.dfp, required this.database});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Écoute de l'état réactif via le provider Riverpod paramétré
    final license = ref.watch(licenseRefreshProvider({'dfp': dfp, 'database': database}));

    if (license.state != LicenseSyncState.warning) {
      return const SizedBox.shrink(); // Invisible au-dessus de 3 jours
    }

    return Container(
      width: double.infinity,
      color: const Color(0xFFE65100), // Orange Material intense conforme Sonar
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Forfait expirant dans ${license.daysRemaining} jours. Code unique de réactivation : ${license.shortCode}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
              onPressed: () {
                ref.read(licenseRefreshProvider({'dfp': dfp, 'database': database}).notifier).executeSilentRefresh();
              },
            )
          ],
        ),
      ),
    );
  }
}
