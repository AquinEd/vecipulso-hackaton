import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/map_points_repository.dart';
import '../../models/map_point.dart';
import '../controllers/map_filters_controller.dart';
import '../controllers/map_points_controller.dart';
import '../navigation/map_point_navigation.dart';
import 'map_point_style.dart';

class MapPointSummary extends StatefulWidget {
  const MapPointSummary({
    super.key,
    required this.controller,
    required this.keys,
    required this.hostContext,
    this.filters,
  });
  final MapPointsController controller;
  final MapFiltersController? filters;
  final Set<String> keys;
  final BuildContext hostContext;
  @override
  State<MapPointSummary> createState() => _MapPointSummaryState();
}

class _MapPointSummaryState extends State<MapPointSummary> {
  bool checking = true, opening = false;
  String? message;
  List<MapPoint> get current {
    final points = widget.controller.result?.points ?? <MapPoint>[];
    return (widget.filters?.apply(points) ?? points)
        .where((p) => widget.keys.contains(p.key))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) check();
    });
  }

  Future<void> check() async {
    if (!mounted) return;
    setState(() {
      checking = true;
      message = null;
    });
    await widget.controller.refreshCurrent();
    if (mounted) setState(() => checking = false);
  }

  Future<void> open(MapPoint selected, MapPointOpener opener) async {
    if (opening || checking) return;
    setState(() {
      opening = true;
      message = null;
    });
    await widget.controller.refreshCurrent();
    if (!mounted) return;
    final point = current.where((p) => p.key == selected.key).firstOrNull;
    if (point == null || widget.controller.failure != null) {
      setState(() {
        opening = false;
        message =
            widget.controller.failure?.message ??
            'El punto ya no está disponible en esta consulta.';
      });
      return;
    }
    final host = widget.hostContext;
    Navigator.pop(context);
    try {
      if (host.mounted) await opener(host, point);
    } catch (error) {
      if (host.mounted) {
        ScaffoldMessenger.of(host).showSnackBar(
          SnackBar(
            content: Text(
              error is MapPointsFailure ? error.message : 'No se pudo abrir el detalle. El destino no está disponible.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigation =
        context.watch<MapPointNavigation?>() ?? const MapPointNavigation();
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        if (widget.filters != null) widget.filters!,
      ]),
      builder: (_, _) {
        final busy =
            checking ||
            opening ||
            widget.controller.stage == MapPointsStage.loading;
        return AlertDialog(
          scrollable: true,
          title: const Text('Ubicación comunitaria aproximada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) const LinearProgressIndicator(),
              if (message != null) Text(message!),
              if (widget.controller.failure != null)
                Text(widget.controller.failure!.message),
              if (!busy && widget.controller.failure == null && current.isEmpty)
                const Text('El punto ya no está disponible en esta consulta.'),
              if (!busy && widget.controller.failure == null)
                for (final point in current) ...[
                  ListTile(
                    leading: Icon(
                      pointIcon(point.layer),
                      color: pointColor(point.layer),
                    ),
                    title: Text(point.title),
                    subtitle: Text(
                      [
                        pointLayerLabel(point.layer),
                        point.subtype,
                        point.layer == MapPointLayer.alerta &&
                                point.state == 'verificada'
                            ? 'Confirmada por vecinos'
                            : point.state.replaceAll('_', ' '),
                        if (point.urgency != null) point.urgency!.name,
                        '${point.distanceMeters} m desde el origen de consulta',
                      ].join(' · '),
                    ),
                  ),
                  if (navigation.forLayer(point.layer) case final opener?)
                    TextButton(
                      key: ValueKey('open-point:${point.key}'),
                      onPressed: () => open(point, opener),
                      child: const Text('Ver detalles'),
                    )
                  else
                    const Text(
                      'El detalle de este módulo no está disponible por ahora.',
                    ),
                ],
              const Text(
                'Información autorizada al actualizar. Ubicación aproximada; la disponibilidad registrada no reserva recursos.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : check,
              child: const Text('Actualizar ficha'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}
