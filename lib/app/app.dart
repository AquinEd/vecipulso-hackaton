import 'package:flutter/material.dart';
import 'package:hackaton_veci_pulso/app/app_router.dart';
import 'package:hackaton_veci_pulso/core/theme/app_theme.dart';

class VeciPulsoApp extends StatefulWidget {
  const VeciPulsoApp({super.key});
  @override
  State<VeciPulsoApp> createState() => _VeciPulsoAppState();
}

class _VeciPulsoAppState extends State<VeciPulsoApp> {
  final router = createRouter();
  @override
  void dispose() {
    router.dispose();
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
