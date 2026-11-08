import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_header.dart';

class AuthStatusScreen extends StatelessWidget {
  const AuthStatusScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return AuthPage(
      children: [
        AuthHeader(
          title: switch (auth.stage) {
            AuthStage.loading => 'Preparando tu acceso',
            AuthStage.configuration => 'Configuración pendiente',
            _ => 'Revisa tu conexión o tu sesión',
          },
          subtitle: auth.message ?? 'Consultando el estado de tu cuenta.',
        ),
        if (auth.busy) const LinearProgressIndicator(),
        if (auth.stage == AuthStage.error && auth.repository != null)
          FilledButton(
            onPressed: auth.restore,
            child: const Text('Reintentar'),
          ),
        TextButton(
          onPressed: () => context.go(AppRoute.tutorial.path),
          child: const Text('Tutorial de uso'),
        ),
      ],
    );
  }
}
