import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackaton_veci_pulso/app/app_router.dart';
import 'package:hackaton_veci_pulso/features/services/data/demo_services.dart';
import 'package:hackaton_veci_pulso/features/services/models/service_preview.dart';
import 'package:hackaton_veci_pulso/features/services/utils/provider_display_name.dart';

void main() {
  test('El nombre público cuenta grafemas y omite segundos nombres', () {
    for (final (surname, expected) in [
      ('López', 'Lópe'),
      ('Díaz', 'Dí'),
      ('Ñau', 'Ñ'),
      ('Li', 'L'),
      ('O', 'O'),
      ('Lo\u0301pez', 'Lo\u0301pe'),
    ]) {
      expect(
        formatProviderDisplayName(' Ana María ', surname),
        'Ana $expected',
      );
    }
  });

  testWidgets('Cada perfil distingue al vecino de su servicio', (t) async {
    final router = createRouter();
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    for (final (id, person, service, occupation) in [
      (
        'demo-carpinteria',
        'José Ramí',
        'Carpintería Vecinal',
        'Carpintero del barrio',
      ),
      ('demo-matematicas', 'Ana Lópe', 'Clases con Ana', 'Clases particulares'),
      (
        'demo-electricidad',
        'María Fern',
        'Electricista Rápido',
        'Electricidad',
      ),
      ('demo-gasfiteria', 'Carlos Lu', 'Gasfitería del Barrio', 'Gasfitería'),
      ('demo-cerrajeria', 'Pedro Roja', 'Cerrajería Cerca', 'Cerrajería'),
    ]) {
      router.go('/servicios/$id');
      await t.pumpAndSettle();
      expect(find.text(person), findsOneWidget);
      expect(find.text('Servicio: $service'), findsOneWidget);
      expect(find.text(occupation), findsOneWidget);
      expect(find.text(service), findsNothing);
      expect(
        find.textContaining(
          demoServices.singleWhere((s) => s.id == id).providerPaternalSurname,
        ),
        findsNothing,
      );
    }
  });

  test('La búsqueda combina nombre, proveedor, oficio y descripción con límites inclusivos', () {
    for (final query in [
      'JOSE',
      'carpinteria',
      'carpintero',
      'restauracion',
      'Carpintería Vecinal',
    ]) {
      expect(demoServices.where((s) => s.matches(query)), [carpentry]);
    }
    expect(demoServices.where((s) => s.matches('GASFITERIA')), [plumbing]);
    expect(
      demoServices.where((s) => s.matches('', maxMeters: 500)),
      demoServices.take(4),
    );
    expect(
      demoServices.where((s) => s.matches('', maxMeters: 1000)),
      demoServices,
    );
    ServicePreview sample(double rating, int meters) => ServicePreview(
      id: 'sample',
      serviceName: 'Demo',
      providerFirstName: 'Luis',
      providerPaternalSurname: 'Díaz',
      description: '',
      category: ServiceCategory.education,
      rating: rating,
      distanceMeters: meters,
    );
    expect(sample(3.9, 400).matches('demo', fourStars: true), isFalse);
    expect(
      sample(4, 1000).matches('demo', maxMeters: 1000, fourStars: true),
      isTrue,
    );
    expect(
      sample(4, 1001).matches('demo', maxMeters: 1000, fourStars: true),
      isFalse,
    );
  });

  testWidgets('El directorio conserva búsqueda y filtros entre perfiles', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(430, 1000);
    addTearDown(t.view.reset);
    final router = createRouter();
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/servicios');
    await t.pumpAndSettle();
    Future<void> tap(String label) async {
      if (find.text(label).evaluate().isEmpty) {
        await t.scrollUntilVisible(
          find.text(label),
          150,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await Scrollable.ensureVisible(
        t.element(find.text(label)),
        alignment: 0.5,
      );
      await t.pumpAndSettle();
      await t.tap(find.text(label));
      await t.pumpAndSettle();
    }

    await tap('Hasta 500 m');
    await tap('4+ estrellas');
    await t.enterText(find.byType(TextField), 'cerrajeria');
    await t.pumpAndSettle();
    expect(find.textContaining('No se encontraron'), findsOneWidget);
    await tap('1 km');
    await tap('Cerrajería Cerca');
    expect(find.text('Cerrajería'), findsOneWidget);
    expect(find.text('★ 4.8'), findsOneWidget);
    expect(find.textContaining('Sin reseñas'), findsOneWidget);
    expect(find.textContaining('98 reseñas'), findsNothing);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'cerrajeria',
    );
    expect(t.widget<FilterChip>(find.byType(FilterChip)).selected, isTrue);
    expect(
      t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '1 km')).selected,
      isTrue,
    );
    await t.tap(find.byTooltip('Borrar búsqueda'));
    await t.pumpAndSettle();
    await tap('Todos');
    await tap('José Ramí');
    expect(find.textContaining('98 reseñas'), findsOneWidget);
    expect(find.text('Puertas y marcos'), findsOneWidget);
    expect(find.text('Carolina R.'), findsOneWidget);
    await tap('Llamar');
    expect(
      find.text(
        'El contacto telefónico estará disponible cuando se registren proveedores reales',
      ),
      findsOneWidget,
    );
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    await tap('Solicitar servicio');
    expect(
      find.text(
        'La solicitud de servicios estará disponible cuando se conecte el sistema',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'El Drawer devuelve a la pestaña de origen y las cinco pestañas abren',
    (t) async {
      final router = createRouter();
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      for (final tab in [
        'Mapa',
        'Publicar',
        'Mensajes',
        'Perfil',
        'Inicio',
        'Mapa',
      ]) {
        await t.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(tab),
          ),
        );
        await t.pumpAndSettle();
      }
      await t.tap(find.byTooltip('Abrir menú'));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Servicios del Barrio'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Servicios de Proximidad'), findsOneWidget);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(router.state.uri.path, '/mapa');
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('Ruta directa, teclado y texto grande en 320 px', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(320, 720);
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final router = createRouter();
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/servicios/inexistente');
    await t.pumpAndSettle();
    expect(find.text('Proveedor no encontrado'), findsOneWidget);
    await t.tap(find.text('Volver al directorio'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'jose');
    t.view.viewInsets = const FakeViewPadding(bottom: 240);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('José Ramí'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      t.element(find.text('José Ramí')),
      alignment: 0.5,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('José Ramí'));
    t.view.viewInsets = const FakeViewPadding();
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Solicitar servicio'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
