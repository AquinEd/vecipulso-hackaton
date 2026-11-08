import '../../data/sos_repository.dart';
import '../../models/sos_models.dart';
import 'sos_controllers.dart';

class AlertEmissionController extends SosController<String> {
  AlertEmissionController(this.repository, this.id)
    : ownerId = repository.userId;
  final SosRepository repository;
  final String id;
  final String? ownerId;
  bool uncertain = false;
  bool attempted = false;
  bool get busy => stage == SosStage.loading;
  Future<void> send({
    required AlertClass kind,
    required EmergencyType type,
    required AlertUrgency urgency,
    String? description,
  }) => perform(() async {
    void checkSession() {
      if (ownerId == null || repository.userId != ownerId) {
        throw SosFailure.session;
      }
    }

    checkSession();
    if (uncertain) {
      try {
        final existing = await repository.detail(id);
        checkSession();
        if (existing.autorId != ownerId) throw SosFailure.denied;
        uncertain = false;
        return existing.id;
      } on SosFailure catch (e) {
        if (e != SosFailure.missing) rethrow;
      }
    }
    attempted = true;
    try {
      final result = await repository.emit(
        id: id,
        kind: kind,
        type: type,
        urgency: urgency,
        description: description,
      );
      checkSession();
      if (result != id) throw SosFailure.invalid;
      uncertain = false;
      return result;
    } catch (e) {
      final failure = SosFailure.from(e);
      uncertain = failure == SosFailure.network || failure == SosFailure.server;
      rethrow;
    }
  }, write: true);
}
