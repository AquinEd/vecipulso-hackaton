import 'emergency_action_option.dart';

/// Remembers the confirmation screen even when it showed a fallback example.
class ConfirmationOrigin {
  const ConfirmationOrigin(this.category);
  final EmergencyActionCategory? category;
}
