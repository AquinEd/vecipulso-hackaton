import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../models/emergency_action_option.dart';
import '../../models/emergency_action_type.dart';

IconData emergencyActionIcon(EmergencyActionType type) => switch (type) {
  EmergencyActionType.neighborAlert => Icons.warning_rounded,
  EmergencyActionType.criticalSupport => Icons.favorite_border,
  EmergencyActionType.offerResources => Icons.volunteer_activism_outlined,
};

class EmergencyActionCard extends StatelessWidget {
  const EmergencyActionCard({
    super.key,
    required this.action,
    required this.onSelect,
  });
  final EmergencyActionDefinition action;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final alert = action.type == EmergencyActionType.neighborAlert;
    return Card(
      color: alert ? const Color(0xffffe8e9) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  emergencyActionIcon(action.type),
                  size: 36,
                  color: alert ? AppColors.sos : AppColors.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(action.description),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Semantics(
              label: action.title,
              child: AppButton(
                label: 'Seleccionar',
                icon: Icons.arrow_forward,
                sos: alert,
                onPressed: onSelect,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
