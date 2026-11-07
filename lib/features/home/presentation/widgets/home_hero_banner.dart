import 'package:flutter/material.dart';
import 'package:hackaton_veci_pulso/core/theme/app_radius.dart';

class HomeHeroBanner extends StatelessWidget {
  const HomeHeroBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 270),
            child: Text(
              '¡Juntos hacemos un mejor barrio!',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Servicios, favores y apoyo cerca de ti.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
