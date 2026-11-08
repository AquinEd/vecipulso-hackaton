import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/app/app.dart';
import 'package:hackaton_veci_pulso/app/app_mode_controller.dart';
import 'package:hackaton_veci_pulso/app/app_router.dart';
import 'package:hackaton_veci_pulso/features/auth/data/auth_repository.dart';
import 'package:hackaton_veci_pulso/features/auth/models/auth_models.dart';
import 'package:hackaton_veci_pulso/features/auth/presentation/controllers/auth_controller.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  String? userId;
  bool hasProfile = false;
  int registrations = 0;
  Registration? received;
  Object? failure;
  PinResult result = const PinResult(true);
  @override
  Stream<String?> get sessions => const Stream.empty();
  @override
  Future<void> restore() async {}
  @override
  Future<List<Zone>> zones() async => [
    (id: '11111111-1111-4111-8111-111111111111', name: 'Zona norte'),
  ];
  @override
  Future<Profile?> profile(String id) async => hasProfile ? (userId: id) : null;
  @override
  Future<String> ensureSession() async => userId ??= 'test-user';
  @override
  Future<void> register(Registration draft, String pin) async {
    registrations++;
    if (failure case final Object e) throw e;
    received = draft;
    hasProfile = true;
  }

  @override
  Future<PinResult> verify(String pin) async {
    if (failure case final Object e) throw e;
    return result;
  }
}

// Other feature suites exercise screens reached after unlocking.
AuthController unlockedFixture() =>
    AuthController(FakeAuthRepository())..stage = AuthStage.unlocked;
Widget signedInApp() => VeciPulsoApp(auth: unlockedFixture());
GoRouter signedInRouter({AppModeController? modeController}) =>
    createRouter(auth: unlockedFixture(), modeController: modeController);
