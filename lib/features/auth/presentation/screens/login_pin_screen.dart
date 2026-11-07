import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/app/app_routes.dart';

import '../widgets/auth_header.dart';
import '../widgets/pin_dots_indicator.dart';
import '../widgets/pin_keypad.dart';

class LoginPinScreen extends StatefulWidget {
  const LoginPinScreen({super.key});
  @override
  State<LoginPinScreen> createState() => _LoginPinScreenState();
}

class _LoginPinScreenState extends State<LoginPinScreen> {
  // La demostración solo necesita contar las pulsaciones.
  int count = 0;
  void inform(String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => AuthPage(
    children: [
      AuthHeader(
        dark: true,
        title: 'Iniciar sesión',
        subtitle: 'Ingresa tu clave de 6 dígitos',
        footer: PinDotsIndicator(count: count, dark: true),
      ),
      PinKeypad(
        randomized: true,
        onDigit: (_) {
          if (count < 6) setState(() => count++);
        },
        onDelete: () {
          if (count > 0) setState(() => count--);
        },
      ),
      if (count == 6)
        FilledButton(
          onPressed: () {
            setState(() => count = 0);
            inform('La verificación real del PIN requiere el servidor.');
          },
          child: const Text('Continuar'),
        ),
      TextButton(
        onPressed: () => inform(
          'La recuperación del PIN estará disponible cuando se implemente el sistema de autenticación',
        ),
        child: const Text('¿Olvidaste tu PIN?'),
      ),
      const Text('¿Aún no tienes cuenta?', textAlign: TextAlign.center),
      OutlinedButton(
        onPressed: () {
          setState(() => count = 0);
          context.push(AppRoute.register.path);
        },
        child: const Text('Regístrate'),
      ),
      TextButton(
        onPressed: () => context.go(AppRoute.home.path),
        child: const Text('Volver al inicio de demostración'),
      ),
    ],
  );
}
