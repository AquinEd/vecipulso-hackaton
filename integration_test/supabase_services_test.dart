import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hackaton_veci_pulso/core/config/supabase_config.dart';
import 'package:hackaton_veci_pulso/features/auth/data/auth_repository.dart';
import 'package:hackaton_veci_pulso/features/services/data/services_repository.dart';
import 'package:hackaton_veci_pulso/features/services/models/service_rows.dart';
import 'package:hackaton_veci_pulso/features/services/presentation/widgets/service_operations.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test('Proveedor y cliente con sesiones independientes y RLS', () async {
    expect(SupabaseConfig.problem, isNull);
    final a = SupabaseClient(SupabaseConfig.url, SupabaseConfig.key);
    final b = SupabaseClient(SupabaseConfig.url, SupabaseConfig.key);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final authA = SupabaseAuthRepository(a), authB = SupabaseAuthRepository(b);
    final zone = (await authA.zones()).first.id;
    for (final auth in [authA, authB]) {
      await auth.ensureSession();
      String digits(int length) =>
          List.generate(length, (_) => Random.secure().nextInt(10)).join();
      await auth.register((
        dni: digits(8),
        name: 'Vecino de prueba',
        zone: zone,
        consent: true,
      ), '37${digits(4)}');
    }
    final provider = ServicesRepository(a), customer = ServicesRepository(b);
    final id = operationId();
    final category = (await provider.categories()).first.id;
    await provider.publish(
      id: id,
      categoryId: category,
      title: 'Servicio prueba $id',
    );
    expect(
      (await customer.page(query: id.split('-').first))
          .any((x) => x.service.id == id),
      isTrue,
    );
    expect((await customer.detail(id)).proveedorId, provider.uid);
    final changed = await b
        .from('servicios')
        .update({'titulo': 'Edición ajena'})
        .eq('id', id)
        .select('id');
    expect(changed, isEmpty);
    final request = await customer.requests.create(operationId(), id);
    expect(
      (await customer.requests.received()).any((r) => r.id == request.id),
      isFalse,
    );
    expect(
      await b.from('perfiles').select('id').eq('id', provider.uid),
      isEmpty,
    );
    expect(
      await a.from('perfiles').select('id').eq('id', customer.uid),
      isEmpty,
    );
    expect(
      (await customer.requests.sent()).any((x) => x.id == request.id),
      isTrue,
    );
    expect(
      (await provider.requests.received()).any((x) => x.id == request.id),
      isTrue,
    );
    expect(
      (await provider.requests.sent()).any((x) => x.id == request.id),
      isFalse,
    );
    await expectLater(
      customer.requests.transition(request.id, RequestStatus.completada),
      throwsA(ServicesFailure.conflict),
    );
    await expectLater(
      customer.recommendations.recommend(operationId(), id, 4),
      throwsA(ServicesFailure.denied),
    );
    await provider.requests.transition(request.id, RequestStatus.contactado);
    await provider.requests.transition(request.id, RequestStatus.completada);
    expect(
      (await customer.requests.sent())
          .singleWhere((x) => x.id == request.id)
          .puedoRecomendar,
      isTrue,
    );
    await customer.recommendations.recommend(operationId(), id, 4);
    for (final repo in [provider, customer]) {
      expect((await repo.recommendations.reviews(id)).single.puntaje, 4);
      expect(await repo.recommendations.statistics(id), (
        count: 1,
        average: 4.0,
        approved: false,
      ));
    }
    await expectLater(
      customer.recommendations.recommend(operationId(), id, 5),
      throwsA(ServicesFailure.duplicate),
    );
  }, skip: !const bool.fromEnvironment('ALLOW_SERVICES_TEST_WRITES'));
}
