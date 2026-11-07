import 'package:flutter/material.dart';

import '../../../../app/app_navigation.dart';
import '../../../../app/app_routes.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/common/app_section_header.dart';

class EmergencyMapPlaceholderScreen extends StatelessWidget {
  const EmergencyMapPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader(title: 'Mapa de Reportes SOS'),
          const SizedBox(height: 16),
          const Text(
            'Esta vista permitirá consultar reportes y recursos comunitarios durante una emergencia',
          ),
          const SizedBox(height: 16),
          const Text('Demostración — Mapa SOS pendiente de implementación'),
          const SizedBox(height: 24),
          AppButton(
            label: 'Volver al Tablero SOS',
            icon: Icons.warning_rounded,
            sos: true,
            onPressed: () => AppNavigation.open(context, AppRoute.sos),
          ),
          TextButton(
            onPressed: () => AppNavigation.exitSos(context),
            child: const Text('Salir del Modo SOS'),
          ),
        ],
      ),
    ),
  );
}
