import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../services/utils/provider_display_name.dart';
import '../../models/solidarity_post.dart';

class SolidarityPostCard extends StatelessWidget {
  const SolidarityPostCard({super.key, required this.post, required this.mode});
  final SolidarityPost post;
  final WallMode mode;

  void _inform(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final economy = mode == WallMode.economy;
    final theme = Theme.of(context).textTheme;
    final color = switch (post.type) {
      PostType.need => AppColors.map,
      PostType.donation => AppColors.warning,
      PostType.exchange => const Color(0xff714fbe),
      _ => AppColors.primary,
    };
    final name = formatProviderDisplayName(
      post.authorFirstName,
      post.authorPaternalSurname,
    );
    final label = economy ? post.type.economyLabel : post.type.label;
    final badge = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: post.type == PostType.donation
                ? AppColors.ink
                : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    final approval = Text(
      economy ? '✓ Visto Bueno Vecinal' : '✓ Visto Bueno',
      style: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
    );
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.community.withValues(alpha: 0.14),
                  child: Icon(Icons.person, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(name, style: theme.titleMedium),
                          badge,
                        ],
                      ),
                      if (!economy)
                        Text(
                          '${post.age} · Barrio ${post.neighborhood}',
                          style: theme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.title,
              style: theme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              post.description,
              style: theme.bodyMedium?.copyWith(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 10),
            if (!economy)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${post.category} · ${post.modality}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (economy)
                  TextButton.icon(
                    onPressed: () => _inform(
                      context,
                      'Contactar',
                      'El contacto entre vecinos estará disponible cuando se integre el sistema de mensajería',
                    ),
                    icon: const Icon(Icons.volunteer_activism_outlined),
                    label: const Text('Contactar'),
                  )
                else ...[
                  Tooltip(
                    message: 'Favoritos de demostración',
                    child: TextButton.icon(
                      onPressed: () => _inform(
                        context,
                        'Favoritos',
                        'El contador es ilustrativo. Guardar favoritos estará disponible en una próxima fase.',
                      ),
                      icon: const Icon(Icons.favorite_border, size: 18),
                      label: Text('${post.likeCount}'),
                    ),
                  ),
                  Tooltip(
                    message: 'Comentarios de demostración',
                    child: TextButton.icon(
                      onPressed: () => _inform(
                        context,
                        'Comentarios',
                        'El contador es ilustrativo. Los comentarios estarán disponibles en una próxima fase.',
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: Text('${post.commentCount}'),
                    ),
                  ),
                ],
                if (post.hasNeighborhoodApproval) approval,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
