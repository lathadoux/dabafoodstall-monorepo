// path: frontend/mobile/lib/presentation/manager/manager_sync_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/datasources/local_data_source.dart';
import '../../data/services/sync_service.dart'; // Ajusté selon votre arborescence corrigée
import '../sale/catalog_provider.dart'; 
import 'widgets/sync_option_card.dart';
// Assurez-vous que le chemin est correct selon votre structure de projet

class ManagerSyncScreen extends ConsumerStatefulWidget  {
  const ManagerSyncScreen({super.key});

  @override
  ConsumerState<ManagerSyncScreen> createState() => _ManagerSyncScreenState();
}

class _ManagerSyncScreenState extends ConsumerState<ManagerSyncScreen>  {
  bool _isCatalogLoading = false;
  bool _isTransactionsUploading = false;
  int _pendingTransactionsCount = 0;
  int _localArticlesCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLocalDatabaseStatus());
  }

  Future<void> _checkLocalDatabaseStatus() async {
    try {
      // 🔑 NETTOYAGE : Utilisation de la source de données locale purifiée
      final localData = ref.read(localDataSourceProvider);
      final tables = await localData.getListeTables();
      
      int articlesCount = 0;
      int pendingCount = 0;

      if (tables.contains('articles')) {
        final articles = await localData.getDonneesTable('articles');
        articlesCount = articles.length;
      }
      
      if (tables.contains('financial_transactions')) {
        // Option simple d'audit de vos transactions locales
        final trans = await localData.getDonneesTable('financial_transactions');
        pendingCount = trans.where((row) => row['statut_sync'] == 0).length;
      }

      if (!mounted) return;
      setState(() {
        _localArticlesCount = articlesCount;
        _pendingTransactionsCount = pendingCount;
      });
    } catch (e) {
      debugPrint("🛑 [Sync Dashboard] Erreur comptage local : $e");
    }
  }

  Future<void> _handleCatalogImport() async {
    setState(() => _isCatalogLoading = true);
    try {
      // 🔑 FIX CRITIQUE : Consommation saine du service via Riverpod
      final syncService = ref.read(syncServiceProvider);
      final bool success = await syncService.importCatalogFromServer();
      await _checkLocalDatabaseStatus();
      
      if (success && mounted) {
        try {
          ref.read(localCatalogProvider.notifier).loadSalesArticles();
          ref.invalidate(localFamillesProvider); 
        } catch (e) {
          debugPrint("ℹ️ [Riverpod Sync Link] : $e");
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? AppTheme.successGreen : AppTheme.alertRed,
          content: Text(success ? '📥 Catalogue importé avec succès !' : '🛑 Échec de liaison IP.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCatalogLoading = false);
    }
  }

  Future<void> _handleTransactionsUpload() async {
    setState(() => _isTransactionsUploading = true);
    await Future.delayed(const Duration(seconds: 2)); // Effet de chargement visuel
    
    try {
      // 🔑 TOUTE LA LOGIQUE SQL DU BATCH EST ENCAPSULÉE À L'ABRI DANS LA DATA SOURCE
      final localData = ref.read(localDataSourceProvider);
      await localData.marquerTransactionsCommeSynchronisees();
      
      await _checkLocalDatabaseStatus();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.successGreen, 
          content: Text('📤 Flux transactionnels synchronisés avec succès.')
        ),
      );
    } catch (e) {
      debugPrint("🛑 [Sync Upload] Échec du push local : $e");
    } finally {
      if (mounted) setState(() => _isTransactionsUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Centre de Synchronisation Réseau', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.darkCharcoal,
        foregroundColor: AppTheme.cleanWhite,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // BANNER DIAGNOSTIC RESPONSIVE
          Card(
            color: AppTheme.cleanWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('💾', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text('État des Tables SQLite Locales', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildStatusRow('Articles en cache local :', '$_localArticlesCount', Colors.blue),
                  const SizedBox(height: 10),
                  _buildStatusRow('Tickets non synchronisés :', '$_pendingTransactionsCount', _pendingTransactionsCount > 0 ? Colors.orange : AppTheme.successGreen),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // CARTES EXTRACTÉES DE FLUX
          SyncOptionCard(
            icon: '📥',
            title: 'Importer Catalogue & Familles',
            subtitle: 'Recharge le référentiel d\'articles depuis PostgreSQL.',
            buttonLabel: 'Aspirer',
            buttonColor: Colors.orange,
            isLoading: _isCatalogLoading,
            onPressed: _isCatalogLoading || _isTransactionsUploading ? null : _handleCatalogImport,
          ),
          const SizedBox(height: 12),
          SyncOptionCard(
            icon: '📤',
            title: 'Pousser les Ventes du Jour',
            subtitle: 'Transfère les transactions de caisse vers l\'API Node.js.',
            buttonLabel: 'Remonter',
            buttonColor: AppTheme.successGreen,
            isLoading: _isTransactionsUploading,
            onPressed: _isCatalogLoading || _isTransactionsUploading || _pendingTransactionsCount == 0 ? null : _handleTransactionsUpload,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
