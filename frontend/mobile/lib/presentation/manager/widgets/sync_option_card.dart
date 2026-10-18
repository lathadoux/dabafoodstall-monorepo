// path: frontend/mobile/lib/presentation/manager/widgets/sync_option_card.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SyncOptionCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color buttonColor;
  final bool isLoading;
  final VoidCallback? onPressed;

  const SyncOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.buttonColor,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cleanWhite,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: buttonColor.withValues(alpha: 0.1),
              child: Text(icon, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            
            // 🔒 SÉCURITÉ RESPONSIVE ABSOLUE : Expanded force le texte à s'adapter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkCharcoal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 10, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            
            // Affichage de l'état réseau
            isLoading 
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: buttonColor, strokeWidth: 2))
                : SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: onPressed,
                      child: Text(buttonLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
