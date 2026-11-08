import '../../data/sos_repository.dart';
import '../../models/sos_models.dart';
import 'sos_controllers.dart';

typedef HelpBoardData = ({
  SosAlert alert,
  List<HelpResponse> responses,
  Map<String, String?> names,
});
List<HelpStatus> helpTransitions(
  HelpResponse response,
  SosAlert alert,
  String? viewer,
  List<HelpResponse> responses,
) {
  if (![
    AlertStatus.sin_verificar,
    AlertStatus.verificada,
  ].contains(alert.estado)) {
    return [];
  }
  final owner = viewer != null && viewer == alert.autorId;
  final volunteer = viewer != null && viewer == response.voluntarioId;
  if (!owner && !volunteer) return [];
  if (response.alertaId != alert.id) return [];
  final live = [
    HelpStatus.ofrecida,
    HelpStatus.aceptada,
    HelpStatus.en_camino,
  ].contains(response.estado);
  return [
    if (owner &&
        response.estado == HelpStatus.ofrecida &&
        !responses.any(
          (r) => [HelpStatus.aceptada, HelpStatus.en_camino].contains(r.estado),
        ))
      HelpStatus.aceptada,
    if (volunteer && response.estado == HelpStatus.aceptada)
      HelpStatus.en_camino,
    if ([HelpStatus.aceptada, HelpStatus.en_camino].contains(response.estado))
      HelpStatus.completada,
    if (live) HelpStatus.cancelada,
  ];
}

class HelpBoardController extends SosController<HelpBoardData> {
  HelpBoardController(this.repository, this.alertId);
  final SosRepository repository;
  final String alertId;
  bool uncertain = false;
  Future<HelpBoardData> read() async {
    final viewer = repository.userId;
    if (viewer == null) throw SosFailure.session;
    final alert = await repository.detail(alertId);
    final responses = await repository.responses(alertId);
    final names = <String, String?>{};
    for (final uid in {
      for (final r in responses) r.voluntarioId,
      alert.autorId,
    }) {
      names[uid] = await repository.publicName(uid);
    }
    if (viewer != repository.userId) throw SosFailure.session;
    return (alert: alert, responses: responses, names: names);
  }

  Future<void> refresh() => perform(() async {
    final snapshot = await read();
    uncertain = false;
    return snapshot;
  });
  Future<void> update(String id, HelpStatus target) => perform(() async {
    final current = await read();
    final row = current.responses.where((r) => r.id == id).firstOrNull;
    if (row == null) throw SosFailure.missing;
    if (!helpTransitions(
      row,
      current.alert,
      repository.userId,
      current.responses,
    ).contains(target)) {
      throw SosFailure.conflict;
    }
    try {
      await repository.updateHelp(id, target);
      final snapshot = await read();
      uncertain = false;
      return snapshot;
    } catch (e) {
      final failure = SosFailure.from(e);
      uncertain = failure == SosFailure.network || failure == SosFailure.server;
      rethrow;
    }
  }, write: true);
  Future<HelpResponse> offer(String id, String? message) async {
    final viewer = repository.userId;
    if (viewer == null) throw SosFailure.session;
    // Reconcile a previous response before attempting the same operation UUID.
    final rows = await repository.responses(alertId);
    if (viewer != repository.userId) {
      throw SosFailure.session;
    }
    final existing = rows
        .where((r) => r.id == id && r.voluntarioId == repository.userId)
        .firstOrNull;
    if (existing != null) return existing;
    final response = await repository.offer(
      id: id,
      alertId: alertId,
      message: message,
    );
    if (viewer != repository.userId) throw SosFailure.session;
    if (response.voluntarioId != viewer || response.alertaId != alertId) {
      throw SosFailure.invalid;
    }
    return response;
  }
}
