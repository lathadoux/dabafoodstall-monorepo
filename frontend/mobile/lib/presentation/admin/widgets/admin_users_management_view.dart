// path: frontend/mobile/lib/presentation/admin/widgets/admin_users_management_view.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/local_data_source.dart';


class AdminUsersManagementView extends ConsumerStatefulWidget {
  final VoidCallback onUserChanged;
  const AdminUsersManagementView({super.key, required this.onUserChanged});

  // 2. Ajustez le type de retour pour correspondre à ConsumerState
  @override
  ConsumerState<AdminUsersManagementView> createState() => _AdminUsersManagementViewState();
}

// 3. Modifiez l'État pour qu'elle étende ConsumerState
class _AdminUsersManagementViewState extends ConsumerState<AdminUsersManagementView> {
  // ⚡ Clé d'actualisation pour forcer la relecture de la table SQLite à chaque action
  Key _refreshKey = UniqueKey();

  void _declencherRafraichissement() {
    setState(() {
      _refreshKey = UniqueKey();
    });
    widget.onUserChanged(); // Alerte le panneau d'administration principal
  }
  @override
  Widget build(BuildContext context ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: _refreshKey, // 🛡️ Lie l'état au rafraîchisseur dynamique
      future: ref.read(localDataSourceProvider).getDonneesTable('users'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAmber));
        }
        
        final employes = snapshot.data ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Créer un Collaborateur", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
                ),
                onPressed: () => _ouvrirFormulaireUserModal(),
              ),
            ),
            
            // 🚀 COUPLAGE SYSTÈME : La liste des utilisateurs s'affiche de manière fluide ici
            Expanded(
              child: employes.isEmpty
                  ? const Center(child: Text("Aucun collaborateur trouvé", style: TextStyle(color: Colors.white60, fontSize: 13)))
                  : ListView.builder(
                      itemCount: employes.length,
                      itemBuilder: (context, i) {
                        final emp = employes[i];
                        final String nom = emp['nom_user'] as String? ?? 'Agent';
                        final String role = emp['role_user'] as String? ?? 'vendor';
                        final String pin = emp['pin_user'] as String? ?? '----';

                        return Card(
                          color: Colors.black45,
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: role == 'admin' 
                                  ? Colors.purple 
                                  : (role == 'manager' ? Colors.blue : Colors.orange),
                              child: Text(
                                role.substring(0, 1).toUpperCase(), 
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                              ),
                            ),
                            title: Text(nom, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text("PIN actuel : $pin • Rôle : ${role.toUpperCase()}", style: const TextStyle(color: Colors.white60, fontSize: 11)),
                            
                            // 🛠️ LE BOUTON D'ÉDITION DEVIENT ENFIN ACCESSIBLE
                            trailing: IconButton(
                              icon: const Icon(Icons.edit, color: AppTheme.primaryAmber, size: 20),
                              onPressed: () => _ouvrirFormulaireUserModal(userData: emp),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _ouvrirFormulaireUserModal({Map<String, dynamic>? userData}) {
    final bool isEdition = userData != null;
    final formKey = GlobalKey<FormState>();
    
    // 🕵️ Extraction de l'identifiant technique SQLite 'id_user' pour cibler la bonne ligne
    final int? idUserActuel = isEdition ? userData['id_user'] as int? : null;
    
    final nomController = TextEditingController(text: isEdition ? userData['nom_user'] : '');
    final pinController = TextEditingController(text: isEdition ? userData['pin_user'] : '');
    String roleSelectionne = isEdition ? userData['role_user'] : 'vendor';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white, // 🎨 PROTECTION : Fond blanc pour une lisibilité totale
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          isEdition ? '📝 Modifier le Profil Agent' : '👤 Nouveau Collaborateur', 
          style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold)
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nomController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: 'Nom & Prénom', 
                    labelStyle: TextStyle(color: Colors.black54)
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: roleSelectionne,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: 'Rôle d\'accès d\'étal', 
                    labelStyle: TextStyle(color: Colors.black54)
                  ),
                  items: const [
                    DropdownMenuItem(value: 'vendor', child: Text('VENDEUR (VDR)')),
                    DropdownMenuItem(value: 'manager', child: Text('GESTIONNAIRE (MGR)')),
                    DropdownMenuItem(value: 'admin', child: Text('ADMINISTRATEUR (ADM)')),
                  ],
                  onChanged: (val) => roleSelectionne = val!,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pinController,
                  style: const TextStyle(color: Colors.black),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'Code PIN Unique (4 chiffres)', 
                    labelStyle: TextStyle(color: Colors.black54)
                  ),
                  validator: (v) {
                    if (v == null || v.length != 4 || int.tryParse(v) == null) return 'Entrez 4 chiffres';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Annuler', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              
              final String pin = pinController.text.trim();
              final String nom = nomController.text.trim();

              final bool unique = await ref.read(localDataSourceProvider).estPinUnique(pin, idUserAExclure: idUserActuel);
              if (!mounted) return;

              if (!unique) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: AppTheme.alertRed, content: Text('🛑 Ce code PIN est déjà pris.')),
                );
                return;
              }

              if (isEdition) {
                await ref.read(localDataSourceProvider).modifierUtilisateur(
                  idUserActuel!, 
                  nom, 
                  roleSelectionne, 
                  userData['password_user'] ?? 'daba_pass', 
                  pin
                );
              } else {
                await ref.read(localDataSourceProvider).creerUtilisateur(
                  nom, 
                  roleSelectionne, 
                  'daba_pass', 
                  pin
                );
              }

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _declencherRafraichissement(); // 🚀 Forçage réactif immédiat
            },
            child: const Text('Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
