import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_mode_controller.dart';
import 'app_routes.dart';

/// Principal destinations replace the current location; details keep using push.
abstract final class AppNavigation {
  static void open(BuildContext context, AppRoute route) {
    final mode = context.read<AppModeController>();
    if (route == AppRoute.sos || route == AppRoute.riskMap) mode.activateSos();
    final target = switch (route) {
      AppRoute.home when mode.isSos => AppRoute.sos,
      AppRoute.map when mode.isSos => AppRoute.riskMap,
      _ => route,
    };
    context.go(target.path);
  }

  static void exitSos(BuildContext context) {
    context.read<AppModeController>().exitSos();
    context.go(AppRoute.home.path);
  }
}
