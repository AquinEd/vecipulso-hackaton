import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hackaton_veci_pulso/features/emergency/data/sos_repository.dart';
import 'package:hackaton_veci_pulso/features/emergency/models/sos_models.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/controllers/alert_emission_controller.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/screens/sos_alert_views.dart';

import 'support/auth_fixture.dart';

const id = '11111111-1111-4111-8111-111111111111';
SosAlert record(String id) => SosAlert.fromJson({
  'id': id,
  'autor_id': id,
  'zona_id': id,
  'clase': 'alerta',
  'tipo': 'sismo',
  'urgencia': 'urgente',
  'descripcion': 'Reporte sintético',
  'estado': 'sin_verificar',
  'ubicacion_aprox': 'POINT(-77 -12)',
  'creado_en': '2026-01-01T00:00:00Z',
});

class AlertsFake implements SosRepository {
  @override
  Future<List<HelpResponse>> responses(String alertId) async => [];
  @override
  Future<String?> publicName(String id) async => null;
  @override
  String? get userId => id;
  SosAlert? saved;
  SosFailure? failure;
  bool lost = false;
  int writes = 0, checks = 0;
  Completer<void>? gate;
  @override
  Future<List<SosAlert>> alerts({bool mine = false, int offset = 0}) async {
    if (failure case final e?) throw e;
    return saved == null ? [] : [saved!];
  }

  @override
  Future<SosAlert> detail(String key) async {
    checks++;
    if (failure case final e?) throw e;
    return saved ?? (throw SosFailure.missing);
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
    writes++;
    expect(point, isNull);
    if (gate != null) await gate!.future;
    saved = record(id);
    if (lost) throw SosFailure.network;
    return id;
  }

  @override
  Future<SosAlert> cancel(String key) async {
    saved = SosAlert.fromJson({
      ...saved!.toJson(),
      'estado': 'cancelada',
      'cerrado_en': '2026-01-01T00:01:00Z',
    });
    return saved!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Un UUID ausente tras el corte permite un reintento explícito con el mismo ID', () async {
    final repo = AlertsFake()..lost = true;
    final c = AlertEmissionController(repo, id);
    await c.send(
      kind: AlertClass.alerta,
      type: EmergencyType.sismo,
      urgency: AlertUrgency.urgente,
    );
    repo.saved = null;
    repo.lost = false;
    await c.send(
      kind: AlertClass.alerta,
      type: EmergencyType.sismo,
      urgency: AlertUrgency.urgente,
    );
    expect(c.data, id);
    expect(repo.checks, 1);
    expect(repo.writes, 2);
    c.dispose();
  });
  testWidgets(
    'Cambiar clase descarta un tipo incompatible y mantiene el formulario sin emitir',
    (t) async {
      final repo = AlertsFake();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AlertEmissionForm(repository: repo)),
        ),
      );
      await t.tap(find.byType(DropdownButtonFormField<EmergencyType>));
      await t.pumpAndSettle();
      await t.tap(find.text('sismo').last);
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<AlertClass>));
      await t.pumpAndSettle();
      await t.tap(find.text('soporte').last);
      await t.pumpAndSettle();
      expect(
        t
            .widget<DropdownButtonFormField<EmergencyType>>(
              find.byType(DropdownButtonFormField<EmergencyType>),
            )
            .initialValue,
        isNull,
      );
      await t.ensureVisible(find.text('Registrar alerta'));
      await t.tap(find.text('Registrar alerta'));
      await t.pumpAndSettle();
      expect(find.text('Selecciona un tipo válido'), findsOneWidget);
      expect(repo.writes, 0);
    },
  );
  Future<void> tap(WidgetTester t, String text) async {
    final f = find.text(text).last;
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  test(
    'Respuesta incierta se reconcilia por UUID sin repetir escritura',
    () async {
      final repo = AlertsFake()..lost = true;
      final c = AlertEmissionController(repo, id);
      await c.send(
        kind: AlertClass.alerta,
        type: EmergencyType.sismo,
        urgency: AlertUrgency.urgente,
      );
      expect(c.data, isNull);
      expect(c.uncertain, isTrue);
      await c.send(
        kind: AlertClass.alerta,
        type: EmergencyType.sismo,
        urgency: AlertUrgency.urgente,
      );
      expect(c.data, id);
      expect(repo.writes, 1);
      expect(repo.checks, 1);
      c.dispose();
    },
  );
  test('Reconsulta fallida no emite una segunda alerta', () async {
    final repo = AlertsFake()..lost = true;
    final c = AlertEmissionController(repo, id);
    await c.send(
      kind: AlertClass.alerta,
      type: EmergencyType.sismo,
      urgency: AlertUrgency.urgente,
    );
    repo.failure = SosFailure.denied;
    await c.send(
      kind: AlertClass.alerta,
      type: EmergencyType.sismo,
      urgency: AlertUrgency.urgente,
    );
    expect(c.data, isNull);
    expect(repo.writes, 1);
    c.dispose();
  });
  testWidgets(
    'Formulario exige tipo y confirmación, usa zona y bloquea doble envío',
    (t) async {
      final repo = AlertsFake()..gate = Completer();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertEmissionForm(repository: repo),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tap(t, 'Abrir');
      await tap(t, 'Registrar alerta');
      expect(find.text('Selecciona un tipo válido'), findsOneWidget);
      expect(repo.writes, 0);
      await t.tap(find.byType(DropdownButtonFormField<EmergencyType>));
      await t.pumpAndSettle();
      await tap(t, 'sismo');
      await t.ensureVisible(find.byType(CheckboxListTile));
      await t.tap(find.byType(CheckboxListTile));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Registrar alerta'));
      await t.tap(find.text('Registrar alerta'));
      await t.pump();
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Registrar alerta'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Alerta registrada por el servidor'), findsNothing);
      repo.gate!.complete();
      await t.pumpAndSettle();
      expect(repo.writes, 1);
      expect(find.text('Alerta registrada por el servidor'), findsOneWidget);
    },
  );
  testWidgets('Tablero vacío, error, reintento, detalle y cancelación propia', (
    t,
  ) async {
    final repo = AlertsFake();
    final router = signedInRouter()..go('/sos/tablero');
    addTearDown(router.dispose);
    await t.pumpWidget(
      Provider<SosRepository?>.value(
        value: repo,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('No hay alertas disponibles'), findsOneWidget);
    repo.failure = SosFailure.network;
    await tap(t, 'Actualizar alertas');
    expect(find.text(SosFailure.network.message), findsOneWidget);
    repo.failure = null;
    repo.saved = record(id);
    await tap(t, 'Actualizar alertas');
    await tap(t, 'Mis alertas');
    await tap(t, 'sismo');
    expect(find.text('Reporte sintético'), findsOneWidget);
    await tap(t, 'Cancelar mi alerta');
    await tap(t, 'Confirmar cancelación');
    expect(find.text('cancelada'), findsOneWidget);
    await tap(t, 'Cerrar');
    expect(find.text('Mis alertas'), findsOneWidget);
  });
  for (final error in [SosFailure.denied, SosFailure.missing]) {
    testWidgets('Detalle presenta ${error.name} y permite reintentar', (
      t,
    ) async {
      final repo = AlertsFake()..failure = error;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSosDetail(context, repo, id),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tap(t, 'Abrir');
      expect(find.text(error.message), findsOneWidget);
      repo.failure = null;
      repo.saved = record(id);
      await tap(t, 'Actualizar');
      expect(find.text('Reporte sintético'), findsOneWidget);
    });
  }
}
