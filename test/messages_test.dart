import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackaton_veci_pulso/features/messages/presentation/screens/messages_screen.dart';

void main() {
  testWidgets('Busca conversaciones ficticias por nombre público y tema', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(home: Scaffold(body: MessagesScreen())),
    );
    expect(find.text('Conversaciones de demostración'), findsOneWidget);
    for (final query in [
      'INES',
      'ayuda comunitaria',
      'carpinteria',
      'inexistente',
    ]) {
      await t.enterText(find.byType(TextField), query);
      await t.pump();
      expect(
        find.text(switch (query) {
          'carpinteria' => 'Leo Ve',
          'inexistente' => 'Sin resultados de búsqueda',
          _ => 'Inés Prad',
        }),
        findsOneWidget,
      );
    }
  });
}
