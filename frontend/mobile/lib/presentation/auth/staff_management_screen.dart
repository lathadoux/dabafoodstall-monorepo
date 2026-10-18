import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/database_helper.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = 'vendor'; // Par défaut

  Future<void> _ajouterCollaborateur() async {
    if (!_formKey.currentState!.validate()) return;
    final db = await _dbHelper.database;

    // --- APPLICATION DIRECTE DE LA SÉCURITÉ ET DES BARRIÈRES DU MOT ---
    if (_selectedRole == 'admin' || _selectedRole == 'manager') {
      final List<Map<String, dynamic>> countResult = await db.rawQuery(
        'SELECT COUNT(*) as total FROM users WHERE role_user = ?', [_selectedRole]
      );
      
      // ===================================================================
      // 🔒 PREMIÈRE GARDE SÉCURITÉ : APRÈS LA REQUÊTE COUNT ASYNCHRONE
      // ===================================================================
      if (!mounted) return;

      int currentCount = countResult.first['total'] as int;

      if (currentCount >= 1) {
        _showLimitAlert(_selectedRole); // Dépend du BuildContext
        return; // Bloque physiquement l'insertion SQL
      }
    }

    // Écriture locale validée dans SQLite
    await db.insert('users', {
      'id_tenant': 1,
      'nom_user': _nameController.text.trim(),
      'role_user': _selectedRole,
      'password_user': _passwordController.text.trim(),
      'pin_user': _pinController.text.trim(),
    });

    _nameController.clear();
    _pinController.clear();
    _passwordController.clear();

    // ===================================================================
    // 🔒 SECONDE GARDE SÉCURITÉ : APRÈS L'INSERTION ATOMIQUE ASYNCHRONE
    // ===================================================================
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.successGreen, // 🛠️ Casse corrigée
        content: Text('👤 Utilisateur créé et enregistré avec succès !'),
      ),
    );
  }


  void _showLimitAlert(String role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🛑 Règle Métier Restrictive'),
        content: Text('Le système autorise un unique [$role] au sein de l\'infrastructure. Veuillez modifier le rôle de l\'utilisateur existant avant d\'en ajouter un nouveau.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('COMPRIS'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cleanWhite,
      appBar: AppBar(title: const Text('Équipe et Collaborateurs')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('👤 Enregistrer un nouvel équipier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom Complet', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Le nom est obligatoire.' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Groupe / Profil de droits', border: OutlineInputBorder()),
                initialValue: _selectedRole,
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Administrateur (Max : 1)')),
                  DropdownMenuItem(value: 'manager', child: Text('Gestionnaire / Manager (Max : 1)')),
                  DropdownMenuItem(value: 'vendor', child: Text('Vendeur Terrain (Illimité)')),
                ],
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(labelText: 'Code PIN (4 chiffres)', border: OutlineInputBorder(), counterText: ""),
                      validator: (v) => v!.length != 4 ? 'Saisissez 4 chiffres.' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Mot de passe (V1)', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Entrez un mot de passe.' : null,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _ajouterCollaborateur,
                child: const Text('VALIDER L\'INSCRIPTION DU COLLABORATEUR'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
