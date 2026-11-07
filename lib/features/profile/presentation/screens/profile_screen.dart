import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/accessibility_controller.dart';
import '../../../../app/app_routes.dart';
import '../../../../shared/widgets/cards/app_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Semantics(
        header: true,
        child: Text(
          'Mi perfil',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      const AppCard(
        child: ListTile(
          leading: CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text('Vecino de ejemplo'),
          subtitle: Text(
            'Perfil de demostración\nCuenta comunitaria ilustrativa',
          ),
        ),
      ),
      if (context.watch<AccessibilityController?>()?.clearInstructions ?? false)
        const Text(
          'Elige un acceso para consultar tus mensajes, avisos o preferencias.',
        ),
      for (final (route, label, icon) in const [
        (AppRoute.messages, 'Mis mensajes', Icons.forum_outlined),
        (
          AppRoute.notifications,
          'Notificaciones',
          Icons.notifications_outlined,
        ),
        (AppRoute.settings, 'Configuración', Icons.settings_outlined),
        (AppRoute.tutorial, 'Tutorial de uso', Icons.menu_book_outlined),
      ])
        ListTile(
          leading: Icon(icon),
          title: Text(label),
          onTap: () {
            if (route == AppRoute.messages) {
              context.go(route.path);
            } else {
              context.push(route.path);
            }
          },
        ),
    ],
  );
}
