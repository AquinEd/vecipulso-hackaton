import 'package:flutter/foundation.dart';

import '../../data/sos_repository.dart';
import '../../models/sos_models.dart';

enum SosStage { initial, loading, success, empty, error, offline, denied }

class SosController<T> extends ChangeNotifier {
  T? data;
  SosFailure? failure;
  SosStage stage = SosStage.initial;
  int _generation = 0;
  bool _disposed = false, _writing = false;
  Future<void> perform(
    Future<T> Function() action, {
    bool write = false,
  }) async {
    if (_disposed || _writing) return;
    final generation = ++_generation;
    _writing = write;
    data = null;
    failure = null;
    stage = SosStage.loading;
    notifyListeners();
    try {
      final result = await action();
      if (_disposed || generation != _generation) return;
      data = result;
      stage = result == null || result is Iterable && result.isEmpty
          ? SosStage.empty
          : SosStage.success;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      failure = SosFailure.from(e);
      stage = switch (failure) {
        SosFailure.network => SosStage.offline,
        SosFailure.session || SosFailure.denied => SosStage.denied,
        _ => SosStage.error,
      };
    } finally {
      if (write) {
        _writing = false;
      }
      if (!_disposed && generation == _generation) {
        _writing = false;
        notifyListeners();
      }
    }
  }

  void clear() {
    if (_disposed) return;
    _generation++;
    data = null;
    failure = null;
    stage = SosStage.initial;
    // A pending write still owns its slot until its request settles.
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

class AlertsController extends SosController<List<SosAlert>> {
  AlertsController(this.repository);
  final SosRepository repository;
  Future<void> refresh({bool mine = false, int offset = 0}) =>
      perform(() => repository.alerts(mine: mine, offset: offset));
}

class AlertDetailController extends SosController<SosAlert> {
  AlertDetailController(this.repository);
  final SosRepository repository;
  Future<void> refresh(String id) => perform(() => repository.detail(id));
  Future<void> cancel(String id) =>
      perform(() => repository.cancel(id), write: true);
  Future<void> emit({
    required String id,
    required AlertClass kind,
    required EmergencyType type,
    required AlertUrgency urgency,
    String? description,
    SosPoint? point,
  }) => perform(() async {
    final saved = await repository.emit(
      id: id,
      kind: kind,
      type: type,
      urgency: urgency,
      description: description,
      point: point,
    );
    return repository.detail(saved);
  }, write: true);
}

class HelpResponsesController extends SosController<List<HelpResponse>> {
  HelpResponsesController(this.repository);
  final SosRepository repository;
  Future<void> refresh(String alertId) =>
      perform(() => repository.responses(alertId));
  Future<void> offer({
    required String id,
    required String alertId,
    String? resourceId,
    String? message,
    SosPoint? point,
  }) => perform(() async {
    await repository.offer(
      id: id,
      alertId: alertId,
      resourceId: resourceId,
      message: message,
      point: point,
    );
    return repository.responses(alertId);
  }, write: true);
  Future<void> update(String id, HelpStatus status) => perform(() async {
    final result = await repository.updateHelp(id, status);
    return repository.responses(result.alertaId);
  }, write: true);
}

class ResourcesController extends SosController<List<CriticalResource>> {
  ResourcesController(this.repository);
  final SosRepository repository;
  Future<void> refresh({int offset = 0}) =>
      perform(() => repository.resources(offset: offset));
}

class BrigadesController extends SosController<List<SupportGroup>> {
  BrigadesController(this.repository);
  final SosRepository repository;
  Future<void> refresh({int offset = 0}) =>
      perform(() => repository.groups(offset: offset));
}

typedef CatalogData = ({
  List<CriticalResource> resources,
  List<SupportGroup> groups,
});

class SosCatalogController extends SosController<CatalogData> {
  SosCatalogController(this.repository, this.brigades);
  final SosRepository repository;
  final bool brigades;
  int offset = 0;
  ResourceType? resourceType;
  GroupType? groupType;
  String query = '';
  Future<void> refresh() => perform(
    () async => (
      resources: brigades
          ? <CriticalResource>[]
          : await repository.resourcePage(offset: offset, type: resourceType),
      groups: brigades
          ? await repository.groupPage(
              offset: offset,
              type: groupType,
              query: query,
            )
          : <SupportGroup>[],
    ),
  );
}
