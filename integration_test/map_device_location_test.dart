import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:hackaton_veci_pulso/features/maps/data/location_service.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/controllers/location_controller.dart';
import 'package:hackaton_veci_pulso/features/maps/presentation/widgets/geographic_map_canvas.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android: lectura nativa puntual con permiso preautorizado y posición sintética',
    (t) async {
      // Opt-in harness: configure ONLY the test emulator via Android settings/adb.
      // Does not test the consent dialog and never reads Supabase or real accounts.
      expect(await Geolocator.isLocationServiceEnabled(), isTrue);
      // Flutter can reinstall the APK and reset emulator grants. The harness
      // waits for external test setup; it does not grant/request permissions.
      debugPrint('WAITING_FOR_TEST_LOCATION_PERMISSION');
      var permission = await Geolocator.checkPermission();
      for (var i = 0; i < 60 && permission == LocationPermission.denied; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        permission = await Geolocator.checkPermission();
      }
      expect(
        permission,
        anyOf(LocationPermission.whileInUse, LocationPermission.always),
      );
      final gps = LocationController(GeolocatorLocationService());
      addTearDown(gps.dispose);
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: gps,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: GeographicMapCanvas()),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(gps.stage, LocationStage.initial);
      expect(find.byKey(const ValueKey('own-position')), findsNothing);
      await t.tap(find.text('Usar mi ubicación'));
      for (var i = 0; i < 60 && gps.stage == LocationStage.loading; i++) {
        await t.pump(const Duration(milliseconds: 500));
      }
      expect(gps.stage, LocationStage.ready, reason: gps.failure?.message);
      expect(
        gps.location!.coordinate.latitude,
        closeTo(
          double.parse(
            const String.fromEnvironment(
              'TEST_LOCATION_LAT',
              defaultValue: '-12',
            ),
          ),
          .01,
        ),
      );
      expect(
        gps.location!.coordinate.longitude,
        closeTo(
          double.parse(
            const String.fromEnvironment(
              'TEST_LOCATION_LNG',
              defaultValue: '-77',
            ),
          ),
          .01,
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('own-position')), findsOneWidget);
      final camera = t
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      expect(camera.camera.center.latitude, gps.location!.coordinate.latitude);
      expect(
        camera.camera.center.longitude,
        gps.location!.coordinate.longitude,
      );
      expect(find.textContaining('lectura puntual'), findsWidgets);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    skip: !const bool.fromEnvironment('ALLOW_NATIVE_MAP_LOCATION_CHECK'),
  );
}
