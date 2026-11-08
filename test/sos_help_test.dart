import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackaton_veci_pulso/features/emergency/data/sos_repository.dart';
import 'package:hackaton_veci_pulso/features/emergency/models/sos_models.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/controllers/help_board_controller.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/controllers/sos_controllers.dart';
import 'package:hackaton_veci_pulso/features/emergency/presentation/screens/sos_alert_views.dart';

import 'sos_alerts_ui_test.dart' show AlertsFake, record, id;

const b = '22222222-2222-4222-8222-222222222222';
const c = '33333333-3333-4333-8333-333333333333';
HelpResponse response(String key, String volunteer, HelpStatus status) =>
    HelpResponse.fromJson({
      'id': key,
      'alerta_id': id,
      'voluntario_id': volunteer,
      'estado': status.name,
      'mensaje': 'Puedo ayudar',
      'creado_en': '2026-01-01T00:00:00Z',
      'actualizado_en': '2026-01-01T00:00:00Z',
    });

class HelpFake extends AlertsFake {
  String viewer = b;
  bool unauthorized = false, closed = false, cut = false;
  Completer<void>? offerGate;
  int offers = 0, updates = 0;
  final rows = <HelpResponse>[];
  @override
  String? get userId => viewer;
  @override
  Future<SosAlert> detail(String key) async => closed
      ? SosAlert.fromJson({
          ...record(key).toJson(),
          'estado': 'atendida',
          'cerrado_en': '2026-01-01T00:01:00Z',
        })
      : record(key);
  @override
  Future<String?> publicName(String key) async => 'Vecino público';
  @override
  Future<List<HelpResponse>> responses(String alertId) async {
    if (unauthorized) throw SosFailure.denied;
    return List.of(rows.where((r) => viewer == id || r.voluntarioId == viewer));
  }

  @override
  Future<HelpResponse> offer({
    required String id,
    required String alertId,
    String? resourceId,
    String? message,
    SosPoint? point,
  }) async {
    offers++;
    if (offerGate != null) await offerGate!.future;
    if (closed || unauthorized || viewer == alertId) throw SosFailure.denied;
    if (rows.any(
      (r) => r.voluntarioId == viewer && r.estado != HelpStatus.cancelada,
    )) {
      throw SosFailure.duplicate;
    }
    final row = response(id, viewer, HelpStatus.ofrecida);
    rows.add(row);
    if (cut) throw SosFailure.network;
    return row;
  }

  @override
  Future<HelpResponse> updateHelp(String key, HelpStatus target) async {
    updates++;
    if (closed) throw SosFailure.conflict;
    final i = rows.indexWhere((r) => r.id == key);
    if (i < 0) throw SosFailure.missing;
    if (!helpTransitions(rows[i], record(id), viewer, rows).contains(target)) {
      throw SosFailure.conflict;
    }
    rows[i] = response(key, rows[i].voluntarioId, target);
    if (target == HelpStatus.completada) {
      closed = true;
      for (var j = 0; j < rows.length; j++) {
        if (j != i) {
          rows[j] = response(
            rows[j].id,
            rows[j].voluntarioId,
            HelpStatus.cancelada,
          );
        }
      }
    }
    if (cut) throw SosFailure.network;
    return rows[i];
  }
}

Future<void> tap(WidgetTester t, String label) async {
  final f = find.text(label).last;
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

class SwitchingNameFake extends HelpFake {
  final nameGate = Completer<String?>();
  @override
  Future<String?> publicName(String key) => nameGate.future;
}

void main() {
  test(
    'Una respuesta privada pendiente se descarta al cambiar de sesión',
    () async {
      final repo = SwitchingNameFake();
      repo.rows.add(response(b, b, HelpStatus.ofrecida));
      final board = HelpBoardController(repo, id);
      final loading = board.refresh();
      await Future<void>.delayed(Duration.zero);
      repo.viewer = c;
      repo.nameGate.complete('Vecino público');
      await loading;
      expect(board.data, isNull);
      expect(board.failure, SosFailure.session);
      expect(board.stage, SosStage.denied);
      board.dispose();
    },
  );
  testWidgets('El emisor acepta desde el detalle y ve el estado confirmado', (
    t,
  ) async {
    final repo = HelpFake()..viewer = id;
    repo.rows.add(response(b, b, HelpStatus.ofrecida));
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
    expect(find.text('Vecino público'), findsOneWidget);
    await tap(t, 'Aceptar ayuda');
    await tap(t, 'Confirmar acción');
    expect(find.text('aceptada'), findsOneWidget);
    expect(repo.updates, 1);
    expect(find.text('Aceptar ayuda'), findsNothing);
    expect(find.text('Estoy en camino'), findsNothing);
  });

  testWidgets(
    'Alerta, ofrecimiento confirmado y estado real con doble pulsación bloqueada',
    (t) async {
      final repo = HelpFake()..offerGate = Completer();
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
      expect(
        find.text('No hay ofrecimientos visibles para tu cuenta'),
        findsOneWidget,
      );
      await tap(t, 'Ofrecer ayuda');
      expect(
        find.widgetWithText(FilledButton, 'Confirmar ofrecimiento'),
        findsOneWidget,
      );
      await t.tap(find.byType(CheckboxListTile));
      await t.pumpAndSettle();
      await t.tap(find.text('Confirmar ofrecimiento'));
      await t.pump();
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar ofrecimiento'),
            )
            .onPressed,
        isNull,
      );
      repo.offerGate!.complete();
      await t.pumpAndSettle();
      expect(repo.offers, 1);
      expect(find.text('ofrecida'), findsOneWidget);
      expect(find.text('Aceptar ayuda'), findsNothing);
      expect(find.textContaining('telefono'), findsNothing);
    },
  );
  test(
    'Propietario acepta una respuesta y cancelar otra preserva la primera',
    () async {
      final repo = HelpFake()..viewer = id;
      repo.rows.addAll([
        response(b, b, HelpStatus.ofrecida),
        response(c, c, HelpStatus.ofrecida),
      ]);
      final board = HelpBoardController(repo, id);
      await board.refresh();
      await board.update(b, HelpStatus.aceptada);
      expect(board.data!.responses.first.estado, HelpStatus.aceptada);
      await board.update(c, HelpStatus.cancelada);
      expect(repo.rows.first.estado, HelpStatus.aceptada);
      expect(repo.rows.last.estado, HelpStatus.cancelada);
      await board.update(c, HelpStatus.aceptada);
      expect(board.failure, SosFailure.conflict);
      board.dispose();
    },
  );
  test('Dos aceptaciones concurrentes terminan con una sola seleccionada en el servidor simulado', () async {
    final repo = HelpFake()..viewer = id;
    repo.rows.addAll([
      response(b, b, HelpStatus.ofrecida),
      response(c, c, HelpStatus.ofrecida),
    ]);
    final first = HelpBoardController(repo, id),
        second = HelpBoardController(repo, id);
    await Future.wait([
      first.update(b, HelpStatus.aceptada),
      second.update(c, HelpStatus.aceptada),
    ]);
    expect(repo.rows.where((r) => r.estado == HelpStatus.aceptada).length, 1);
    expect(
      [
        first.failure,
        second.failure,
      ].where((e) => e == SosFailure.conflict).length,
      1,
    );
    first.dispose();
    second.dispose();
  });
  test('Cierre y autorización se propagan, sin respuestas privadas ni éxito ficticio', () async {
    final repo = HelpFake()..unauthorized = true;
    final board = HelpBoardController(repo, id);
    await board.refresh();
    expect(board.stage, SosStage.denied);
    expect(board.data, isNull);
    repo.unauthorized = false;
    repo.closed = true;
    await expectLater(board.offer(b, null), throwsA(SosFailure.denied));
    repo.rows.add(response(b, b, HelpStatus.ofrecida));
    await board.update(b, HelpStatus.aceptada);
    expect(board.failure, SosFailure.conflict);
    expect(repo.updates, 0);
    board.dispose();
  });
  test(
    'Ofrecimiento con respuesta perdida se reconcilia por UUID sin otro INSERT',
    () async {
      final repo = HelpFake()..cut = true;
      final board = HelpBoardController(repo, id);
      await expectLater(board.offer(b, 'Mensaje'), throwsA(SosFailure.network));
      expect((await board.offer(b, 'Mensaje')).id, b);
      expect(repo.offers, 1);
      board.dispose();
    },
  );
  test(
    'Actualización incierta requiere lectura y respeta estado terminal',
    () async {
      final repo = HelpFake()
        ..viewer = id
        ..cut = true;
      repo.rows.add(response(b, b, HelpStatus.ofrecida));
      final board = HelpBoardController(repo, id);
      await board.update(b, HelpStatus.aceptada);
      expect(board.uncertain, isTrue);
      expect(board.data, isNull);
      repo.cut = false;
      await board.refresh();
      expect(board.data!.responses.single.estado, HelpStatus.aceptada);
      repo.viewer = b;
      await board.update(b, HelpStatus.en_camino);
      await board.update(b, HelpStatus.completada);
      expect(board.data!.alert.estado, AlertStatus.atendida);
      expect(
        helpTransitions(repo.rows.single, board.data!.alert, b, repo.rows),
        isEmpty,
      );
      board.dispose();
    },
  );
}
