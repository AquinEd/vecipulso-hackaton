import 'package:flutter/foundation.dart';

enum AppMode { normal, sos }

class AppModeController extends ChangeNotifier {
  AppMode _mode = AppMode.normal;
  AppMode get mode => _mode;
  bool get isSos => _mode == AppMode.sos;

  void activateSos() => _setMode(AppMode.sos);
  void exitSos() => _setMode(AppMode.normal);

  void _setMode(AppMode value) {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
  }
}
