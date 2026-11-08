import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hackaton_veci_pulso/core/config/supabase_config.dart';
import 'package:hackaton_veci_pulso/features/maps/data/map_origin_repository.dart';
import 'package:hackaton_veci_pulso/features/maps/data/map_points_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test('Lectura geográfica autorizada con dos cuentas sintéticas de distintas zonas', () async {
    expect(SupabaseConfig.problem, isNull);
    expect(
      const String.fromEnvironment('MAP_READ_PROJECT_URL'),
      SupabaseConfig.url,
    );
    expect(
      const String.fromEnvironment('MAP_READ_ENVIRONMENT'),
      'synthetic-read-only',
    );
    const accounts = [
      (
        email: String.fromEnvironment('MAP_READ_EMAIL_A'),
        password: String.fromEnvironment('MAP_READ_PASSWORD_A'),
      ),
      (
        email: String.fromEnvironment('MAP_READ_EMAIL_B'),
        password: String.fromEnvironment('MAP_READ_PASSWORD_B'),
      ),
    ];
    final clients = <SupabaseClient>[];
    final zones = <String>[];
    for (final account in accounts) {
      expect(
        account.email.isNotEmpty && account.password.isNotEmpty,
        isTrue,
        reason: 'Se necesitan cuentas sintéticas preexistentes y autorizadas',
      );
      final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.key);
      clients.add(client);
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: account.email,
        password: account.password,
      );
      final profile = await client
          .from('perfiles')
          .select('zona_id,rol')
          .eq('id', client.auth.currentUser!.id)
          .single();
      expect(profile['rol'], 'vecino');
      zones.add(profile['zona_id'] as String);
    }
    expect(
      clients[0].auth.currentUser!.id == clients[1].auth.currentUser!.id,
      isFalse,
    );
    expect(
      zones[0] == zones[1],
      isFalse,
      reason: 'Usar dos zonas de prueba distintas',
    );
    final originA = await SupabaseMapOriginRepository(clients[0]).load();
    final originB = await SupabaseMapOriginRepository(clients[1]).load();
    expect(originA, isNotNull);
    expect(originB, isNotNull);
    final a = SupabaseMapPointsRepository(clients[0]);
    final b = SupabaseMapPointsRepository(clients[1]);
    final ownA = await a.load(originA!.coordinate);
    final ownB = await b.load(originB!.coordinate);
    expect(
      ownA.points,
      isNotEmpty,
      reason: 'Preparar puntos sintéticos autorizados de A antes del ensayo',
    );
    expect(
      ownB.points,
      isNotEmpty,
      reason: 'Preparar puntos sintéticos autorizados de B antes del ensayo',
    );
    final bAtA = await b.load(originA.coordinate);
    final keysA = ownA.points.map((p) => p.key).toSet();
    expect(keysA.intersection(ownB.points.map((p) => p.key).toSet()), isEmpty);
    expect(keysA.intersection(bAtA.points.map((p) => p.key).toSet()), isEmpty);
    for (final result in [ownA, ownB, bAtA]) {
      expect(
        result.points.map((p) => p.key).toSet().length,
        result.points.length,
      );
      for (final point in result.points) {
        expect(point.coordinate.latitude, inInclusiveRange(-90, 90));
        expect(point.coordinate.longitude, inInclusiveRange(-180, 180));
        expect(point.toJson().containsKey('telefono'), isFalse);
      }
    }
    // No signUp, INSERT, UPDATE, DELETE, emisión SOS, SQL or admin connection.
    // This does not certify every RLS policy, only this projection/zone scenario.
  }, skip: !const bool.fromEnvironment('ALLOW_MAP_READ_CHECK'));
}
