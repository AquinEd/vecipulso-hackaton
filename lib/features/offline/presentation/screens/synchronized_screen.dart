import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/accessibility_controller.dart';
import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/navigation/guide_page.dart';
import '../controllers/offline_demo_controller.dart';

class SynchronizedScreen extends StatelessWidget {
  const SynchronizedScreen({super.key, this.demo});
  final OfflineDemoController? demo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GuidePage(
      title: 'Sincronización',
      children: [
        if (demo?.status != OfflineDemoStatus.synchronized)
          const Text(
            'Vista previa del resultado ficticio',
            textAlign: TextAlign.center,
          ),
        Center(
          child: CircleAvatar(
            radius: 64,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: CircleAvatar(
              radius: 46,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(
                Icons.check,
                size: 56,
                color: Colors.white,
                semanticLabel: 'Confirmación simulada',
              ),
            ),
          ),
        ),
        Text(
          '¡Simulación completada!',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const Text(
          'Así se visualizaría una solicitud sincronizada cuando el sistema tenga conexión con el servidor.',
        ),
        const Text(
          'Demostración: no se enviaron datos ni se notificó a ningún vecino.',
        ),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.small,
              children: [
                Text('Resultado de ejemplo', style: theme.textTheme.titleLarge),
                const Text('Tipo: ${OfflineDemoController.request}'),
                Text(
                  'Estado: Sincronizado (simulado)',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
                const Text('Sincronización simulada completada.'),
              ],
            ),
          ),
        ),
        if (context.watch<AccessibilityController>().clearInstructions)
          const Text(
            'Usa Atrás para regresar o abre el tablero para consultar el Modo SOS de demostración.',
          ),
        AppButton(
          label: 'Ir al tablero de ayuda',
          icon: Icons.arrow_forward,
          onPressed: () => context.go(AppRoute.sos.path),
        ),
      ],
    );
  }
}
