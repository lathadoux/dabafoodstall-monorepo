// path: frontend/mobile/lib/presentation/admin/admin_sync_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/sync_service.dart'; // Alignement du chemin vers votre SyncService unique

class AdminSyncScreen extends StatelessWidget {
  const AdminSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "Console d'Administration Sync",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdminSyncHeader(),
            SizedBox(height: 24),
            // Déploiement du composant connecté de synchronisation
            SyncUsersCatalog(),
          ],
        ),
      ),
    );
  }
}

/// En-tête informatif rappelant les restrictions de sécurité Admin
class _AdminSyncHeader extends StatelessWidget {
  const _AdminSyncHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.red.shade800, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "⚠️ Zone d'Accès Restreint : Super Admin",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Les opérations de synchronisation descendante modifient les tables de sécurité locales (profils serveurs/vendeurs et PIN d'accès).",
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

/// ⚙️ COMPOSANT RECONSTRUIT : Gestion de l'aspiration connectée à Riverpod
class SyncUsersCatalog extends ConsumerStatefulWidget {
  const SyncUsersCatalog({super.key});

  @override
  ConsumerState<SyncUsersCatalog> createState() => _SyncUsersCatalogState();
}

class _SyncUsersCatalogState extends ConsumerState<SyncUsersCatalog> {
  bool _isSyncing = false;

  /// Déclenche le téléchargement réseau (Pull)
  Future<void> _executePull() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      // 🔑 CONSOMMATION DU PROVIDER VIA LE MEMBRE NATIF 'ref' DE CONSUMERSTATE
      final syncService = ref.read(syncServiceProvider);
      
      // Appel du service pour le Tenant 1 (votre établissement par défaut)
      bool isSuccess = await syncService.pullUsersFromServer(1);

      if (!mounted) return;

      // Notification visuelle de l'état de la transaction SQLite/Cloud
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isSuccess ? Icons.verified_user : Icons.gpp_bad,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isSuccess
                      ? "Base RH et catalogue synchronisés à 100 % !"
                      : "Rupture de liaison réseau avec l'API Gateway.",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint("🛑 [Admin Sync] Erreur lors du pull : $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_alt_rounded, color: Colors.purple.shade800, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Synchronisation RH & Catalogue",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ), 
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Télécharge le grand livre des collaborateurs, écrase le cache de sécurité SQLite local et rafraîchit l'arborescence des familles et articles.",
              style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.3),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : _executePull,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade800,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.purple.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_lock_rounded, size: 18),
                label: Text(
                  _isSyncing ? "Mise à jour sécurisée..." : "Aspirer les profils Cloud",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
