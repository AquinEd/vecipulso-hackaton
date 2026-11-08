abstract final class AuthValidators {
  static String? pin(String value) => RegExp(r'^[0-9]{6}$').hasMatch(value)
      ? null
      : 'El PIN debe tener seis dígitos.';
  static bool weakPin(String value) =>
      RegExp(r'^(.)\1{5}$').hasMatch(value) ||
      value == '123456' ||
      value == '654321';
  static String? dni(String? value) =>
      RegExp(r'^[0-9]{8}$').hasMatch(value ?? '')
      ? null
      : 'Ingresa los ocho dígitos de tu DNI.';
  static String normalizeName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');
  static String? name(String? value) {
    final length = normalizeName(value ?? '').runes.length;
    if (length == 0) return 'Ingresa tu nombre completo.';
    return length < 3 || length > 80
        ? 'El nombre debe tener entre 3 y 80 caracteres.'
        : null;
  }
}
