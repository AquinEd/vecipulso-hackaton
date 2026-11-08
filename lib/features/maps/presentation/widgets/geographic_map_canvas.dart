import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_mode_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/location_service.dart';
import '../controllers/location_controller.dart';
import '../controllers/map_points_controller.dart';
import '../controllers/map_filters_controller.dart';
import 'map_points_layer.dart';
import '../../data/map_environment.dart';
import '../../models/map_origin.dart';

class GeographicMapCanvas extends StatefulWidget {
  const GeographicMapCanvas({super.key, this.emergency = false, this.filters});
  final bool emergency;
  final MapFiltersController? filters;
  @override
  State<GeographicMapCanvas> createState() => _GeographicMapCanvasState();
}

class _GeographicMapCanvasState extends State<GeographicMapCanvas>
    with WidgetsBindingObserver {
  final camera = MapController();
  LocationController? positions;
  MapPointsController? mapPoints;
  DeviceLocation? lastFix;
  String? viewer;
  MapOrigin get visibleOrigin {
    final fix = positions?.location;
    return fix == null ? origin : MapOrigin(fix.coordinate, fix.label);
  }

  MapEnvironment? environment;
  MapOrigin origin = MapOrigin.neutral;
  bool requested = false, locating = false, originError = false;
  bool ready = false, loaded = false, tileError = false;
  bool suspended = false;
  int generation = 0, attempt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    suspended =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final next =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (!mounted || next == suspended) return;
    setState(() => suspended = next);
    if (!next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !isActive()) return;
        final fix = positions?.location;
        if (fix != lastFix) {
          lastFix = fix;
          if (ready) center();
        }
        refreshPoints(force: true);
      });
    }
  }

  bool isActive() {
    final mode = context.read<AppModeController?>();
    return !suspended &&
        TickerMode.valuesOf(context).enabled &&
        (mode == null || mode.isSos == widget.emergency);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    mapPoints = context.read<MapPointsController?>();
    mapPoints?.syncSession(notify: false);
    positions = context.watch<LocationController?>();
    positions?.syncSession(notify: false);
    final identity = context.watch<AuthController?>()?.observedId;
    if (identity != viewer) {
      viewer = identity;
      generation++;
      requested = false;
      origin = MapOrigin.neutral;
    }
    final next = context.watch<MapEnvironment?>() ?? const MapEnvironment();
    if (environment != next &&
        (environment?.createTiles != next.createTiles ||
            environment?.origins != next.origins ||
            environment?.sessionOrigin != next.sessionOrigin)) {
      generation++;
      requested = false;
      environment = next;
    }
    environment ??= next;
    final mode = context.watch<AppModeController?>();
    final active =
        !suspended &&
        (mode == null || mode.isSos == widget.emergency) &&
        TickerMode.valuesOf(context).enabled;
    final fix = positions?.location;
    if (active && fix != lastFix) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ready) center();
      });
    }
    if (active) lastFix = fix;
    if (active && (!locating || fix != null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) refreshPoints();
      });
    }
    if (active && !requested) {
      requested = true;
      unawaited(loadOrigin(notify: false));
    }
  }

  Future<void> loadOrigin({bool notify = true}) async {
    final request = ++generation;
    final source = environment!;
    void loading() {
      locating = source.origins != null && source.sessionOrigin == null;
      originError = false;
    }

    if (notify) {
      setState(loading);
    } else {
      loading();
    }
    // A synchronous session origin must not notify another provider during build.
    await Future<void>.value();
    if (!mounted || request != generation) return;
    try {
      final result = source.sessionOrigin ?? await source.origins?.load();
      if (!mounted || request != generation) return;
      setState(() {
        origin = result ?? MapOrigin.neutral;
        locating = false;
      });
      if (ready) center();
      refreshPoints();
    } catch (_) {
      if (!mounted || request != generation) return;
      setState(() {
        origin = MapOrigin.neutral;
        locating = false;
        originError = true;
      });
      if (ready) center();
      refreshPoints();
    }
  }

  void refreshPoints({bool force = false}) {
    final mode = context.read<AppModeController?>();
    if (suspended ||
        !TickerMode.valuesOf(context).enabled ||
        mode != null && mode.isSos != widget.emergency) {
      return;
    }
    final controller = mapPoints;
    if (controller == null) return;
    if (visibleOrigin.isNeutral) {
      controller.requireOrigin();
    } else {
      unawaited(controller.refresh(visibleOrigin.coordinate, force: force));
    }
  }

  LatLng point(MapOrigin o) => LatLng(
    o.coordinate.latitude.clamp(-85.05112878, 85.05112878),
    o.coordinate.longitude,
  );
  void center() =>
      camera.move(point(visibleOrigin), visibleOrigin.zoom.clamp(2, 19));
  void zoom(double delta) => camera.move(
    camera.camera.center,
    (camera.camera.zoom + delta).clamp(2, 19),
  );
  void status(int version, {bool success = false, bool failure = false}) {
    if (loaded && !failure || tileError && failure) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || attempt != version) return;
      if (success && !loaded || failure && !tileError) {
        setState(() {
          loaded |= success;
          tileError |= failure;
        });
      }
    });
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final env = environment ?? const MapEnvironment();
    final mode = context.watch<AppModeController?>();
    final active =
        !suspended &&
        (mode == null || mode.isSos == widget.emergency) &&
        TickerMode.valuesOf(context).enabled;
    final version = attempt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(visibleOrigin.label, key: const ValueKey('map-origin')),
        if (positions case final gps?) ...[
          FilledButton.icon(
            onPressed: gps.busy ? null : gps.locate,
            icon: const Icon(Icons.my_location),
            label: Text(
              gps.location == null
                  ? 'Usar mi ubicación'
                  : 'Actualizar mi ubicación',
            ),
          ),
          const Text(
            'La lectura no se publica como registro. Consultar puntos envía el origen a Supabase; al centrar, el proveedor de mapas recibe el área visualizada.',
          ),
          if (gps.busy)
            const LinearProgressIndicator(key: ValueKey('gps-loading')),
          if (gps.failure != null) Text(gps.failure!.message),
          if (gps.location case final fix?)
            Text(
              '${fix.accuracyLabel} · ${fix.measuredAt.toLocal().toIso8601String().split(".").first}',
            ),
        ],
        if (locating) const LinearProgressIndicator(),
        if (originError) ...[
          const Text(
            'No se pudo obtener el centro de tu zona. Se muestra una vista general.',
          ),
          TextButton(
            onPressed: loadOrigin,
            child: const Text('Reintentar centro'),
          ),
        ],
        if (mapPoints case final controller?)
          MapPointsStatus(
            controller: controller,
            filters: widget.filters,
            onRefresh: () => refreshPoints(force: true),
          ),
        if (env.createTiles == null)
          const Text('Cartografía sin proveedor configurado'),
        if (active && env.createTiles != null && !loaded && !tileError)
          const Text('Cargando cartografía…', key: ValueKey('tiles-loading')),
        if (tileError) ...[
          const Text(
            'No se pudieron cargar algunos mosaicos. Comprueba tu conexión.',
          ),
          TextButton(
            onPressed: () => setState(() {
              attempt++;
              loaded = false;
              tileError = false;
            }),
            child: const Text('Reintentar cartografía'),
          ),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 360,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: camera,
                  options: MapOptions(
                    initialCenter: point(visibleOrigin),
                    initialZoom: visibleOrigin.zoom.clamp(2, 19),
                    minZoom: 2,
                    maxZoom: 19,
                    onMapReady: () {
                      ready = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                  children: [
                    if (active && env.createTiles != null)
                      _TileSurface(
                        key: ValueKey((env, version)),
                        environment: env,
                        onFailure: () => status(version, failure: true),
                        onSuccess: () => status(version, success: true),
                      ),
                    if (mapPoints case final controller?)
                      MapPointsLayer(
                        controller: controller,
                        filters: widget.filters,
                      ),
                    if (positions?.location case final fix?)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point(MapOrigin(fix.coordinate, fix.label)),
                            width: 44,
                            height: 44,
                            child: IgnorePointer(
                              child: Tooltip(
                                message: fix.label,
                                child: Semantics(
                                  label: 'Tu última lectura de ubicación, visible solo en este dispositivo',
                                  child: const Icon(
                                    Icons.my_location,
                                    key: ValueKey('own-position'),
                                    color: Colors.blue,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Card(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Acercar mapa',
                          onPressed: ready ? () => zoom(1) : null,
                          icon: const Icon(Icons.add),
                        ),
                        IconButton(
                          tooltip: 'Alejar mapa',
                          onPressed: ready ? () => zoom(-1) : null,
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton(
                          tooltip: 'Centrar vista inicial',
                          onPressed: ready ? center : null,
                          icon: const Icon(Icons.center_focus_strong),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () async {
                          try {
                            final opened = await launchUrl(
                              Uri.parse(
                                'https://www.openstreetmap.org/copyright',
                              ),
                              mode: LaunchMode.externalApplication,
                            );
                            if (!opened) throw StateError('No disponible');
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Atribución: https://www.openstreetmap.org/copyright',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          '© OpenStreetMap contributors',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TileSurface extends StatefulWidget {
  const _TileSurface({
    super.key,
    required this.environment,
    required this.onSuccess,
    required this.onFailure,
  });
  final MapEnvironment environment;
  final VoidCallback onSuccess, onFailure;
  @override
  State<_TileSurface> createState() => _TileSurfaceState();
}

class _TileSurfaceState extends State<_TileSurface> {
  late final tiles = widget.environment.createTiles!();
  // TileLayer owns and disposes its TileProvider.
  @override
  Widget build(BuildContext context) => TileLayer(
    urlTemplate: MapEnvironment.tileUrl,
    userAgentPackageName: 'VeciPulso',
    tileProvider: tiles,
    panBuffer: 0,
    maxNativeZoom: 19,
    tileDisplay: const TileDisplay.instantaneous(),
    errorTileCallback: (_, _, _) => widget.onFailure(),
    tileBuilder: (_, child, tile) {
      if (tile.imageInfo != null && !tile.loadError) widget.onSuccess();
      return child;
    },
  );
}
