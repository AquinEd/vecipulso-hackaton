import 'package:flutter_test/flutter_test.dart';

import 'app_mode_navigation_test.dart' show start, tab, tap;

void main() {
  testWidgets('Perfil ficticio y acceso a mensajes', (t) async {
    final (router, _) = await start(t);
    await tab(t, 'Perfil');
    expect(find.text('Vecino de ejemplo'), findsOneWidget);
    expect(find.textContaining('PIN'), findsNothing);
    await tap(t, find.text('Mis mensajes'));
    expect(router.state.uri.path, '/mensajes');
  });
}
