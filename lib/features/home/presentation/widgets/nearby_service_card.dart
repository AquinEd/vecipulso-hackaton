import 'package:flutter/material.dart';
import 'package:hackaton_veci_pulso/features/services/models/service_preview.dart';
import 'package:hackaton_veci_pulso/core/theme/app_colors.dart';
import 'package:hackaton_veci_pulso/shared/widgets/cards/app_card.dart';

class NearbyServiceCard extends StatelessWidget {
  const NearbyServiceCard({
    super.key,
    required this.service,
    required this.onTap,
  });
  final ServicePreview service;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (service.category) {
      ServiceCategory.plumbing => Icons.build_outlined,
      ServiceCategory.carpentry => Icons.carpenter_outlined,
      ServiceCategory.education => Icons.school_outlined,
    };
    return AppCard(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.name, style: theme.textTheme.titleMedium),
                      Text(service.description),
                      const SizedBox(height: 4),
                      Text(
                        '★ ${service.rating.toStringAsFixed(1)}   ·   ${service.distanceMeters} m',
                        semanticsLabel:
                            'Valoración de ejemplo ${service.rating} de 5, distancia ilustrativa ${service.distanceMeters} metros',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '✓ Visto Bueno Vecinal · Demo',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
