enum EmergencyActionType {
  neighborAlert,
  criticalSupport,
  offerResources;

  static EmergencyActionType? fromParameter(String? value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return null;
  }
}
