import 'package:flutter/foundation.dart';

enum AccessibilityPreference {
  largeText,
  highContrast,
  largeButtons,
  clearInstructions,
}

class AccessibilityController extends ChangeNotifier {
  final _enabled = <AccessibilityPreference>{};
  bool enabled(AccessibilityPreference option) => _enabled.contains(option);
  bool get largeText => enabled(AccessibilityPreference.largeText);
  bool get highContrast => enabled(AccessibilityPreference.highContrast);
  bool get largeButtons => enabled(AccessibilityPreference.largeButtons);
  bool get clearInstructions =>
      enabled(AccessibilityPreference.clearInstructions);

  void update(AccessibilityPreference option, bool value) {
    final changed = value ? _enabled.add(option) : _enabled.remove(option);
    if (changed) notifyListeners();
  }

  void resetToDefaults() {
    if (_enabled.isEmpty) return;
    _enabled.clear();
    notifyListeners();
  }
}
