import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hackaton_veci_pulso/app/app.dart';
import 'package:hackaton_veci_pulso/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hackaton_veci_pulso/features/auth/presentation/widgets/pin_keypad.dart';
import 'package:hackaton_veci_pulso/features/emergency/data/sos_repository.dart';
import 'package:hackaton_veci_pulso/features/emergency/models/sos_models.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/controllers/alert_emission_controller.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/screens/sos_alert_views.dart';

import 'support/auth_fixture.dart';
import 'sos_alerts_ui_test.dart' show AlertsFake, record, id;
import 'sos_catalog_test.dart' show CatalogFake;

const neighborB = '22222222-2222-4222-8222-222222222222';

class ChangingSession extends AlertsFake {
  String? viewer = id;
  @override
  String? get userId => viewer;
}

// A shared in-memory backend exercises UI composition, not real RLS.
class ScenarioRepository extends CatalogFake {
  String viewer = id;
  SosAlert? alert;
  HelpResponse? response;
  @override
  String? get userId => viewer;
  @override
  Future<List<SosAlert>> alerts({bool mine = false, int offset = 0}) async {
    if (failure case final e?) throw e;
    return alert == null || mine && alert!.autorId != viewer ? [] : [alert!];
  }

  @override
  Future<SosAlert> detail(String key) async {
    if (alert?.id != key) throw SosFailure.missing;
    return alert!;
  }

  @override
  Future<String> emit({
    required String id,
    required AlertClass kind,
    required EmergencyType type,
    required AlertUrgency urgency,
    String? description,
    SosPoint? point,
    DateTime? createdLocal,
  }) async {
    expect(point, isNull);
    alert = SosAlert.fromJson({
      ...record(id).toJson(),
      'autor_id': viewer,
      'descripcion': description,
      'tipo': type.name,
    });
    return id;
  }

  @override
  Future<List<HelpResponse>> responses(String alertId) async =>
      response == null ||
          viewer != alert!.autorId && viewer != response!.voluntarioId
      ? []
      : [response!];
  @override
  Future<String?> publicName(String key) async => 'Vecino sintético';
  @override
  Future<HelpResponse> offer({
    required String id,
    required String alertId,
    String? resourceId,
    String? message,
    SosPoint? point,
  }) async {
    response = HelpResponse.fromJson({
      'id': id,
      'alerta_id': alertId,
      'voluntario_id': viewer,
      'estado': 'ofrecida',
      'mensaje': message,
      'creado_en': '2026-01-01T00:00:00Z',
      'actualizado_en': '2026-01-01T00:00:00Z',
    });
    return response!;
  }

  @override
  Future<HelpResponse> updateHelp(String key, HelpStatus status) async {
    response = HelpResponse.fromJson({
      ...response!.toJson(),
      'estado': status.name,
    });
    return response!;
  }
}

void main() {
  test('Una emisión no se confirma ni se reenvía bajo otra sesión', () async {
    final repo = ChangingSession()..gate = Completer<void>();
    final controller = AlertEmissionController(repo, id);
    final pending = controller.send(
      kind: AlertClass.alerta,
      type: EmergencyType.sismo,
      urgency: AlertUrgency.urgente,
    );
    repo.viewer = neighborB;
    repo.gate!.complete();
    await pending;
    expect(controller.failure, SosFailure.session);
    expect(controller.data, isNull);
    await controller.send(
      kind: AlertClass.alerta,
      type: EmergencyType.sismo,
      urgency: AlertUrgency.urgente,
    );
    expect(repo.writes, 1);
    controller.dispose();
  });

  testWidgets(
    'PIN A/B → emisión → ofrecimiento → aceptación → catálogos → recuperación',
    (t) async {
      final repo = ScenarioRepository();
      AuthController? current;
      Future<void> tap(String text) async {
        final item = find.text(text).last;
        await t.ensureVisible(item);
        await t.tap(item);
        await t.pumpAndSettle();
      }

      Future<GoRouter> login(String viewer) async {
        await t.pumpWidget(const SizedBox());
        current?.dispose();
        repo.viewer = viewer;
        final authRepo = FakeAuthRepository()
          ..userId = viewer
          ..hasProfile = true;
        final auth = AuthController(authRepo);
        current = auth;
        await auth.restore();
        await t.pumpWidget(
          Provider<SosRepository?>.value(
            value: repo,
            child: VeciPulsoApp(auth: auth),
          ),
        );
        await t.pumpAndSettle();
        final router = GoRouter.of(t.element(find.text('Iniciar sesión')));
        router.go('/sos/tablero');
        await t.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/auth/login');
        for (final digit in '012345'.split('')) {
          final key = find.descendant(
            of: find.byType(PinKeypad),
            matching: find.text(digit),
          );
          await t.ensureVisible(key);
          await t.tap(key);
          await t.pump();
        }
        await tap('Continuar');
        expect(auth.stage, AuthStage.unlocked);
        router.go('/sos/tablero');
        await t.pumpAndSettle();
        return router;
      }

      await login(id);
      expect(find.text(sosNotice), findsOneWidget);
      await tap('Emitir alerta');
      await t.tap(find.byType(DropdownButtonFormField<EmergencyType>));
      await t.pumpAndSettle();
      await tap('sismo');
      await t.ensureVisible(find.byType(CheckboxListTile));
      await t.tap(find.byType(CheckboxListTile));
      await t.pumpAndSettle();
      await tap('Registrar alerta');
      expect(find.text('Alerta registrada por el servidor'), findsOneWidget);
      await tap('Cerrar');
      await login(neighborB);
      await tap('sismo');
      await tap('Ofrecer ayuda');
      await t.ensureVisible(find.byType(CheckboxListTile));
      await t.tap(find.byType(CheckboxListTile));
      await t.pumpAndSettle();
      await tap('Confirmar ofrecimiento');
      expect(repo.response!.voluntarioId, neighborB);
      await tap('Cerrar');
      await login(id);
      await tap('Mis alertas');
      await tap('sismo');
      await tap('Aceptar ayuda');
      await tap('Confirmar acción');
      expect(repo.response!.estado, HelpStatus.aceptada);
      await tap('Cerrar');
      final router = await login(neighborB);
      await tap('sismo');
      expect(find.text('aceptada'), findsOneWidget);
      await tap('Cerrar');
      await tap('Recursos críticos');
      await tap('agua');
      expect(find.text('Reserva publicada'), findsOneWidget);
      await tap('Cerrar');
      await t.tap(find.byType(BackButton).last);
      await t.pumpAndSettle();
      await tap('Grupos y Brigadas');
      await tap('Grupo público');
      expect(find.text('Contacto no publicado'), findsOneWidget);
      await tap('Cerrar');
      await t.tap(find.byType(BackButton).first);
      await t.pumpAndSettle();
      repo.failure = SosFailure.network;
      await tap('Actualizar alertas');
      expect(find.text(SosFailure.network.message), findsOneWidget);
      repo.failure = null;
      await tap('Actualizar alertas');
      expect(find.text('sismo'), findsOneWidget);
      router.go('/sos/acciones');
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/sos/tablero');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      current?.dispose();
    },
  );
}
