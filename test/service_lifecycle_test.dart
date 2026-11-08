import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hackaton_veci_pulso/features/services/data/services_repository.dart';
import 'package:hackaton_veci_pulso/features/services/models/service_rows.dart';
import 'package:hackaton_veci_pulso/features/services/presentation/widgets/service_operations.dart';

import 'support/directory_fixture.dart';
import 'support/auth_fixture.dart';

class Inbox implements RequestsRepository {
  RequestStatus? status;
  bool reviewed = false, fail = false;
  String requestId = '';
  final gate = Completer<void>();
  Map<String, dynamic> get fields => {
    'id': requestId,
    'servicio_id': DirectoryFixture.id,
    'servicio': 'Mesas',
    'estado': status!.name,
    'creado_en': '2026-01-01T00:00:00Z',
  };
  @override
  Future<ServiceRequest> create(
    String id,
    String serviceId, {
    String? message,
  }) async {
    await gate.future;
    requestId = id;
    status = RequestStatus.solicitada;
    return ServiceRequest.fromJson({
      ...fields,
      'solicitante_id': DirectoryFixture.id,
    });
  }

  @override
  Future<List<SentRequest>> sent() async => status == null
      ? []
      : [
          SentRequest.fromJson({
            ...fields,
            'proveedor': 'Prueba A',
            'puedo_recomendar': status == RequestStatus.completada && !reviewed,
          }),
        ];
  @override
  Future<List<ReceivedRequest>> received() async => status == null
      ? []
      : [
          ReceivedRequest.fromJson({...fields, 'solicitante': 'Prueba B'}),
        ];
  @override
  Future<ServiceRequest> transition(String id, RequestStatus next) async {
    if (fail) throw ServicesFailure.denied;
    status = next;
    return ServiceRequest.fromJson({
      ...fields,
      'solicitante_id': DirectoryFixture.id,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Reviews extends DetailRecommendationsFixture {
  Reviews(this.inbox);
  final Inbox inbox;
  @override
  Future<String> recommend(
    String id,
    String serviceId,
    int stars, {
    String? comment,
  }) async {
    if (inbox.reviewed) throw ServicesFailure.duplicate;
    if (inbox.status != RequestStatus.completada) throw ServicesFailure.denied;
    expect(stars, 4);
    inbox.reviewed = true;
    return id;
  }

  @override
  Future<({int count, double? average, bool approved})> statistics(
    String id,
  ) async => (
    count: inbox.reviewed ? 1 : 0,
    average: inbox.reviewed ? 4.0 : null,
    approved: false,
  );
}

class FlowRepo extends DirectoryFixture {
  @override
  final Inbox requests = Inbox();
  @override
  RecommendationsRepository get recommendations => Reviews(requests);
  String? published;
  bool failPublish = true;
  @override
  Future<ServiceRow> publish({
    required String id,
    required int categoryId,
    required String title,
    String? description,
    int? years,
  }) async {
    if (failPublish) throw ServicesFailure.network;
    expect(categoryId, 1);
    published = title;
    return row.service;
  }

  @override
  Future<List<ServiceRow>> mine() async =>
      published == null ? [] : [row.service];
}

void main() {
  test('Transiciones permitidas por actor y estados terminales', () {
    for (final status in RequestStatus.values) {
      final live = [
        RequestStatus.solicitada,
        RequestStatus.contactado,
      ].contains(status);
      expect(
        transitions(status, provider: false),
        live ? [RequestStatus.cancelada] : [],
      );
      expect(transitions(status, provider: true), [
        if (status == RequestStatus.solicitada) RequestStatus.contactado,
        if (live) ...[RequestStatus.completada, RequestStatus.cancelada],
      ]);
    }
  });
  Future<void> tap(WidgetTester t, String label) async {
    final f = find.text(label).last;
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> mount(WidgetTester t, FlowRepo repo, String path) async {
    final router = signedInRouter()..go(path);
    addTearDown(router.dispose);
    await t.pumpWidget(
      Provider<ServicesRepository?>.value(
        value: repo,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('Directorio, solicitud, ambas bandejas y valoración confirmada', (
    t,
  ) async {
    final repo = FlowRepo();
    await mount(t, repo, '/servicios');
    await tap(t, 'Mesas');
    await tap(t, 'Solicitar servicio');
    await t.tap(find.text('Enviar solicitud'));
    await t.pump();
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Enviar solicitud'),
          )
          .onPressed,
      isNull,
    );
    repo.requests.gate.complete();
    await t.pumpAndSettle();
    expect(find.textContaining('solicitada'), findsOneWidget);
    expect(find.text('Recomendar'), findsNothing);
    await tap(t, 'Recibidas');
    await tap(t, 'Completar');
    repo.requests.fail = true;
    await tap(t, 'Confirmar');
    expect(find.text(ServicesFailure.denied.message), findsOneWidget);
    repo.requests.fail = false;
    await tap(t, 'Confirmar');
    await tap(t, 'Enviadas');
    await tap(t, 'Recomendar');
    final commentField = find.descendant(
      of: find.byType(AlertDialog).last,
      matching: find.byType(TextFormField),
    );
    await t.enterText(commentField, 'á' * 301);
    expect(
      t
          .widget<TextField>(
            find.descendant(of: commentField, matching: find.byType(TextField)),
          )
          .controller!
          .text
          .characters
          .length,
      300,
    );
    await tap(t, 'Enviar recomendación');
    expect(find.text('Selecciona de 1 a 5 estrellas'), findsOneWidget);
    await t.ensureVisible(find.byTooltip('4 estrellas'));
    await t.tap(find.byTooltip('4 estrellas'));
    await t.pumpAndSettle();
    await tap(t, 'Enviar recomendación');
    expect(repo.requests.reviewed, isTrue);
    expect(find.text('Recomendar'), findsNothing);
    await tap(t, 'Cerrar');
    expect(find.textContaining('★ 4.0'), findsOneWidget);
  });
  testWidgets('Publicar exige categoría y nombre y permite reintentar', (
    t,
  ) async {
    final repo = FlowRepo();
    await mount(t, repo, '/servicios');
    await tap(t, 'Mis servicios');
    expect(find.text('Aún no publicaste servicios'), findsOneWidget);
    await tap(t, 'Cerrar');
    await tap(t, 'Ofrecer un servicio');
    await tap(t, 'Guardar');
    expect(find.text('Selecciona una categoría disponible'), findsOneWidget);
    expect(find.text('Escribe al menos 3 caracteres'), findsOneWidget);
    await t.enterText(find.byType(TextFormField).first, 'Mesas');
    await t.tap(find.byType(DropdownButtonFormField<int>));
    await t.pumpAndSettle();
    await tap(t, 'Carpintería');
    await tap(t, 'Guardar');
    expect(repo.published, isNull);
    expect(find.text(ServicesFailure.network.message), findsOneWidget);
    repo.failPublish = false;
    await tap(t, 'Guardar');
    expect(repo.published, 'Mesas');
    expect(find.text('Editar'), findsOneWidget);
  });
}
