import 'package:flutter/foundation.dart';

import '../../data/location_service.dart';

enum LocationStage {
  initial,
  loading,
  ready,
  denied,
  permanentlyDenied,
  disabled,
  timeout,
  unavailable,
  session,
}

class LocationController extends ChangeNotifier {
  LocationController(this.service, {this.sessionId})
    : _identity = sessionId?.call();
  final LocationService service;
  final String? Function()? sessionId;
  String? _identity;
  DeviceLocation? location;
  LocationFailure? failure;
  LocationStage stage = LocationStage.initial;
  int _generation = 0;
  bool _disposed = false, _inFlight = false;
  bool get busy => _inFlight;

  void syncSession({bool notify = true}) {
    if (_disposed || sessionId == null || sessionId!() == _identity) return;
    _identity = sessionId!();
    clear(notify: notify);
  }

  void clear({bool notify = true}) {
    if (_disposed) return;
    _generation++;
    location = null;
    failure = null;
    stage = LocationStage.initial;
    // A pending native one-shot keeps its slot until it settles.
    if (notify) notifyListeners();
  }

  Future<void> locate() async {
    if (_disposed || _inFlight) return;
    syncSession(notify: false);
    final identity = _identity;
    final request = ++_generation;
    bool active() =>
        !_disposed &&
        request == _generation &&
        (sessionId == null || identity != null && sessionId!() == identity);
    _inFlight = true;
    location = null;
    failure = null;
    stage = LocationStage.loading;
    notifyListeners();
    try {
      if (sessionId != null && identity == null) throw LocationFailure.session;
      final result = await service.locate(isActive: active);
      if (_disposed || request != _generation) return;
      if (!active()) throw LocationFailure.session;
      location = result;
      stage = LocationStage.ready;
    } catch (error) {
      if (_disposed || request != _generation) return;
      failure = !active()
          ? LocationFailure.session
          : error is LocationFailure
          ? error
          : LocationFailure.unavailable;
      stage = switch (failure!) {
        LocationFailure.denied => LocationStage.denied,
        LocationFailure.permanentlyDenied => LocationStage.permanentlyDenied,
        LocationFailure.disabled => LocationStage.disabled,
        LocationFailure.timeout => LocationStage.timeout,
        LocationFailure.session => LocationStage.session,
        _ => LocationStage.unavailable,
      };
    } finally {
      _inFlight = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    location = null;
    super.dispose();
  }
}
