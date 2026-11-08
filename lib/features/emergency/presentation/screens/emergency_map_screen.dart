import 'package:flutter/material.dart';

import '../../../../app/app_navigation.dart';
import '../../../../app/app_routes.dart';
import '../../../maps/presentation/controllers/map_filters_controller.dart';
import '../../../maps/presentation/widgets/map_filters_panel.dart';
import '../../../maps/presentation/widgets/geographic_map_canvas.dart';

const emergencyMapNotice =
    'Cartografía real — Puntos autorizados de la comunidad. No indica zonas de peligro oficiales.';

class EmergencyMapScreen extends StatefulWidget {
  const EmergencyMapScreen({super.key});
  @override
  State<EmergencyMapScreen> createState() => _EmergencyMapScreenState();
}

class _EmergencyMapScreenState extends State<EmergencyMapScreen> {
  final filters = MapFiltersController();
  @override
  void dispose() {
    filters.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xffffece8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                emergencyMapNotice,
                style: TextStyle(
                  color: Color(0xff80242b),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          MapFiltersPanel(controller: filters, compact: true),
          const SizedBox(height: 12),
          GeographicMapCanvas(emergency: true, filters: filters),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Reportes y recursos'),
          ),
          TextButton(
            onPressed: () => AppNavigation.open(context, AppRoute.sos),
            child: const Text('Volver al Tablero SOS'),
          ),
          TextButton(
            onPressed: () => AppNavigation.exitSos(context),
            child: const Text('Salir del Modo SOS'),
          ),
        ],
      ),
    );
  }
}
