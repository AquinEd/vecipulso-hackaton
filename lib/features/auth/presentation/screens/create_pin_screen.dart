import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
  bool mismatch = false;
  Future<void> submit() async {
    final auth = context.read<AuthController>();
    if (auth.busy || entry.length != 6) return;
    if (draft.isNotEmpty && listEquals(entry, draft)) {
      final pin = entry.join();
      setState(() {
        draft.clear();
        entry.clear();
      });
      await auth.register(pin);
      return;
    }
    setState(() {
      if (draft.isEmpty) {
        draft.addAll(entry);
      } else {
        mismatch = true;
      }
      entry.clear();
    });
  }

  @override
  void dispose() {
    draft.clear();
    entry.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final confirming = draft.isNotEmpty;
    return PopScope(
      canPop: !auth.busy,
      child: AuthPage(
        children: [
          AuthHeader(
            title: confirming ? 'Confirma tu PIN' : 'Crea tu PIN',
            subtitle: confirming
                ? 'Escribe nuevamente los seis dígitos.'
                : 'Elige una clave de seis dígitos.',
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
          if (auth.message case final String message) Text(message),
          if (auth.busy) const LinearProgressIndicator(),
          AbsorbPointer(
            absorbing: auth.busy,
            child: PinKeypad(
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
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: !auth.busy && entry.length == 6 ? submit : null,
            child: Text(confirming ? 'Confirmar PIN' : 'Continuar'),
          ),
        ],
      ),
    );
  }
}
