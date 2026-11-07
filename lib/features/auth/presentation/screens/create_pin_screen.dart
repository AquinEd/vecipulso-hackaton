import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/app/app_routes.dart';

import '../widgets/auth_header.dart';
import '../widgets/registration_step_indicator.dart';
import '../widgets/pin_dots_indicator.dart';
import '../widgets/pin_keypad.dart';

class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});
  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  final draft = <int>[], entry = <int>[];
  bool completed = false, mismatch = false;
  void submit() => setState(() {
    if (draft.isEmpty) {
      draft.addAll(entry);
    } else if (listEquals(entry, draft)) {
      completed = true;
      draft.clear();
    } else {
      mismatch = true;
    }
    entry.clear();
  });
  @override
  void dispose() {
    draft.clear();
    entry.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return AuthPage(
        children: [
          const AuthHeader(
            title: 'Registro de demostración completado',
            subtitle: 'Tus datos todavía no se han guardado. La creación real de la cuenta estará disponible cuando se conecte el servidor',
          ),
          FilledButton(
            onPressed: () => context.go(AppRoute.home.path),
            child: const Text('Ir al inicio'),
          ),
        ],
      );
    }
    final confirming = draft.isNotEmpty;
    return AuthPage(
      children: [
        AuthHeader(
          title: confirming ? 'Confirma tu PIN' : 'Crea tu PIN',
          subtitle: confirming
              ? 'Escribe nuevamente los seis dígitos.'
              : 'Elige una clave de seis dígitos para esta demostración.',
          footer: RegistrationStepIndicator(step: confirming ? 3 : 2),
        ),
        Text(
          confirming ? '3. Confirma tu clave' : '2. Define tu PIN',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 20),
        PinDotsIndicator(count: entry.length),
        const SizedBox(height: 18),
        if (mismatch)
          Semantics(
            liveRegion: true,
            child: Text(
              'Los PIN no coinciden. Inténtalo nuevamente.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        PinKeypad(
          onDigit: (digit) {
            if (entry.length < 6) {
              setState(() {
                entry.add(digit);
                mismatch = false;
              });
            }
          },
          onDelete: () {
            if (entry.isNotEmpty) setState(entry.removeLast);
          },
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: entry.length == 6 ? submit : null,
          child: Text(confirming ? 'Confirmar PIN' : 'Continuar'),
        ),
      ],
    );
  }
}
