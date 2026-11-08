import 'package:flutter/foundation.dart';

import '../../../../core/utils/normalize_search.dart';
import '../../models/map_point.dart';

class MapFiltersController extends ChangeNotifier {
  final Set<MapPointLayer> _layers = MapPointLayer.values.toSet();
  String _query = '';
  Set<MapPointLayer> get layers => Set.unmodifiable(_layers);
  String get query => _query;
  bool get all => _layers.length == MapPointLayer.values.length;
  bool get isDefault => all && query.isEmpty;
  void setQuery(String text) {
    if (_query == text) return;
    _query = text;
    notifyListeners();
  }

  void setLayer(MapPointLayer layer, bool enabled) {
    if (enabled ? _layers.add(layer) : _layers.remove(layer)) notifyListeners();
  }

  void only(MapPointLayer layer) {
    if (_layers.length == 1 && _layers.contains(layer)) return;
    _layers
      ..clear()
      ..add(layer);
    notifyListeners();
  }

  void showAll() {
    if (all) return;
    _layers.addAll(MapPointLayer.values);
    notifyListeners();
  }

  void restore() {
    _layers.addAll(MapPointLayer.values);
    _query = '';
    notifyListeners();
  }

  List<MapPoint> apply(Iterable<MapPoint> source) {
    final query = normalizeSearch(_query);
    return List.unmodifiable(
      source.where(
        (point) =>
            _layers.contains(point.layer) &&
            normalizeSearch('${point.title} ${point.subtype}').contains(query),
      ),
    );
  }
}
