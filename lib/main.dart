import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/maps/data/map_environment.dart';
import 'features/maps/data/map_points_repository.dart';
import 'features/maps/presentation/controllers/map_points_controller.dart';
import 'features/maps/data/location_service.dart';
import 'features/maps/presentation/controllers/location_controller.dart';
import 'features/maps/data/map_origin_repository.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'core/errors/auth_failure.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final problem = SupabaseConfig.problem;
  late final AuthController auth;
  MapOriginRepository? mapOrigins;
  MapPointsRepository? mapPoints;
  if (problem != null) {
    auth = AuthController.unavailable(problem);
  } else {
    try {
      final supabase = await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.key,
        debug: false,
      );
      auth = AuthController(SupabaseAuthRepository(supabase.client));
      mapOrigins = SupabaseMapOriginRepository(supabase.client);
      mapPoints = SupabaseMapPointsRepository(supabase.client);
    } catch (error) {
      auth = AuthController.unavailable(
        '${AuthFailure.from(error).message} Reinicia la aplicación.',
        configured: true,
      );
    }
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => LocationController(
        GeolocatorLocationService(),
        sessionId: () => auth.observedId,
      ),
      child: ChangeNotifierProvider<MapPointsController?>(
        create: (_) =>
            mapPoints == null ? null : MapPointsController(mapPoints),
        child: Provider<MapEnvironment>.value(
          value: MapEnvironment.openStreetMap(origins: mapOrigins),
          child: VeciPulsoApp(auth: auth),
        ),
      ),
    ),
  );
  if (auth.repository != null) unawaited(auth.restore());
}
