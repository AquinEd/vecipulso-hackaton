import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/map_point.dart';
import '../controllers/map_points_controller.dart';
import '../controllers/map_filters_controller.dart';
import 'map_point_style.dart';
import 'map_point_summary.dart';

export 'map_point_style.dart';

class MapPointsLayer extends StatelessWidget {
  const MapPointsLayer({super.key, required this.controller, this.filters});
  final MapPointsController controller;
  final MapFiltersController? filters;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, ?filters]),
    builder: (_, _) {
      final groups = <(double, double), List<MapPoint>>{};
      final source = controller.result?.points ?? <MapPoint>[];
      for (final point in filters?.apply(source) ?? source) {
        groups
            .putIfAbsent((
              point.coordinate.latitude,
              point.coordinate.longitude,
            ), () => [])
            .add(point);
      }
      return MarkerLayer(
        markers: [
          for (final group in groups.values)
            Marker(
              point: LatLng(
                group.first.coordinate.latitude,
                group.first.coordinate.longitude,
              ),
              width: 48,
              height: 48,
              child: IconButton(
                key: ValueKey('map-point:${group.first.key}'),
                tooltip: group.length == 1
                    ? '${pointLayerLabel(group.first.layer)}: ${group.first.title}'
                    : '${group.length} puntos en esta ubicación aproximada',
                style: IconButton.styleFrom(
                  backgroundColor: pointColor(group.first.layer),
                  foregroundColor: Colors.white,
                ),
                icon: group.length == 1
                    ? Icon(pointIcon(group.first.layer))
                    : Badge(
                        label: Text('${group.length}'),
                        child: const Icon(Icons.layers),
                      ),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => MapPointSummary(
                    controller: controller,
                    filters: filters,
                    keys: group.map((point) => point.key).toSet(),
                    hostContext: context,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class MapPointsStatus extends StatelessWidget {
  const MapPointsStatus({
    super.key,
    required this.controller,
    required this.onRefresh,
    this.filters,
  });
  final MapPointsController controller;
  final VoidCallback onRefresh;
  final MapFiltersController? filters;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, ?filters]),
    builder: (_, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.stage == MapPointsStage.loading) ...[
          const LinearProgressIndicator(),
          const Text('Consultando puntos de tu zona…'),
        ],
        if (controller.stage == MapPointsStage.originRequired)
          const Text(
            'Para consultar puntos usa tu ubicación o recupera el centro de tu zona. La vista general no es un origen de búsqueda.',
          ),
        if (controller.stage == MapPointsStage.empty)
          const Text('No hay puntos disponibles para esta consulta.'),
        if (controller.failure != null) Text(controller.failure!.message),
        if (controller.result case final result?) ...[
          if (result.points.isNotEmpty &&
              (filters?.apply(result.points).isEmpty ?? false))
            const Text('No hay coincidencias con estos filtros.'),
          Text(
            '${filters?.apply(result.points).length ?? result.points.length} de ${result.points.length} puntos autorizados · radio de consulta ${controller.radiusMeters} m',
          ),
          if (controller.updatedAt case final date?)
            Text(
              'Consulta actualizada: ${date.toLocal().toIso8601String().split(".").first}',
            ),
          if (result.truncated)
            const Text(
              'Se alcanzó el límite de la consulta. Se muestran hasta 500 puntos; la lista puede estar incompleta.',
            ),
        ],
        TextButton(
          onPressed: controller.stage == MapPointsStage.loading
              ? null
              : onRefresh,
          child: Text(
            controller.failure == null
                ? 'Actualizar puntos'
                : 'Reintentar puntos',
          ),
        ),
      ],
    ),
  );
}
