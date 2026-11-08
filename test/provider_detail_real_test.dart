import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hackaton_veci_pulso/features/services/data/services_repository.dart';
import 'package:hackaton_veci_pulso/features/services/models/service_rows.dart';
import 'package:hackaton_veci_pulso/features/services/presentation/controllers/services_controllers.dart';
import 'package:hackaton_veci_pulso/features/services/presentation/screens/provider_detail_screen.dart';

import 'support/directory_fixture.dart';

class DetailFixture extends DirectoryFixture {
  ServicesFailure? error;
  bool rich = false;
  bool approval = false;
  bool authorized = false;
  Completer<ServiceRow>? pending;
  @override
  Future<ServiceRow> detail(String id) async {
    if (error case final e?) throw e;
    return pending?.future ?? super.detail(id);
  }

  @override
  Future<PublicProvider?> provider(String id) async => rich
      ? PublicProvider.fromJson({
          'id': DirectoryFixture.id,
          'nombre_publico': 'Ana P.',
          'zona_id': DirectoryFixture.id,
          'vecino_confiable': false,
        })
      : null;
  @override
  Future<ServiceContact?> contact(String id) async => rich
      ? ServiceContact.fromJson({
          'servicio_id': id,
          'telefono': '999999999',
          'autorizado': authorized,
        })
      : null;
  @override
  Future<List<ServiceWork>> works(String id) async => rich
      ? [
          ServiceWork.fromJson({
            'id': id,
            'servicio_id': id,
            'titulo': 'Mesa restaurada',
            'creado_en': '2026-01-01T00:00:00Z',
          }),
        ]
      : [];
  @override
  RecommendationsRepository get recommendations => RichReviews(rich, approval);
}

class RichReviews extends DetailRecommendationsFixture {
  RichReviews(this.rich, [this.approval = false]);
  final bool rich;
  final bool approval;
  @override
  Future<List<ServiceReview>> reviews(String id) async => rich
      ? [
          ServiceReview.fromJson({
            'id': id,
            'autor': 'Vecino B.',
            'puntaje': 4,
            'comentario': null,
            'creado_en': '2026-01-01T00:00:00Z',
          }),
        ]
      : [];
  @override
  Future<({int count, double? average, bool approved})> statistics(
    String id,
  ) async => (
    count: approval
        ? 3
        : rich
        ? 1
        : 0,
    average: rich ? 4.0 : null,
    approved: approval,
  );
}

void main() {
  Future<void> mount(WidgetTester t, DetailFixture repository) async {
    await t.pumpWidget(
      Provider<ServicesRepository?>.value(
        value: repository,
        child: const MaterialApp(
          home: Scaffold(body: ProviderDetailScreen(id: DirectoryFixture.id)),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('El sello se muestra únicamente con estadísticas respaldadas', (
    t,
  ) async {
    await mount(
      t,
      DetailFixture()
        ..rich = true
        ..approval = true,
    );
    expect(find.text('✓ Visto Bueno Vecinal'), findsOneWidget);
    expect(find.textContaining('3 recomendaciones'), findsOneWidget);
  });
  testWidgets(
    'Ficha pública, trabajo, reseña con comentario nulo y contacto autorizado',
    (t) async {
      final repo = DetailFixture()
        ..rich = true
        ..authorized = true;
      await mount(t, repo);
      expect(find.text('Ana P.'), findsOneWidget);
      expect(find.text('Mesas'), findsOneWidget);
      expect(find.text('Zona de prueba'), findsOneWidget);
      expect(find.text('Mesa restaurada'), findsOneWidget);
      expect(find.text('Vecino B.'), findsOneWidget);
      expect(find.textContaining('4 de 5 estrellas'), findsOneWidget);
      expect(find.textContaining('1 recomendaciones'), findsOneWidget);
      expect(find.text('✓ Visto Bueno Vecinal'), findsNothing);
      expect(find.textContaining('999999999'), findsOneWidget);
      expect(find.textContaining('DNI'), findsNothing);
    },
  );
  testWidgets('Portafolio vacío y teléfono sin autorización oculto', (t) async {
    final repo = DetailFixture()..rich = true;
    await mount(t, repo);
    expect(find.textContaining('999999999'), findsNothing);
    repo.rich = false;
    await t.pumpWidget(const SizedBox());
    await mount(t, repo);
    expect(find.text('Sin trabajos publicados'), findsOneWidget);
    expect(find.text('Sin recomendaciones'), findsOneWidget);
    expect(find.text('Sin valoraciones'), findsOneWidget);
    expect(find.text('✓ Visto Bueno Vecinal'), findsNothing);
  });
  for (final error in [
    ServicesFailure.network,
    ServicesFailure.denied,
    ServicesFailure.missing,
  ]) {
    testWidgets('Error seguro y reintento de ${error.name}', (t) async {
      final repo = DetailFixture()..error = error;
      await mount(t, repo);
      expect(find.text(error.message), findsOneWidget);
      repo.error = null;
      await t.tap(find.text('Reintentar'));
      await t.pumpAndSettle();
      expect(find.text('Mesas'), findsOneWidget);
    });
  }
  test(
    'Cambio de servicio descarta respuesta antigua y dispose invalida la carga',
    () async {
      final repo = DetailFixture()..pending = Completer<ServiceRow>();
      final controller = ServiceDetailController(repo, RichReviews(false));
      final old = repo.pending!;
      final first = controller.refresh(DirectoryFixture.id);
      repo.pending = null;
      await controller.refresh(DirectoryFixture.id);
      old.completeError(ServicesFailure.network);
      await first;
      expect(controller.data?.service.id, DirectoryFixture.id);
      expect(controller.failure, isNull);
      repo.pending = Completer<ServiceRow>();
      final pending = controller.refresh(DirectoryFixture.id);
      controller.dispose();
      repo.pending!.complete(repo.row.service);
      await pending;
      expect(controller.data, isNull);
    },
  );
}
