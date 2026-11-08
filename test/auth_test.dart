import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/core/errors/auth_failure.dart';
import 'package:hackaton_veci_pulso/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hackaton_veci_pulso/features/auth/models/auth_models.dart';

import 'support/auth_fixture.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackaton_veci_pulso/app/app.dart';
import 'package:hackaton_veci_pulso/features/auth/utils/auth_validators.dart';
import 'package:hackaton_veci_pulso/features/auth/presentation/widgets/pin_keypad.dart';
import 'package:hackaton_veci_pulso/features/auth/presentation/widgets/pin_dots_indicator.dart';

Future<void> tapLabel(WidgetTester tester, String text) async {
  final item = find.text(text);
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}

Future<void> digits(WidgetTester tester, String value) async {
  for (final digit in value.split('')) {
    final key = find.descendant(
      of: find.byType(PinKeypad),
      matching: find.text(digit),
    );
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pump();
  }
}

void main() {
  testWidgets('La configuración pendiente protege SOS y permite el tutorial', (
    tester,
  ) async {
    final auth = AuthController.unavailable('Configura SUPABASE_URL');
    await tester.pumpWidget(VeciPulsoApp(auth: auth));
    await tester.pumpAndSettle();
    final router = GoRouter.of(
      tester.element(find.text('Configuración pendiente')),
    );
    router.go('/sos/tablero');
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/auth/estado');
    await tapLabel(tester, 'Tutorial de uso');
    expect(router.routerDelegate.currentConfiguration.uri.path, '/tutorial');
  });
  test(
    'Doble confirmación ejecuta una RPC y la sesión restaurada exige PIN',
    () async {
      final repo = FakeAuthRepository();
      final auth = AuthController(repo);
      await auth.restore();
      auth.prepare((
        dni: '01234567',
        name: 'María Peña',
        zone: auth.zones.single.id,
        consent: true,
      ));
      await Future.wait([auth.register('012345'), auth.register('012345')]);
      expect(repo.registrations, 1);
      expect(auth.stage, AuthStage.unlocked);
      await auth.restore();
      expect(auth.stage, AuthStage.locked);
      auth.dispose();
    },
  );
  test('DNI de ocho dígitos y normalización del nombre', () {
    expect(AuthValidators.dni('01234567'), isNull);
    for (final value in ['123', '1234567a', '123456789']) {
      expect(AuthValidators.dni(value), isNotNull);
    }
    for (final value in ['', '  ']) {
      expect(AuthValidators.name(value), isNotNull);
    }
    expect(AuthValidators.name('María Peña'), isNull);
    expect(AuthValidators.normalizeName(' María   Peña '), 'María Peña');
  });
  testWidgets('Registro permite corregir datos, volver y confirmar el PIN', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    final auth = AuthController(repo);
    await auth.restore();
    await tester.pumpWidget(VeciPulsoApp(auth: auth));
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Continuar');
    expect(find.text('Ingresa tu nombre completo.'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'a123456789');
    await tester.enterText(fields.last, '  María   Peña ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Zona norte');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Continuar');
    expect(find.text('Crea tu PIN'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('María Peña'), findsOneWidget);
    expect(find.text('12345678'), findsOneWidget);
    await tapLabel(tester, 'Continuar');
    await digits(tester, '0234567');
    expect(
      tester.widget<PinDotsIndicator>(find.byType(PinDotsIndicator)).count,
      6,
    );
    expect(find.textContaining('023456'), findsNothing);
    final erase = find.byTooltip('Borrar último dígito');
    await tester.ensureVisible(erase);
    await tester.tap(erase);
    await tester.pump();
    expect(
      tester.widget<PinDotsIndicator>(find.byType(PinDotsIndicator)).count,
      5,
    );
    await digits(tester, '6');
    await tapLabel(tester, 'Continuar');
    await digits(tester, '000000');
    await tapLabel(tester, 'Confirmar PIN');
    expect(find.textContaining('Los PIN no coinciden'), findsOneWidget);
    await digits(tester, '023456');
    await tapLabel(tester, 'Confirmar PIN');
    expect(repo.received, (
      dni: '12345678',
      name: 'María Peña',
      zone: '11111111-1111-4111-8111-111111111111',
      consent: true,
    ));
    expect(auth.draft, isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
  test('PIN de seis dígitos', () {
    expect(AuthValidators.pin('012345'), isNull);
    expect(AuthValidators.weakPin('123456'), isTrue);
    expect(AuthValidators.name('A'), isNotNull);
    for (final invalid in ['12345', '0234567', '12x456']) {
      expect(AuthValidators.pin(invalid), isNotNull);
    }
    expect(() => PinResult.parse({'ok': 'true'}), throwsFormatException);
  });
  testWidgets(
    'La ruta protegida permanece cerrada ante DNI duplicado y fallo de conexión',
    (tester) async {
      final repo = FakeAuthRepository();
      final auth = AuthController(repo);
      await auth.restore();
      expect(repo.userId, isNull);
      await tester.pumpWidget(VeciPulsoApp(auth: auth));
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(Form)));
      router.go('/mensajes');
      await tester.pumpAndSettle();
      expect(find.text('Crea tu cuenta'), findsOneWidget);
      auth.prepare((
        dni: '01234567',
        name: 'María Peña',
        zone: '11111111-1111-4111-8111-111111111111',
        consent: true,
      ));
      router.go('/auth/pin');
      await tester.pumpAndSettle();
      repo.failure = AuthFailure.duplicate;
      await auth.register('023456');
      await tester.pumpAndSettle();
      expect(find.text(AuthFailure.duplicate.message), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      repo.failure = TimeoutException('test');
      await auth.register('023456');
      await tester.pumpAndSettle();
      expect(find.text(AuthFailure.network.message), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      router.go('/tutorial');
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/tutorial');
    },
  );
  testWidgets('La sesión con perfil exige PIN y respeta el bloqueo', (
    tester,
  ) async {
    final repo = FakeAuthRepository()
      ..userId = 'usuario'
      ..hasProfile = true;
    final auth = AuthController(repo);
    await auth.restore();
    await tester.pumpWidget(VeciPulsoApp(auth: auth));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    repo.result = const PinResult(false, reason: 'incorrecto', remaining: 2);
    await digits(tester, '012345');
    await tapLabel(tester, 'Continuar');
    expect(find.textContaining('Intentos restantes: 2'), findsOneWidget);
    repo.result = PinResult(
      false,
      until: DateTime.now().add(const Duration(minutes: 1)),
    );
    await auth.verify('012345');
    repo.result = const PinResult(true);
    await auth.verify('012345');
    expect(auth.stage, AuthStage.locked);
    expect(repo.userId, 'usuario');
    await tester.pump(const Duration(minutes: 2));
    await auth.verify('012345');
    expect(auth.stage, AuthStage.unlocked);
    await tester.pumpAndSettle();
  });
}
