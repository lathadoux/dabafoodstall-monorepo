// path: frontend/mobile/lib/presentation/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
//import '../../data/database/database_helper.dart';
import '../../data/datasources/local_data_source.dart';
import '../auth/auth_provider.dart';
import '../auth/cashier_pin_screen.dart';
import 'widgets/admin_menu_cards.dart';
import 'widgets/admin_table_tabs.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  final String adminName;
  const AdminDashboardScreen({super.key, required this.adminName});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  String? _tableSelectionnee;
  List<String> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerTables();
  }

  Future<void> _chargerTables() async {
    final List<String> list = (await ref.read(localDataSourceProvider).getListeTables()).cast<String>();
    if (!mounted) return;
    setState(() {
      _tables = list;
      _isLoading = false;
      if (_tables.isNotEmpty) _tableSelectionnee = _tables.first;
    });
  }

// path: frontend/mobile/lib/presentation/admin/admin_dashboard_screen.dart

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: Text('Console Admin : ${widget.adminName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.alertRed),
            onPressed: () {
              ref.read(currentOperatorProvider.notifier).state = const OperatorState(
                isAuthenticated: false,
                nomPOS: "Étal Pilote Abidjan",
                idUser: null,
                nomUtilisateur: null,
                role: null,
              );
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const CashierPinScreen()), (route) => false);
            },
          )
        ],
      ),
      // 🚀 FIX ANTI-DÉBORDEMENT GLOBALE : Le corps entier de l'administration devient défilant
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _tableSelectionnee,
                        dropdownColor: Colors.black,
                        style: const TextStyle(color: AppTheme.primaryAmber, fontWeight: FontWeight.bold),
                        items: _tables.map((String t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                        onChanged: (val) => setState(() => _tableSelectionnee = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AdminMenuCards(ref: ref, onActionComplete: () => setState(() {})),
                  const Divider(color: Colors.white24, height: 24),
                  
                  // 🚀 FIX STRUCTUREL : Utilisation d'un SizedBox à hauteur fixe pour contenir proprement la TabBarView
                  if (_tableSelectionnee != null)
                    SizedBox(
                      height: 450, // Donne un espace de défilement confortable pour afficher la liste RH
                      child: AdminTableTabs(table: _tableSelectionnee!, onRefresh: () => setState(() {})),
                    ),
                ],
              ),
            ),
    );
  }

}
