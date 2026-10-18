import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/database_helper.dart';
import '../../domain/entities/user.dart';
import '../main_navigation.dart';
import '../sale/sync_ui_provider.dart'; // Écoute de l'état du réseau (🟢/🟡)

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  /// Exécute l'algorithme d'authentification hybride (Local SQLite vs API Cloud)
    Future<void> _handleClassicLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final syncState = ref.read(syncUiProvider);
    
    // 🔒 SÉCURITÉ COMPILATEUR : Capture des instances graphiques AVANT l'async gap
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      if (syncState.isOnline) {
        debugPrint("🌐 [Login] Tentative d'authentification Cloud pour : $username...");
      }

      // ⏳ Saut asynchrone (attente de réponse de la base SQLite locale)
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> result = await db.query(
        'users',
        where: 'nom_user = ? AND password_user = ?',
        whereArgs: [username, password],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final userMap = result.first;
        
        UserRole role;
        switch (userMap['role_user']) {
          case 'admin':
            role = UserRole.admin;
            break;
          case 'manager':
            role = UserRole.manager;
            break;
          case 'vendor':
          default:
            role = UserRole.vendor;
            break;
        }

        final userConnecte = User(
          idUser: userMap['id_user'] as int,
          idTenant: userMap['id_tenant'] as int,
          nomUser: userMap['nom_user'] as String,
          roleUser: role,
        );

        debugPrint("🔓 [Login] Connexion classique validée pour : ${userConnecte.nomUser}");

        setState(() => _isLoading = false);
        
        // 🔒 UTILISATION EXCLUSIVE DE LA RÉFÉRENCE CAPTURÉE AVANT L'ASYNC GAP
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => MainNavigation(currentUser: userConnecte)),
          (route) => false,
        );
      } else {
        setState(() => _isLoading = false);
        _showErrorNotification(messenger, "Identifiant ou mot de passe incorrect.");
      }

    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorNotification(messenger, "Erreur technique de traitement : $e");
    }
  }


  void _showErrorNotification(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.alertRed, // 🛠️ Convention lowerCamelCase appliquée
        content: Text('🛑 $message', textAlign: TextAlign.center),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncUiProvider);

    return Scaffold(
      backgroundColor: AppTheme.cleanWhite, // 🛠️ Convention lowerCamelCase appliquée
      appBar: AppBar(
        title: const Text('Espace Manager & Admin'),
        actions: [
          // Témoin visuel du mode de fonctionnement réseau
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              syncState.isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: syncState.isOnline ? AppTheme.successGreen : AppTheme.primaryAmber, // 🛠️ lowerCamelCase
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Identification Classique',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.darkCharcoal),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Entrez vos accès professionnels (Gestionnaires et Administrateurs)',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Champ Identifiant / Nom d'utilisateur
                  TextFormField(
                    controller: _usernameController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Nom d\'utilisateur ou Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Veuillez saisir votre identifiant.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Champ Mot de passe sécurisé
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      fillColor: Colors.white,
                      filled: true,
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez saisir votre mot de passe.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // Bouton de validation
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.darkCharcoal,
                      foregroundColor: AppTheme.cleanWhite, // 🛠️ lowerCamelCase
                    ),
                    onPressed: _isLoading ? null : _handleClassicLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: AppTheme.cleanWhite, strokeWidth: 2),
                          )
                        : const Text('OUVRIR LA SESSION DIRECTE'),
                  ),
                  const SizedBox(height: 16),
                  
                  // Bouton de retour vers le clavier PIN de secours
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '⬅️ Revenir au Clavier PIN Vendeur',
                      style: TextStyle(color: AppTheme.darkCharcoal, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
