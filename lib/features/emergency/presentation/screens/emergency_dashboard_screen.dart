import 'package:flutter/material.dart';

import '../../../../app/app_navigation.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/common/app_section_header.dart';
import '../../data/demo_emergency_reports.dart';
import '../widgets/emergency_report_card.dart';
import '../widgets/emergency_report_details.dart';

class EmergencyDashboardScreen extends StatefulWidget {
  const EmergencyDashboardScreen({super.key});

  @override
  State<EmergencyDashboardScreen> createState() =>
      _EmergencyDashboardScreenState();
}

class _EmergencyDashboardScreenState extends State<EmergencyDashboardScreen> {
  bool expanded = false;

  void showNotice(String title, String message) => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Text(message),
      scrollable: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: AppColors.sos,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Modo Emergencia',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'MODO DEMOSTRACIÓN — No hay alertas reales verificadas',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xff9d2030),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Simulación de zona de riesgo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Los reportes mostrados son ejemplos y no representan emergencias activas',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => AppNavigation.exitSos(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Salir del Modo SOS'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 592),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSectionHeader(title: 'Reportes de la comunidad'),
                  const SizedBox(height: 8),
                  const Text('Reportes de ejemplo · Distancias simuladas'),
                  const SizedBox(height: 16),
                  for (final report in demoEmergencyReports.take(
                    expanded ? demoEmergencyReports.length : 3,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: EmergencyReportCard(
                        key: ValueKey(report.id),
                        report: report,
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          useRootNavigator: true,
                          useSafeArea: true,
                          isScrollControlled: true,
                          showDragHandle: true,
                          builder: (_) =>
                              EmergencyReportDetails(report: report),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const AppSectionHeader(title: 'Acciones rápidas'),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final request = AppButton(
                        label: 'Solicitar ayuda',
                        icon: Icons.warning_rounded,
                        sos: true,
                        onPressed: () => showNotice(
                          'Solicitud de ayuda no disponible todavía',
                          'Esta función estará disponible cuando se integren el registro de emergencias y el servidor. No se ha enviado ninguna solicitud',
                        ),
                      );
                      final offer = AppButton(
                        label: 'Ofrecer ayuda',
                        icon: Icons.volunteer_activism_outlined,
                        onPressed: () => showNotice(
                          'Ofrecer ayuda estará disponible próximamente',
                          'Podrás ofrecer recursos y apoyo a otros vecinos cuando se implemente este módulo',
                        ),
                      );
                      if (constraints.maxWidth < 400 ||
                          MediaQuery.textScalerOf(context).scale(14) > 18) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            request,
                            const SizedBox(height: 12),
                            offer,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: request),
                          const SizedBox(width: 12),
                          Expanded(child: offer),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () =>
                        AppNavigation.open(context, AppRoute.riskMap),
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Ver mapa de reportes'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: expanded
                        ? 'Contraer reportes'
                        : 'Ver todos los reportes',
                    icon: expanded ? Icons.unfold_less : Icons.list_alt,
                    sos: true,
                    onPressed: () => setState(() => expanded = !expanded),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'VeciPulso es una demostración comunitaria. No es un servicio oficial de emergencias.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
