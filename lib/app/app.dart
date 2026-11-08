import 'package:hackaton_veci_pulso/features/auth/presentation/controllers/auth_controller.dart';

import 'app_mode_controller.dart';
import 'accessibility_controller.dart';

import 'package:provider/provider.dart';

import 'package:flutter/material.dart';
import 'package:hackaton_veci_pulso/app/app_router.dart';
import 'package:hackaton_veci_pulso/core/theme/app_theme.dart';

class VeciPulsoApp extends StatefulWidget {
  const VeciPulsoApp({super.key, required this.auth});
  final AuthController auth;
  @override
  State<VeciPulsoApp> createState() => _VeciPulsoAppState();
}

class _VeciPulsoAppState extends State<VeciPulsoApp> {
  final mode = AppModeController();
  late final router = createRouter(auth: widget.auth, modeController: mode);
  @override
  void dispose() {
    router.dispose();
    mode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: widget.auth,
    child: ChangeNotifierProvider(
      create: (_) => AccessibilityController(),
      child: Consumer<AccessibilityController>(
        builder: (_, settings, _) => MaterialApp.router(
          title: 'VeciPulso',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(
            highContrast: settings.highContrast,
            largeButtons: settings.largeButtons,
          ),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: settings.largeText
                  ? media.copyWith(
                      textScaler: _LargeTextScaler(media.textScaler),
                    )
                  : media,
              child: child!,
            );
          },
          routerConfig: router,
        ),
      ),
    ),
  );
}

class _LargeTextScaler extends TextScaler {
  const _LargeTextScaler(this.system);
  final TextScaler system;
  @override
  double scale(double fontSize) => system.scale(fontSize) * 1.2;
  @override
  double get textScaleFactor => scale(14) / 14;
}
