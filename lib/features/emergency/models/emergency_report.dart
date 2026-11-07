enum EmergencyPriority {
  critical('Crítica'),
  urgent('Urgente'),
  underReview('En revisión');

  const EmergencyPriority(this.label);
  final String label;
}

enum EmergencyCategory {
  rescue('Rescate'),
  resources('Recursos básicos'),
  housing('Vivienda');

  const EmergencyCategory(this.label);
  final String label;
}

class EmergencyReport {
  const EmergencyReport({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.distanceLabel,
    required this.isDemo,
  });

  final String id, title, description, distanceLabel;
  final EmergencyCategory category;
  final EmergencyPriority priority;
  final bool isDemo;
}
