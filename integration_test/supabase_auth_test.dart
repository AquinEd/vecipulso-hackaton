import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hackaton_veci_pulso/core/config/supabase_config.dart';
import 'package:hackaton_veci_pulso/core/errors/auth_failure.dart';
import 'package:hackaton_veci_pulso/features/auth/data/auth_repository.dart';
import 'package:hackaton_veci_pulso/features/auth/models/auth_models.dart';
import 'package:hackaton_veci_pulso/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hackaton_veci_pulso/features/auth/utils/auth_validators.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test('Contrato v5 con dos usuarios anónimos de prueba', () async {
    expect(SupabaseConfig.problem, isNull);
    final random = Random.secure();
    String digits(int length) =>
        List.generate(length, (_) => random.nextInt(10)).join();
    String newPin() {
      String pin;
      do {
        pin = digits(6);
      } while (AuthValidators.weakPin(pin));
      return pin;
    }

    // Separate namespace from the session used by the installed app.
    final storageKey = 'vecipulso.integration.${digits(12)}';
    SharedPreferencesLocalStorage newStorage() =>
        SharedPreferencesLocalStorage(persistSessionKey: storageKey);
    var storage = newStorage();
    Future<Supabase> start() => Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.key,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        localStorage: storage,
        detectSessionInUri: false,
      ),
    );
    var sdk = await start();
    addTearDown(() async {
      await sdk.dispose();
      await storage.removePersistedSession();
    });
    var repo = SupabaseAuthRepository(sdk.client);
    final zones = await repo.zones();
    expect(zones.isNotEmpty && zones.first.name.isNotEmpty, isTrue);
    expect(repo.userId, isNull);
    final a = AuthController(repo);
    await a.restore();
    final zone = zones.first.id;
    Registration data(String dni) =>
        (dni: dni, name: 'Prueba técnica VeciPulso', zone: zone, consent: true);
    final draft = data(digits(8));
    final pin = newPin();
    expect(a.prepare(draft), isTrue);
    await a.register(pin);
    expect(a.stage, AuthStage.unlocked, reason: a.message);
    final idA = repo.userId!;
    expect(a.profile?.userId == idA, isTrue);
    a.dispose();

    await sdk.dispose();
    storage = newStorage();
    sdk = await start();
    repo = SupabaseAuthRepository(sdk.client);
    final restored = AuthController(repo);
    addTearDown(restored.dispose);
    await restored.restore();
    expect(repo.userId == idA, isTrue);
    expect(restored.stage, AuthStage.locked);
    await restored.verify(pin);
    expect(restored.stage, AuthStage.unlocked);

    final other = SupabaseClient(SupabaseConfig.url, SupabaseConfig.key);
    addTearDown(other.dispose);
    final b = SupabaseAuthRepository(other);
    final idB = await b.ensureSession();
    expect(idB != idA, isTrue);
    await expectLater(
      b.register(draft, newPin()),
      throwsA(
        predicate<Object>(
          (error) => AuthFailure.from(error) == AuthFailure.duplicate,
        ),
      ),
    );
    expect(await b.profile(idB), isNull);
    String dniB;
    do {
      dniB = digits(8);
    } while (dniB == draft.dni);
    await b.register(data(dniB), newPin());
    expect((await b.profile(idB))?.userId == idB, isTrue);
    expect(await b.profile(idA) == null, isTrue);
    expect(await repo.profile(idB) == null, isTrue);

    // Only this run's newly created user receives incorrect PIN attempts.
    final wrong = pin == '000001' ? '000002' : '000001';
    for (var remaining = 4; remaining > 0; remaining--) {
      final result = await repo.verify(wrong);
      expect(result.ok, isFalse);
      expect(result.reason, 'incorrecto');
      expect(result.remaining, remaining);
    }
    final lock = await repo.verify(wrong);
    expect(lock.ok, isFalse);
    expect(lock.reason, 'bloqueado');
    final wait = lock.until!.difference(DateTime.now());
    expect(wait > Duration.zero && wait <= const Duration(minutes: 6), isTrue);
    final duringLock = await repo.verify(pin);
    expect(duringLock.ok, isFalse);
    expect(duringLock.reason, 'bloqueado');
    printOnFailure(
      'Registro, restauración, RLS y bloqueo verificados antes de la espera.',
    );
    await Future<void>.delayed(wait + const Duration(seconds: 2));
    expect((await repo.verify(pin)).ok, isTrue);
  }, timeout: const Timeout(Duration(minutes: 9)));
}
