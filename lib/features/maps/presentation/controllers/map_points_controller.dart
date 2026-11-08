import 'package:flutter/foundation.dart';

import '../../data/map_points_repository.dart';
import '../../models/map_origin.dart';
import '../../models/map_point.dart';

enum MapPointsStage {
  initial,
  originRequired,
  loading,
  ready,
  empty,
  offline,
  denied,
  invalid,
  error,
}

class MapPointsController extends ChangeNotifier {
  MapPointsController(this.repository) : _viewer = repository.userId;
  final MapPointsRepository repository;
  String? _viewer;
  (double, double, int)? _query;
  Future<void>? _pending;
  int _generation = 0;
  bool _disposed = false;
  MapPointsStage stage = MapPointsStage.initial;
  MapPointsFailure? failure;
  MapPointsResult? result;
  DateTime? updatedAt;
  int? get radiusMeters => _query?.$3;

  void syncSession({bool notify = true}) {
    if (_disposed || _viewer == repository.userId) return;
    _viewer = repository.userId;
    clear(notify: notify);
  }

  void clear({bool notify = true}) {
    if (_disposed) return;
    _generation++;
    _query = null;
    _pending = null;
    result = null;
    failure = null;
    updatedAt = null;
    stage = MapPointsStage.initial;
    if (notify) notifyListeners();
  }

  void requireOrigin() {
    if (_disposed || stage == MapPointsStage.originRequired) return;
    clear(notify: false);
    stage = MapPointsStage.originRequired;
    notifyListeners();
  }

  Future<void> refreshCurrent() {
    final query = _query;
    if (_disposed) return Future.value();
    if (query == null) {
      requireOrigin();
      return Future.value();
    }
    return refresh(
      GeoCoordinate(query.$1, query.$2),
      radiusMeters: query.$3,
      force: true,
    );
  }

  Future<void> refresh(
    GeoCoordinate origin, {
    int radiusMeters = 3000,
    bool force = false,
  }) {
    if (_disposed) return Future.value();
    syncSession(notify: false);
    final query = (origin.latitude, origin.longitude, radiusMeters);
    if (_query == query) {
      if (stage == MapPointsStage.loading) return _pending ?? Future.value();
      if (!force &&
          {MapPointsStage.ready, MapPointsStage.empty}.contains(stage)) {
        return Future.value();
      }
    }
    _query = query;
    final generation = ++_generation;
    final viewer = repository.userId;
    result = null;
    failure = null;
    updatedAt = null;
    stage = MapPointsStage.loading;
    // Install the future before notifying listeners (reentrant reads coalesce).
    final future = _fetch(origin, radiusMeters, generation, viewer);
    _pending = future;
    notifyListeners();
    return future;
  }

  Future<void> _fetch(
    GeoCoordinate origin,
    int radius,
    int generation,
    String? viewer,
  ) async {
    bool active() =>
        !_disposed && generation == _generation && repository.userId == viewer;
    try {
      if (viewer == null) throw MapPointsFailure.denied;
      final data = await repository.load(
        origin,
        radiusMeters: radius,
        isActive: active,
      );
      if (_disposed || generation != _generation) return;
      if (repository.userId != viewer) throw MapPointsFailure.denied;
      result = data;
      stage = data.points.isEmpty ? MapPointsStage.empty : MapPointsStage.ready;
      updatedAt = DateTime.now();
    } catch (error) {
      if (_disposed || generation != _generation) return;
      failure = repository.userId != viewer
          ? MapPointsFailure.denied
          : MapPointsFailure.from(error);
      stage = switch (failure!) {
        MapPointsFailure.offline => MapPointsStage.offline,
        MapPointsFailure.denied => MapPointsStage.denied,
        MapPointsFailure.invalid => MapPointsStage.invalid,
        _ => MapPointsStage.error,
      };
    } finally {
      if (!_disposed && generation == _generation) {
        _pending = null;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    result = null;
    super.dispose();
  }
}
