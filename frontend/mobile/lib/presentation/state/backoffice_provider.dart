// path: frontend/mobile/lib/presentation/state/backoffice_provider.dart
import 'package:flutter/material.dart';
import '../../data/repositories/license_repository.dart';

class BackOfficeProvider extends ChangeNotifier {
  final LicenseRepository _licenseRepo = LicenseRepository();

  bool _isDashboardAccessible = false;
  bool get isDashboardAccessible => _isDashboardAccessible;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  /// Évalue les droits d'accès au tableau de bord Admin selon la licence locale flashée
  Future<void> checkAdminAccessRights() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 🔑 LA RÈGLE METIER : Extraction directe du drapeau 'allow_backoffice' depuis SQLite
      _isDashboardAccessible = await _licenseRepo.isFeatureAllowed('allow_backoffice');
    } catch (e) {
      _isDashboardAccessible = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
