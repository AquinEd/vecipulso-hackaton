import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hackaton_veci_pulso/core/config/supabase_config.dart';
import 'package:hackaton_veci_pulso/features/emergency/data/sos_repository.dart';
import 'package:hackaton_veci_pulso/features/emergency/models/sos_models.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/screens/sos_alert_views.dart';

// Run only against a dedicated project without real neighbors or notifications.
// Credentials belong to pre-provisioned synthetic Auth users with profiles.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'SOS real: emisor, colaborador y tercero independiente bajo RLS',
    () async {
      expect(SupabaseConfig.problem, isNull);
      expect(
        const String.fromEnvironment('SOS_TEST_PROJECT_URL'),
        SupabaseConfig.url,
      );
      expect(
        const String.fromEnvironment('SOS_TEST_ENVIRONMENT'),
        'isolated-synthetic',
      );
      const credentials = [
        (
          email: String.fromEnvironment('SOS_TEST_EMAIL_A'),
          password: String.fromEnvironment('SOS_TEST_PASSWORD_A'),
        ),
        (
          email: String.fromEnvironment('SOS_TEST_EMAIL_B'),
          password: String.fromEnvironment('SOS_TEST_PASSWORD_B'),
        ),
        (
          email: String.fromEnvironment('SOS_TEST_EMAIL_C'),
          password: String.fromEnvironment('SOS_TEST_PASSWORD_C'),
        ),
      ];
      final clients = <SupabaseClient>[];
      final repos = <SupabaseSosRepository>[];
      final zones = <String>[];
      for (final credential in credentials) {
        expect(
          credential.email.isNotEmpty && credential.password.isNotEmpty,
          isTrue,
          reason: 'Faltan credenciales de las cuentas sintéticas A/B/C',
        );
        final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.key);
        clients.add(client);
        addTearDown(client.dispose);
        await client.auth.signInWithPassword(
          email: credential.email,
          password: credential.password,
        );
        final uid = client.auth.currentUser!.id;
        final profile = await client
            .from('perfiles')
            .select('zona_id,rol')
            .eq('id', uid)
            .single();
        expect(profile['rol'], 'vecino');
        zones.add(profile['zona_id'] as String);
        repos.add(SupabaseSosRepository(client));
      }
      expect(repos.map((r) => r.userId).toSet().length, 3);
      expect(
        zones.toSet().length,
        1,
        reason: 'A/B/C deben pertenecer a la misma zona sintética',
      );
      final a = repos[0], b = repos[1], c = repos[2];
      final alertId = newAlertId(),
          responseB = newAlertId(),
          responseC = newAlertId();
      var emitted = false;
      addTearDown(() async {
        if (!emitted) return;
        // Cancel this scenario's alert only. Never delete unrelated rows.
        final row = await a.detail(alertId);
        if ([
          AlertStatus.sin_verificar,
          AlertStatus.verificada,
        ].contains(row.estado)) {
          await a.cancel(alertId);
        }
      });
      expect(
        await a.emit(
          id: alertId,
          kind: AlertClass.alerta,
          type: EmergencyType.otro,
          urgency: AlertUrgency.normal,
          description: 'PRUEBA SINTÉTICA AISLADA — no es una emergencia',
        ),
        alertId,
      );
      emitted = true;
      expect((await b.detail(alertId)).autorId, a.userId);
      expect(
        await a.emit(
          id: alertId,
          kind: AlertClass.alerta,
          type: EmergencyType.otro,
          urgency: AlertUrgency.normal,
        ),
        alertId,
      );
      await b.offer(
        id: responseB,
        alertId: alertId,
        message: 'Ofrecimiento sintético B',
      );
      expect((await a.responses(alertId)).single.id, responseB);
      expect(await c.responses(alertId), isEmpty);
      await expectLater(b.cancel(alertId), throwsA(isA<SosFailure>()));
      await expectLater(
        clients[1]
            .from('alertas_sos')
            .update({'estado': 'cancelada'})
            .eq('id', alertId),
        throwsA(isA<PostgrestException>()),
      );
      expect((await a.detail(alertId)).cerradoEn, isNull);
      await expectLater(
        c.updateHelp(responseB, HelpStatus.aceptada),
        throwsA(isA<SosFailure>()),
      );
      await c.offer(
        id: responseC,
        alertId: alertId,
        message: 'Ofrecimiento sintético C',
      );
      final results = await Future.wait([
        for (final id in [responseB, responseC])
          a
              .updateHelp(id, HelpStatus.aceptada)
              .then<bool>(
                (_) => true,
                onError: (Object e) {
                  if (e != SosFailure.conflict && e != SosFailure.duplicate) {
                    throw e;
                  }
                  return false;
                },
              ),
      ]);
      expect(results.where((x) => x).length, 1);
      final rows = await a.responses(alertId);
      final selected = rows.singleWhere((r) => r.estado == HelpStatus.aceptada);
      final other = rows.singleWhere((r) => r.id != selected.id);
      final selectedRepo = selected.voluntarioId == b.userId ? b : c;
      final otherRepo = other.voluntarioId == b.userId ? b : c;
      await otherRepo.updateHelp(other.id, HelpStatus.cancelada);
      expect(
        (await a.responses(alertId))
            .singleWhere((r) => r.id == selected.id)
            .estado,
        HelpStatus.aceptada,
      );
      expect(
        (await selectedRepo.responses(alertId)).single.estado,
        HelpStatus.aceptada,
      );
      await selectedRepo.updateHelp(selected.id, HelpStatus.en_camino);
      await a.updateHelp(selected.id, HelpStatus.completada);
      for (final repo in [a, b, c]) {
        expect((await repo.detail(alertId)).estado, AlertStatus.atendida);
      }
      expect(
        (await a.responses(alertId))
            .singleWhere((r) => r.id == other.id)
            .estado,
        HelpStatus.cancelada,
      );
      await expectLater(
        b.offer(id: newAlertId(), alertId: alertId),
        throwsA(isA<SosFailure>()),
      );
      // Cross-zone and the known cerrar_alerta vulnerability are manual checks
      // documented in FASE_5_6_CIERRE_SOS.md; this test does not claim to cover them.
    },
    skip: !const bool.fromEnvironment('ALLOW_SOS_TEST_WRITES'),
  );
}
