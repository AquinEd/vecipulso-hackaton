import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/common/app_section_header.dart';
import '../../data/demo_emergency_actions.dart';
import '../../models/emergency_action_option.dart';
import '../../models/emergency_action_type.dart';
import 'emergency_action_summary.dart';

IconData _categoryIcon(EmergencyActionCategory category) => switch (category) {
  EmergencyActionCategory.earthquake => Icons.vibration,
  EmergencyActionCategory.fire => Icons.local_fire_department,
  EmergencyActionCategory.security => Icons.shield_outlined,
  EmergencyActionCategory.health ||
  EmergencyActionCategory.medicalHelp => Icons.medical_services_outlined,
  EmergencyActionCategory.trappedPerson => Icons.person_search,
  EmergencyActionCategory.foodAndWater => Icons.restaurant,
  EmergencyActionCategory.transportOrShelter ||
  EmergencyActionCategory.shelter => Icons.house_outlined,
  EmergencyActionCategory.water => Icons.water_drop_outlined,
  EmergencyActionCategory.firstAid => Icons.healing,
  EmergencyActionCategory.tools => Icons.handyman_outlined,
  EmergencyActionCategory.transport => Icons.directions_car_outlined,
};

class EmergencyActionSelector extends StatefulWidget {
  const EmergencyActionSelector({super.key, required this.action});
  final EmergencyActionDefinition action;
  @override
  State<EmergencyActionSelector> createState() =>
      _EmergencyActionSelectorState();
}

class _EmergencyActionSelectorState extends State<EmergencyActionSelector> {
  EmergencyActionOption? selected;
  bool summary = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.action.type == EmergencyActionType.neighborAlert
        ? AppColors.sos
        : AppColors.primary;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: summary
            ? EmergencyActionSummary(
                action: widget.action,
                option: selected!,
                onChange: () => setState(() => summary = false),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSectionHeader(title: widget.action.selectorTitle),
                  const SizedBox(height: 8),
                  const Text(emergencyDemoNotice),
                  const SizedBox(height: 16),
                  for (final option in widget.action.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Semantics(
                        selected: selected == option,
                        child: Material(
                          color: selected == option
                              ? color.withValues(alpha: .1)
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: selected == option
                                  ? color
                                  : AppColors.border,
                              width: selected == option ? 2 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            key: ValueKey(option.category),
                            leading: Icon(
                              _categoryIcon(option.category),
                              color: color,
                            ),
                            title: Text(option.label),
                            subtitle: Text(option.description),
                            trailing: Icon(
                              selected == option
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: color,
                            ),
                            onTap: () => setState(() => selected = option),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: color),
                    onPressed: selected == null
                        ? null
                        : () => setState(() => summary = true),
                    child: const Text('Ver resumen de demostración'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
      ),
    );
  }
}
