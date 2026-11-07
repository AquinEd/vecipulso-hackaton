import 'package:flutter/material.dart';

import '../../../../shared/widgets/common/app_section_header.dart';
import '../../data/demo_emergency_actions.dart';
import '../../models/emergency_action_option.dart';
import '../../models/emergency_action_type.dart';

class EmergencyActionSummary extends StatelessWidget {
  const EmergencyActionSummary({
    super.key,
    required this.action,
    required this.option,
    required this.onChange,
  });
  final EmergencyActionDefinition action;
  final EmergencyActionOption option;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AppSectionHeader(title: 'Resumen de demostración'),
      const SizedBox(height: 16),
      const Text(emergencyDemoNotice),
      const SizedBox(height: 16),
      Text(
        'Acción: ${action.type == EmergencyActionType.offerResources ? 'Ofrecer ayuda' : action.title}',
      ),
      Text('${action.summaryLabel}: ${option.label}'),
      const Text(emergencyDemoLocation),
      Text(
        'Estado: ${action.type == EmergencyActionType.offerResources ? 'No registrado' : 'No enviada'}',
      ),
      const SizedBox(height: 20),
      Text(action.notice),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: onChange,
        child: const Text('Cambiar selección'),
      ),
      if (action.type == EmergencyActionType.criticalSupport)
        FilledButton(
          onPressed: () => Navigator.pop(context, option.category),
          child: const Text('Ver confirmación visual (demo)'),
        ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar demostración'),
      ),
    ],
  );
}
