import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/auth_fixture.dart';

import 'package:hackaton_veci_pulso/app/accessibility_controller.dart';
import 'package:hackaton_veci_pulso/core/theme/app_theme.dart';

void main() {
  for (final width in [320.0, 412.0]) {
    for (final scale in [1.5, 2.0]) {
      testWidgets('Pantallas complementarias a $width px y escala $scale', (
        t,
      ) async {
        await t.binding.setSurfaceSize(Size(width, 700));
        addTearDown(() => t.binding.setSurfaceSize(null));
        final settings = AccessibilityController();
        for (final option in AccessibilityPreference.values) {
          settings.update(option, true);
        }
        final router = signedInRouter();
        addTearDown(router.dispose);
        addTearDown(settings.dispose);
        await t.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.build(highContrast: true, largeButtons: true),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          ),
        );
        for (final path in [
          '/mensajes',
          '/mensajes/ayuda',
          '/perfil',
          '/notificaciones',
          '/configuracion',
        ]) {
          router.go(path);
          await t.pumpAndSettle();
          await t.drag(find.byType(Scrollable).first, const Offset(0, -600));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: path);
        }
      });
    }
  }
}
