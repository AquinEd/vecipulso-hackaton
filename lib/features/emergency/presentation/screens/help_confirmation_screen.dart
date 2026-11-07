import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../services/utils/provider_display_name.dart';
import '../../data/demo_emergency_actions.dart';
import '../../models/emergency_action_option.dart';
import '../../models/confirmation_origin.dart';
import '../../models/emergency_action_type.dart';

class HelpConfirmationScreen extends StatelessWidget {
  const HelpConfirmationScreen({super.key, this.category});
  final EmergencyActionCategory? category;

  void showNotice(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final support = demoEmergencyActions.firstWhere(
      (a) => a.type == EmergencyActionType.criticalSupport,
    );
    final selected = support.options
        .where((o) => o.category == category)
        .firstOrNull;
    final option = selected ?? support.options.first;
    final need =
        '${selected == null ? "Necesidad de ejemplo" : "Necesidad seleccionada"}: ${option.label}';
    final theme = Theme.of(context).textTheme;
    const gap = SizedBox(height: AppSpacing.medium);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Color(0xffdbf5e6),
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.primary,
                    child: Icon(
                      Icons.check_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              gap,
              Text(
                'DEMOSTRACIÓN',
                textAlign: TextAlign.center,
                style: theme.labelLarge?.copyWith(color: AppColors.primary),
              ),
              Semantics(
                header: true,
                child: Text(
                  'Vista previa de ayuda',
                  textAlign: TextAlign.center,
                  style: theme.headlineSmall,
                ),
              ),
              gap,
              const Text(
                'Así se visualizaría una solicitud de ayuda comunitaria. Ningún vecino ha sido contactado.',
                textAlign: TextAlign.center,
              ),
              gap,
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xffdbf5e6),
                        child: Icon(Icons.person, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.medium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatProviderDisplayName('Pedro', 'G'),
                              style: theme.titleLarge,
                            ),
                            const Text('Voluntario de ejemplo'),
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
                child: Text('Opciones de contacto', style: theme.titleMedium),
              ),
              const SizedBox(height: AppSpacing.small),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      MediaQuery.textScalerOf(context).scale(16) > 24 ? 1 : 3;
                  final width =
                      (constraints.maxWidth -
                          (columns - 1) * AppSpacing.small) /
                      columns;
                  return Wrap(
                    spacing: AppSpacing.small,
                    runSpacing: AppSpacing.small,
                    children: [
                      for (final (label, icon) in const [
                        ('Llamar', Icons.call_outlined),
                        ('Chat', Icons.chat_bubble_outline),
                        ('Ubicar', Icons.location_on_outlined),
                      ])
                        SizedBox(
                          width: width,
                          child: Tooltip(
                            message: '$label (demostración)',
                            child: FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.all(AppSpacing.small),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                ),
                              ),
                              onPressed: () => showNotice(
                                context,
                                label,
                                '$label todavía no está disponible en esta demostración.',
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [Icon(icon), Text(label)],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              gap,
              Container(
                padding: const EdgeInsets.all(AppSpacing.medium),
                decoration: BoxDecoration(
                  color: const Color(0xffe9f4fa),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.map,
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(child: Text(need, style: theme.titleMedium)),
                  ],
                ),
              ),
              gap,
              AppButton(
                label: 'Ver detalles de la ayuda',
                icon: Icons.info_outline,
                onPressed: () => showNotice(
                  context,
                  'Detalles de la ayuda',
                  'Tipo de ayuda: ${support.title}\n$need\n$emergencyDemoLocation\n\nDemostración — solicitud no enviada\nNingún voluntario ha aceptado esta solicitud.',
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              OutlinedButton(
                onPressed: () => context.go(
                  AppRoute.tracking.path,
                  extra: ConfirmationOrigin(selected?.category),
                ),
                child: const Text('Ver simulación de seguimiento'),
              ),
              const SizedBox(height: AppSpacing.small),
              OutlinedButton(
                onPressed: () => context.go(AppRoute.sos.path),
                child: const Text('Regresar al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
