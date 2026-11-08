import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:hackaton_veci_pulso/features/maps/data/map_environment.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/widgets/geographic_map_canvas.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android: mosaicos reales, cámara, zoom y gesto táctil', (
    tester,
  ) async {
    await tester.pumpWidget(
      Provider<MapEnvironment>.value(
        value: MapEnvironment.openStreetMap(),
        child: const MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(child: GeographicMapCanvas()),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byKey(const ValueKey('tiles-loading')).evaluate().isEmpty) break;
    }
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tiles-loading')),
      findsNothing,
      reason: 'No se confirmó la carga de cartografía real',
    );
    expect(
      find.textContaining('No se pudieron cargar algunos mosaicos'),
      findsNothing,
    );
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    expect(find.text('Vista general · no es tu ubicación'), findsOneWidget);
    final camera = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    final initialZoom = camera.camera.zoom;
    await tester.tap(find.byTooltip('Acercar mapa'));
    await tester.pumpAndSettle();
    expect(camera.camera.zoom, initialZoom + 1);
    final before = camera.camera.center;
    await tester.drag(find.byType(FlutterMap), const Offset(70, 0));
    await tester.pumpAndSettle();
    expect(camera.camera.center, isNot(before));
    await tester.tap(find.byTooltip('Centrar vista inicial'));
    await tester.pumpAndSettle();
    expect(camera.camera.center.latitude, 0);
    expect(camera.camera.zoom, initialZoom);
    expect(tester.takeException(), isNull);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    final png = await binding.takeScreenshot('vecipulso_map_6_2');
    await File('${Directory.systemTemp.path}/vecipulso_map_6_2.png')
        .writeAsBytes(png);
    // No login, GPS, application data, SOS or Supabase writes in this harness.
  }, skip: !const bool.fromEnvironment('ALLOW_MAP_TILE_CHECK'));
}
