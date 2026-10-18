// path: frontend/mobile/lib/presentation/close/widgets/cloture_header_card.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ClotureHeaderCard extends StatelessWidget {
  final int idSession;
  final String dateOuverture;

  const ClotureHeaderCard({super.key, required this.idSession, required this.dateOuverture});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppTheme.cleanWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Session Active : #$idSession", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.darkCharcoal)),
                  const SizedBox(height: 4),
                  Text(
                    "Ouverte le : ${dateOuverture.isNotEmpty ? dateOuverture.substring(0, 16).replaceAll('T', ' à ') : 'En attente'}", 
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.lock_clock_rounded, color: Colors.orange, size: 30),
          ],
        ),
      ),
    );
  }
}
