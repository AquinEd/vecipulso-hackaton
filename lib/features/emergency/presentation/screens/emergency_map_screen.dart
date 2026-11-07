import 'package:flutter/material.dart';

import '../../../../app/app_navigation.dart';
import '../../../../app/app_routes.dart';
import '../../data/demo_emergency_map_markers.dart';
import '../../models/emergency_map_marker.dart';
import '../widgets/emergency_map_canvas.dart';
import '../widgets/emergency_report_details.dart';

const emergencyMapNotice =
    'MAPA DE DEMOSTRACIÓN — No representa emergencias ni ubicaciones reales.';

class EmergencyMapScreen extends StatefulWidget {
  const EmergencyMapScreen({super.key});
  @override
  State<EmergencyMapScreen> createState() => _EmergencyMapScreenState();
}

class _EmergencyMapScreenState extends State<EmergencyMapScreen> {
  final selected = EmergencyMapCategory.values.toSet();
  bool get all => selected.length == EmergencyMapCategory.values.length;

  void details(EmergencyMapMarker marker) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final report = marker.report;
        if (report != null) return EmergencyReportDetails(report: report);
        final brigade = marker.brigade;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  marker.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (brigade != null) ...[
                  Text('Tipo de grupo: ${brigade.typeLabel}'),
                  Text('Sector de ejemplo: ${brigade.sectorLabel}'),
                  Text('Integrantes de demostración: ${brigade.memberCount}'),
                ] else ...[
                  Text(marker.description!),
                  const Text('Tipo de recurso: refugio temporal'),
                  const Text('Disponibilidad ficticia para la demostración'),
                ],
                const SizedBox(height: 16),
                const Text(emergencyMapNotice),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = demoEmergencyMapMarkers
        .where((m) => selected.contains(m.category))
        .toList();
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
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('Todos'),
                selected: all,
                onSelected: (_) => setState(
                  () => selected.addAll(EmergencyMapCategory.values),
                ),
              ),
              for (final category in EmergencyMapCategory.values)
                FilterChip(
                  label: Text(category.filter),
                  selected: !all && selected.contains(category),
                  onSelected: (enable) => setState(() {
                    if (all) selected.clear();
                    if (enable) {
                      selected.add(category);
                    } else {
                      selected.remove(category);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          EmergencyMapCanvas(markers: markers, onSelect: details),
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reportes y recursos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  for (final category in EmergencyMapCategory.values.where(
                    selected.contains,
                  ))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(category.icon, color: category.color),
                          const SizedBox(width: 12),
                          Expanded(child: Text(category.label)),
                        ],
                      ),
                    ),
                  const Divider(),
                  const Row(
                    children: [
                      Icon(Icons.circle, color: Color(0xffcd846f), size: 20),
                      SizedBox(width: 12),
                      Expanded(child: Text('Zona de riesgo ilustrativa')),
                    ],
                  ),
                ],
              ),
            ),
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
