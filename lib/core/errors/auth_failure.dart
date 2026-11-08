import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthFailure implements Exception {
  network(
    'No se pudo conectar con el servidor. Revisa tu conexión y reintenta.',
  ),
  session('La sesión ya no está disponible. Revisa el estado de tu registro.'),
  duplicate('Este DNI ya está registrado.'),
  dni('Ingresa los ocho dígitos de tu DNI.'),
  zone('Selecciona una zona disponible.'),
  consent('Acepta el tratamiento de tus datos para continuar.'),
  pin('El PIN debe tener seis dígitos.'),
  missingPin('El perfil no tiene PIN. Contacta al equipo de VeciPulso.'),
  weakPin(
    'Elige un PIN menos obvio. Evita seis dígitos iguales, 123456 y 654321.',
  ),
  nameInvalid('El nombre debe tener entre 3 y 80 caracteres.'),
  denied('El servidor denegó el acceso. Revisa los permisos del proyecto.'),
  unexpected('El servidor devolvió una respuesta inesperada.'),
  blocked('Cuenta temporalmente bloqueada.'),
  profile('El servidor aún no confirmó el perfil. Reintenta la consulta.');

  const AuthFailure(this.message);
  final String message;
  static AuthFailure from(Object error) {
    if (error is AuthFailure) return error;
    if (error is TimeoutException || error is AuthRetryableFetchException) {
      return network;
    }
    if (error is AuthException &&
        (error.statusCode == '401' ||
            [
              'refresh_token_not_found',
              'session_not_found',
              'refresh_token_already_used',
            ].contains(error.code))) {
      return session;
    }
    if (error is PostgrestException) {
      final msg = error.message.toLowerCase();
      if (['PGRST301', 'PGRST303'].contains(error.code)) return session;
      if (error.code == '42501') return denied;
      if (error.code == '23505' ||
          msg.contains('dni') &&
              RegExp('registrad|duplic|existe').hasMatch(msg)) {
        return duplicate;
      }
      if (msg.contains('dni')) return dni;
      if (msg.contains('sesión')) return session;
      if (msg.contains('nombre')) return nameInvalid;
      if (msg.contains('menos obvio')) return weakPin;
      if (msg.contains('tratamiento')) return consent;
      if (msg.contains('zona') || msg.contains('barrio')) return zone;
      if (msg.contains('consent')) return consent;
      if (msg.contains('pin')) return pin;
    }
    final type = error.runtimeType.toString();
    if (type.contains('SocketException') ||
        type.contains('ClientException') ||
        type.contains('HandshakeException')) {
      return network;
    }
    return unexpected;
  }
}
