import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_navigation.dart';
import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/common/app_asset_image.dart';
import '../../../services/utils/provider_display_name.dart';
import '../../data/demo_emergency_actions.dart';
import '../../models/confirmation_origin.dart';
import '../../models/emergency_action_type.dart';
import '../widgets/help_demo_chat_sheet.dart';
import '../widgets/help_route_preview.dart';

class HelpTrackingScreen extends StatelessWidget {
  const HelpTrackingScreen({super.key, this.origin});
  final ConfirmationOrigin? origin;

  void back(BuildContext context) {
    if (origin == null) {
      context.go(AppRoute.sos.path);
    } else {
      context.go(AppRoute.help.path, extra: origin?.category);
    }
  }

  void showCallNotice(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Llamar'),
        content: const Text(
          'Las llamadas estarán disponibles cuando se habilite la coordinación real de ayuda. Esta es una demostración.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = demoEmergencyActions
        .firstWhere((a) => a.type == EmergencyActionType.criticalSupport)
        .options;
    final selected = options
        .where((o) => o.category == origin?.category)
        .firstOrNull;
    final theme = Theme.of(context).textTheme;
    const gap = SizedBox(height: AppSpacing.medium);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => back(context)),
          title: const AppAssetImage(
            path: AppAssets.vecipulsoLogoHorizontalPNG,
            label: 'VeciPulso',
            height: 40,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Coordinación de ayuda · Demo',
                        style: theme.headlineSmall,
                      ),
                    ),
                    gap,
                    Card(
                      color: const Color(0xffe4f4ed),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.small),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Simulación de coordinación',
                                    style: theme.titleMedium,
                                  ),
                                  const Text(
                                    'Vista ilustrativa de cómo podría coordinarse una ayuda entre vecinos.',
                                  ),
                                  const SizedBox(height: AppSpacing.small),
                                  const Text(
                                    'Demostración: ninguna solicitud fue enviada ni aceptada.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    gap,
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                            const SizedBox(width: AppSpacing.small),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formatProviderDisplayName(
                                      'María',
                                      'Torres',
                                    ),
                                    style: theme.titleLarge,
                                  ),
                                  const Text(
                                    'Vecina que necesitaría ayuda · Perfil ficticio',
                                  ),
                                  Text(
                                    '${selected == null ? "Necesidad de ejemplo" : "Necesidad seleccionada"}: ${(selected ?? options.first).label}',
                                  ),
                                  const SizedBox(height: AppSpacing.small),
                                  Text(
                                    'Voluntario que podría ayudar: ${formatProviderDisplayName("Pedro", "G")} (ejemplo)',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    gap,
                    Semantics(
                      header: true,
                      child: Text('Mapa orientativo', style: theme.titleLarge),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    const HelpRoutePreview(),
                    const SizedBox(height: AppSpacing.small),
                    const Text(
                      'Ruta ilustrativa. No representa ubicación en tiempo real ni garantiza condiciones seguras de tránsito.',
                    ),
                    gap,
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.medium,
                      runSpacing: AppSpacing.small,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => showCallNotice(context),
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('Llamar'),
                        ),
                        FilledButton.icon(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            showDragHandle: true,
                            builder: (_) => const HelpDemoChatSheet(),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat'),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => AppNavigation.exitSos(context),
                      child: const Text('Salir del Modo SOS'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
