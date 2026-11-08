import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/auth_failure.dart';
import '../../data/auth_repository.dart';
import '../../models/auth_models.dart';
import '../../utils/auth_validators.dart';

enum AuthStage { loading, configuration, register, locked, unlocked, error }

class AuthController extends ChangeNotifier {
  AuthController(AuthRepository source)
    : repository = source,
      stage = AuthStage.loading {
    observedId = source.userId;
    subscription = source.sessions.listen(
      (id) {
        if (id == observedId) return;
        final ownSignIn = creatingSession && observedId == null && id != null;
        observedId = id;
        if (!ownSignIn) {
          timer?.cancel();
          blockedUntil = null;
          if (id == null) {
            generation++;
            busy = false;
            fail(AuthFailure.session);
            notifyListeners();
          } else {
            unawaited(restore());
          }
        }
      },
      onError: (Object error) {
        generation++;
        fail(error);
        busy = false;
        notifyListeners();
      },
    );
  }
  AuthController.unavailable(this.message, {bool configured = false})
    : repository = null,
      stage = configured ? AuthStage.error : AuthStage.configuration;
  final AuthRepository? repository;
  AuthStage stage;
  String? message;
  List<Zone> zones = [];
  Registration? draft;
  Profile? profile;
  bool busy = false;
  bool creatingSession = false;
  String? observedId;
  int generation = 0;
  DateTime? blockedUntil;
  Timer? timer;
  StreamSubscription<String?>? subscription;

  void fail(Object error) {
    final failure = AuthFailure.from(error);
    debugPrint('VeciPulso auth: ${failure.name}');
    stage = AuthStage.error;
    message = failure.message;
    draft = null;
    profile = null;
  }

  Future<void> restore() async {
    final repo = repository;
    if (repo == null) return;
    final request = ++generation;
    busy = true;
    draft = null;
    profile = null;
    message = null;
    stage = AuthStage.loading;
    notifyListeners();
    try {
      await repo.restore();
      final id = repo.userId;
      final found = id == null ? null : await repo.profile(id);
      if (request != generation || id != repo.userId) return;
      if (found == null) {
        final available = await repo.zones();
        if (request != generation) return;
        if (available.isEmpty) throw AuthFailure.zone;
        zones = available;
        stage = AuthStage.register;
      } else {
        profile = found;
        stage = AuthStage.locked;
      }
    } catch (error) {
      if (request == generation) fail(error);
    } finally {
      if (request == generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void discardDraft() {
    draft = null;
  }

  bool prepare(Registration data) {
    if (busy || stage != AuthStage.register) return false;
    message =
        AuthValidators.dni(data.dni) ??
        AuthValidators.name(data.name) ??
        (!zones.any((z) => z.id == data.zone)
            ? AuthFailure.zone.message
            : !data.consent
            ? AuthFailure.consent.message
            : null);
    if (message == null) draft = data;
    notifyListeners();
    return message == null;
  }

  Future<void> register(String pin) async {
    final data = draft;
    if (stage != AuthStage.register || data == null || busy) return;
    final repo = repository!;
    final request = generation;
    busy = true;
    message = null;
    notifyListeners();
    var submitted = false;
    try {
      if (AuthValidators.pin(pin) != null) throw AuthFailure.pin;
      if (AuthValidators.weakPin(pin)) throw AuthFailure.weakPin;
      creatingSession = true;
      final id = await repo.ensureSession();
      creatingSession = false;
      if (request != generation || id != repo.userId) return;
      observedId = id;
      // A previous request may have committed before the response was lost.
      final existing = await repo.profile(id);
      if (request != generation || id != repo.userId) return;
      if (existing != null) {
        profile = existing;
        draft = null;
        stage = AuthStage.locked;
        return;
      }
      submitted = true;
      await repo.register(data, pin);
      final confirmed = await repo.profile(id);
      if (request != generation || id != repo.userId) return;
      if (confirmed == null) throw AuthFailure.profile;
      profile = confirmed;
      draft = null;
      stage = AuthStage.unlocked;
    } catch (error) {
      if (request != generation) return;
      final failure = AuthFailure.from(error);
      if (failure == AuthFailure.session ||
          submitted &&
              [
                AuthFailure.profile,
                AuthFailure.network,
                AuthFailure.unexpected,
              ].contains(failure)) {
        fail(error);
      } else {
        message = failure.message;
      }
    } finally {
      creatingSession = false;
      if (request == generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> verify(String pin) async {
    if (stage != AuthStage.locked || busy || blockedUntil != null) return;
    final repo = repository!;
    final request = generation;
    busy = true;
    message = null;
    notifyListeners();
    try {
      if (AuthValidators.pin(pin) != null) throw AuthFailure.pin;
      if (repo.userId == null || repo.userId != profile?.userId) {
        throw AuthFailure.session;
      }
      final result = await repo.verify(pin);
      if (request != generation || repo.userId != profile?.userId) return;
      if (result.ok) {
        stage = AuthStage.unlocked;
      } else if (result.until?.isAfter(DateTime.now()) == true) {
        blockedUntil = result.until!;
        message =
            'Cuenta bloqueada hasta ${blockedUntil!.toLocal().toString().split(".").first}.';
        timer?.cancel();
        timer = Timer(blockedUntil!.difference(DateTime.now()), () {
          blockedUntil = null;
          message = null;
          notifyListeners();
        });
      } else if (result.reason == 'bloqueado') {
        throw AuthFailure.blocked;
      } else if (result.reason == 'sin_sesion') {
        throw AuthFailure.session;
      } else if (result.reason == 'sin_pin') {
        throw AuthFailure.missingPin;
      } else if (result.reason == 'formato') {
        throw AuthFailure.pin;
      } else if (result.reason != 'incorrecto') {
        throw AuthFailure.unexpected;
      } else {
        message =
            'PIN incorrecto.${result.remaining == null ? "" : " Intentos restantes: ${result.remaining}."}';
      }
    } catch (error) {
      if (request != generation) return;
      final failure = AuthFailure.from(error);
      if ([
        AuthFailure.session,
        AuthFailure.blocked,
        AuthFailure.missingPin,
      ].contains(failure)) {
        fail(error);
      } else {
        message = failure.message;
      }
    } finally {
      if (request == generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    generation++;
    subscription?.cancel();
    timer?.cancel();
    draft = null;
    super.dispose();
  }
}
