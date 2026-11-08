import 'package:flutter/foundation.dart';

import '../../data/services_repository.dart';
import '../../models/service_rows.dart';

enum ServiceStage { initial, loading, loaded, empty, error, denied, offline }

class ServiceController<T> extends ChangeNotifier {
  T? data;
  ServicesFailure? failure;
  ServiceStage stage = ServiceStage.initial;
  int _generation = 0;
  bool _disposed = false;
  bool _writing = false;

  Future<void> load(Future<T> Function() fetch, {bool write = false}) async {
    if (_disposed || _writing) return;
    final generation = ++_generation;
    _writing = write;
    data = null;
    failure = null;
    stage = ServiceStage.loading;
    notifyListeners();
    try {
      final result = await fetch();
      if (generation != _generation) return;
      data = result;
      stage = result is Iterable && result.isEmpty
          ? ServiceStage.empty
          : ServiceStage.loaded;
    } catch (e) {
      if (generation != _generation) return;
      failure = ServicesFailure.from(e);
      stage = switch (failure) {
        ServicesFailure.denied ||
        ServicesFailure.session => ServiceStage.denied,
        ServicesFailure.network => ServiceStage.offline,
        _ => ServiceStage.error,
      };
    } finally {
      if (generation == _generation) {
        _writing = false;
        notifyListeners();
      }
    }
  }

  void clear() {
    if (_disposed) return;
    _generation++;
    _writing = false;
    data = null;
    failure = null;
    stage = ServiceStage.initial;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

class DirectoryController extends ServiceController<List<ServiceRow>> {
  DirectoryController(this.repository);
  final ServicesRepository repository;
  Future<void> refresh({int? categoryId}) =>
      load(() => repository.directory(categoryId: categoryId));
}

class NearbyController extends ServiceController<List<NearbyService>> {
  NearbyController(this.repository);
  final ServicesRepository repository;
  Future<void> search(
    double lat,
    double lng, {
    int radius = 3000,
    String? query,
    String? category,
    double minimum = 0,
  }) => load(
    () => repository.nearby(
      lat,
      lng,
      radius: radius,
      query: query,
      category: category,
      minimum: minimum,
    ),
  );
}

typedef ServiceDetail = ({
  ServiceRow service,
  PublicProvider? provider,
  ServiceContact? contact,
  List<ServiceWork> works,
  List<ServiceReview> reviews,
});

class ServiceDetailController extends ServiceController<ServiceDetail> {
  ServiceDetailController(this.services, this.recommendations);
  final ServicesRepository services;
  final RecommendationsRepository recommendations;
  Future<void> refresh(String id) => load(() async {
    final service = await services.detail(id);
    final parts = await (
      services.provider(service.proveedorId),
      services.contact(id),
      services.works(id),
      recommendations.reviews(id),
    ).wait;
    return (
      service: service,
      provider: parts.$1,
      contact: parts.$2,
      works: parts.$3,
      reviews: parts.$4,
    );
  });
}

class RequestController extends ServiceController<ServiceRequest> {
  RequestController(this.repository);
  final RequestsRepository repository;
  Future<void> create(String id, String serviceId, {String? message}) => load(
    () => repository.create(id, serviceId, message: message),
    write: true,
  );
  Future<void> transition(String id, RequestStatus status) =>
      load(() => repository.transition(id, status), write: true);
}

class RecommendationController extends ServiceController<String> {
  RecommendationController(this.repository);
  final RecommendationsRepository repository;
  Future<void> submit(
    String id,
    String serviceId,
    int stars, {
    String? comment,
  }) => load(
    () => repository.recommend(id, serviceId, stars, comment: comment),
    write: true,
  );
}

class ServiceEditorController extends ServiceController<ServiceRow> {
  ServiceEditorController(this.repository);
  final ServicesRepository repository;

  Future<void> publish({
    required String id,
    required int categoryId,
    required String title,
    String? description,
    int? years,
  }) => load(
    () => repository.publish(
      id: id,
      categoryId: categoryId,
      title: title,
      description: description,
      years: years,
    ),
    write: true,
  );
}

class SentRequestsController extends ServiceController<List<SentRequest>> {
  SentRequestsController(this.repository);
  final RequestsRepository repository;
  Future<void> refresh() => load(repository.sent);
}

class ReceivedRequestsController
    extends ServiceController<List<ReceivedRequest>> {
  ReceivedRequestsController(this.repository);
  final RequestsRepository repository;
  Future<void> refresh() => load(repository.received);
}
