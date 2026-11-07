import 'emergency_action_type.dart';

enum EmergencyActionCategory {
  earthquake,
  fire,
  security,
  health,
  trappedPerson,
  medicalHelp,
  foodAndWater,
  transportOrShelter,
  water,
  firstAid,
  tools,
  transport,
  shelter,
}

class EmergencyActionOption {
  const EmergencyActionOption(this.category, this.label, this.description);
  final EmergencyActionCategory category;
  final String label, description;
}

class EmergencyActionDefinition {
  const EmergencyActionDefinition({
    required this.type,
    required this.title,
    required this.description,
    required this.selectorTitle,
    required this.summaryLabel,
    required this.notice,
    required this.options,
  });
  final EmergencyActionType type;
  final String title, description, selectorTitle, summaryLabel, notice;
  final List<EmergencyActionOption> options;
}
