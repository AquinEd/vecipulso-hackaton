import 'package:flutter/foundation.dart';

enum OfflineDemoStatus { offline, pending, sending, synchronized, error }

class OfflineDemoController extends ChangeNotifier {
  static const request = 'Necesito agua potable';
  OfflineDemoStatus _status = OfflineDemoStatus.offline;
  OfflineDemoStatus get status => _status;

  void createExample() =>
      _advance(OfflineDemoStatus.offline, OfflineDemoStatus.pending);
  void recoverConnection() =>
      _advance(OfflineDemoStatus.pending, OfflineDemoStatus.sending);
  void retry() => _advance(OfflineDemoStatus.error, OfflineDemoStatus.sending);
  bool succeed() =>
      _advance(OfflineDemoStatus.sending, OfflineDemoStatus.synchronized);
  void fail() => _advance(OfflineDemoStatus.sending, OfflineDemoStatus.error);
  void reset() => _advance(_status, OfflineDemoStatus.offline);

  bool _advance(OfflineDemoStatus from, OfflineDemoStatus to) {
    if (_status != from || _status == to) return false;
    _status = to;
    notifyListeners();
    return true;
  }
}
