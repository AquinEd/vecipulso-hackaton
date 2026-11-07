import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../models/community_brigade.dart';

class BrigadeCard extends StatelessWidget {
  const BrigadeCard({
    super.key,
    required this.brigade,
    required this.onContact,
  });
  final CommunityBrigade brigade;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(14) > 18;
          final button = AppButton(
            label: 'Contacto directo',
            icon: Icons.chat_bubble_outline,
            onPressed: onContact,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Icon(
                      switch (brigade.icon) {
                        BrigadeIcon.shield => Icons.shield_outlined,
                        BrigadeIcon.community => Icons.groups_outlined,
                        BrigadeIcon.health => Icons.favorite_border,
                        BrigadeIcon.mobility => Icons.location_on_outlined,
                      },
                      size: 30,
                      color: switch (brigade.icon) {
                        BrigadeIcon.health => AppColors.sos,
                        BrigadeIcon.mobility => AppColors.map,
                        _ => AppColors.primary,
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          brigade.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.small),
                        Text(
                          '${brigade.sectorLabel} · ${brigade.memberCount} integrantes',
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(height: AppSpacing.medium),
                          button,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (compact) ...[
                const SizedBox(height: AppSpacing.medium),
                button,
              ],
            ],
          );
        },
      ),
    ),
  );
}
