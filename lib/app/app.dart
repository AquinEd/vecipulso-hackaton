import 'app_mode_controller.dart';

import 'package:flutter/material.dart';
import 'package:hackaton_veci_pulso/app/app_router.dart';
import 'package:hackaton_veci_pulso/core/theme/app_theme.dart';

class VeciPulsoApp extends StatefulWidget {
  const VeciPulsoApp({super.key});
  @override
  State<VeciPulsoApp> createState() => _VeciPulsoAppState();
}

class _VeciPulsoAppState extends State<VeciPulsoApp> {
  final mode = AppModeController();
  late final router = createRouter(modeController: mode);
  @override
  void dispose() {
    router.dispose();
    mode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'VeciPulso',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    routerConfig: router,
  );
}
