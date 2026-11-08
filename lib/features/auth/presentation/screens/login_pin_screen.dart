import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';

import 'package:flutter/material.dart';

import '../widgets/auth_header.dart';
import '../widgets/pin_dots_indicator.dart';
import '../widgets/pin_keypad.dart';

class LoginPinScreen extends StatefulWidget {
  const LoginPinScreen({super.key});
  @override
  State<LoginPinScreen> createState() => _LoginPinScreenState();
}

class _LoginPinScreenState extends State<LoginPinScreen> {
  final entry = <int>[];
  @override
  void dispose() {
    entry.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final disabled = auth.busy || auth.blockedUntil != null;
    return AuthPage(
      children: [
        AuthHeader(
          dark: true,
          title: 'Iniciar sesión',
          subtitle: 'Ingresa tu clave de 6 dígitos',
          footer: PinDotsIndicator(count: entry.length, dark: true),
        ),
        AbsorbPointer(
          absorbing: disabled,
          child: PinKeypad(
            randomized: true,
            onDigit: (digit) {
              if (entry.length < 6) setState(() => entry.add(digit));
            },
            onDelete: () {
              if (entry.isNotEmpty) setState(entry.removeLast);
            },
          ),
        ),
        if (auth.busy) const LinearProgressIndicator(),
        if (auth.message case final String message)
          Semantics(liveRegion: true, child: Text(message)),
        if (entry.length == 6)
          FilledButton(
            onPressed: disabled
                ? null
                : () {
                    final pin = entry.join();
                    setState(entry.clear);
                    auth.verify(pin);
                  },
            child: const Text('Continuar'),
          ),
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              content: const Text(
                'El PIN desbloquea esta instalación. La cuenta anónima no se puede recuperar con DNI y PIN en otro dispositivo.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          ),
          child: const Text('¿Olvidaste tu PIN?'),
        ),
      ],
    );
  }
}
