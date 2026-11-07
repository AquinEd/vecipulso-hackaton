abstract final class AuthValidators {
  static String? dni(String? value) =>
      RegExp(r'^[0-9]{8}$').hasMatch(value ?? '')
      ? null
      : 'Ingresa los ocho dígitos de tu DNI.';
  static String normalizeName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');
  static String? name(String? value) =>
      normalizeName(value ?? '').isEmpty ? 'Ingresa tu nombre completo.' : null;
}
