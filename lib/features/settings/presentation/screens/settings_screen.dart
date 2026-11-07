import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/accessibility_controller.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/navigation/guide_page.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => GuidePage(
    title: 'Configuración',
    children: [
      const Text('Preferencias y ayuda de VeciPulso'),
      if (context.watch<AccessibilityController?>()?.clearInstructions ?? false)
        const Text(
          'Elige una sección. Usa Atrás para volver a tus preferencias.',
        ),
      for (final (route, label, detail, icon) in const [
        (
          AppRoute.access,
          'Accesibilidad',
          'Texto, contraste e interacción',
          Icons.accessibility_new,
        ),
        (
          AppRoute.tutorial,
          'Tutorial de uso',
          'Ayuda paso a paso',
          Icons.menu_book_outlined,
        ),
        (
          AppRoute.pending,
          'Estados offline (demo)',
          'Practica la sincronización simulada',
          Icons.wifi_off,
        ),
        (
          AppRoute.notifications,
          'Notificaciones',
          'Consulta los avisos de ejemplo',
          Icons.notifications_outlined,
        ),
      ])
        AppCard(
          child: ListTile(
            leading: Icon(icon),
            title: Text(label),
            subtitle: Text(detail),
            onTap: () => context.push(route.path),
          ),
        ),
      AppCard(
        child: ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Cuenta y privacidad'),
          subtitle: const Text('Datos de cuenta y seguridad'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (dialog) => AlertDialog(
              title: const Text('Cuenta y privacidad'),
              content: const Text(
                'La gestión de datos de cuenta estará disponible al integrar el sistema de usuarios.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          ),
        ),
      ),
      const AppCard(
        child: ListTile(
          title: Text('VeciPulso'),
          subtitle: Text(
            'MVP para hackathon · 0.1.0+1\nAplicación de demostración',
          ),
        ),
      ),
    ],
  );
}
