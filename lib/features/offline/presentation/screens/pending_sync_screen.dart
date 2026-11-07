import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/accessibility_controller.dart';
import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/navigation/guide_page.dart';
import '../controllers/offline_demo_controller.dart';

class PendingSyncScreen extends StatelessWidget {
  const PendingSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demo = context.watch<OfflineDemoController>();
    final theme = Theme.of(context);
    final status = demo.status;
    final message = switch (status) {
      OfflineDemoStatus.offline => 'Este escenario muestra cómo VeciPulso podría funcionar sin internet. No se está comprobando la conexión real.',
      OfflineDemoStatus.pending =>
        'Esta solicitud de ejemplo todavía no fue enviada.',
      OfflineDemoStatus.sending =>
        'El procesamiento es ficticio. No hay comunicación con un servidor.',
      OfflineDemoStatus.synchronized => 'Sincronización simulada completada.',
      OfflineDemoStatus.error => 'Se produjo un error en la simulación.',
    };
    final (title, icon) = switch (status) {
      OfflineDemoStatus.offline => ('Sin conexión · Demo', Icons.wifi_off),
      OfflineDemoStatus.pending => ('Pendiente · Demo', Icons.schedule),
      OfflineDemoStatus.sending => ('Simulando procesamiento', Icons.sync),
      OfflineDemoStatus.synchronized => (
        'Sincronizado · Demo',
        Icons.check_circle_outline,
      ),
      OfflineDemoStatus.error => ('Error · Demo', Icons.error_outline),
    };
    return GuidePage(
      title: 'Modo sin conexión',
      children: [
        Semantics(
          liveRegion: true,
          child: Card(
            color: status == OfflineDemoStatus.error
                ? theme.colorScheme.errorContainer
                : const Color(0xff0b3033),
            child: Builder(
              builder: (context) {
                final color = status == OfflineDemoStatus.error
                    ? theme.colorScheme.onErrorContainer
                    : Colors.white;
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.large),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.small,
                    children: [
                      Icon(icon, color: color, size: 36),
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: color,
                        ),
                      ),
                      Text(
                        message,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: color,
                        ),
                      ),
                      if (status == OfflineDemoStatus.sending)
                        const LinearProgressIndicator(
                          semanticsLabel: 'Procesamiento simulado',
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (status == OfflineDemoStatus.offline) ...[
          Text(
            'Funciones previstas sin conexión',
            style: theme.textTheme.titleLarge,
          ),
          for (final (icon, name, detail) in const [
            (
              Icons.storefront_outlined,
              'Consultar directorio guardado',
              'Consultar servicios y grupos del barrio.',
            ),
            (
              Icons.edit_note,
              'Registrar solicitudes pendientes',
              'Preparar una solicitud para enviarla más adelante.',
            ),
            (
              Icons.contact_phone_outlined,
              'Consultar contactos útiles',
              'Encontrar contactos de apoyo del barrio.',
            ),
          ])
            AppCard(
              child: ListTile(
                leading: Icon(icon, color: theme.colorScheme.primary),
                title: Text(name),
                subtitle: Text('Función futura · $detail'),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    scrollable: true,
                    title: Text(name),
                    content: Text(
                      'En una versión futura podrás realizar esta acción: $detail Esta demo no almacena datos.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Card(
            color: const Color(0xfffff1da),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.small,
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.warningText),
                  Text(
                    'Solicitud pendiente · Demo',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Text(
                    'Ejemplo ficticio: ${OfflineDemoController.request}',
                  ),
                  const Text(
                    'Ningún vecino fue notificado. La solicitud no se guardó en el dispositivo.',
                  ),
                ],
              ),
            ),
          ),
        ],
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.small,
              children: [
                Text(
                  'Controles de demostración',
                  style: theme.textTheme.titleMedium,
                ),
                if (context.watch<AccessibilityController>().clearInstructions)
                  const Text(
                    'Crea el ejemplo y simula recuperar la conexión. Luego elige éxito o error. Si eliges error, puedes volver a intentar.',
                  ),
                if (status == OfflineDemoStatus.offline)
                  FilledButton(
                    onPressed: demo.createExample,
                    child: const Text('Crear ejemplo pendiente'),
                  ),
                if (status == OfflineDemoStatus.pending)
                  FilledButton(
                    onPressed: demo.recoverConnection,
                    child: const Text('Simular conexión recuperada'),
                  ),
                if (status == OfflineDemoStatus.sending) ...[
                  FilledButton(
                    onPressed: () {
                      if (demo.succeed()) {
                        context.push(AppRoute.synced.path, extra: demo);
                      }
                    },
                    child: const Text('Simular éxito'),
                  ),
                  OutlinedButton(
                    onPressed: demo.fail,
                    child: const Text('Simular error'),
                  ),
                ],
                OutlinedButton(
                  onPressed: status == OfflineDemoStatus.error
                      ? demo.retry
                      : null,
                  child: const Text('Simular reintento'),
                ),
                if (status != OfflineDemoStatus.offline)
                  TextButton(
                    onPressed: demo.reset,
                    child: const Text('Restablecer demostración'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
