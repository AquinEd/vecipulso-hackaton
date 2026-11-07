import 'package:flutter/material.dart';
import 'package:hackaton_veci_pulso/features/services/models/service_preview.dart';
import 'package:hackaton_veci_pulso/core/theme/app_colors.dart';
import 'package:hackaton_veci_pulso/shared/widgets/cards/app_card.dart';

class ServiceListCard extends StatelessWidget {
  const ServiceListCard({
    super.key,
    required this.service,
    required this.onTap,
    this.directory = false,
  });
  final ServicePreview service;
  final VoidCallback onTap;
  final bool directory;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (service.category) {
      ServiceCategory.plumbing => Icons.build_outlined,
      ServiceCategory.carpentry => Icons.carpenter_outlined,
      ServiceCategory.electricity => Icons.lightbulb_outline,
      ServiceCategory.locksmith => Icons.lock_outline,
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
                      Text(
                        service.serviceName,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(service.providerDisplayName),
                      Text(
                        directory
                            ? service.category.label
                            : service.summary ?? service.description,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '★ ${service.rating.toStringAsFixed(1)}   ·   ${service.distanceMeters} m',
                        semanticsLabel:
                            'Valoración de ejemplo ${service.rating} de 5, distancia ilustrativa ${service.distanceMeters} metros',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: directory
                              ? const Color(0xff9a5100)
                              : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (service.hasNeighborhoodApproval)
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
                            directory
                                ? '✓ Visto Bueno Vecinal'
                                : '✓ Visto Bueno Vecinal · Demo',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                    ],
                  ),
                ),
                if (directory)
                  const Icon(
                    Icons.arrow_forward,
                    size: 20,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
