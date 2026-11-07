import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'app_mode_controller.dart';
import 'app_navigation.dart';

import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';

import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/shared/widgets/navigation/app_drawer.dart';
import 'package:hackaton_veci_pulso/shared/widgets/navigation/app_bottom_navigation.dart';
import 'package:hackaton_veci_pulso/core/constants/app_assets.dart';
import 'package:hackaton_veci_pulso/shared/widgets/common/app_asset_image.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell, required this.path});
  final StatefulNavigationShell shell;
  final String path;
  @override
  Widget build(BuildContext context) {
    // The focused SOS flow owns its Scaffold and back handling. Keep the shell
    // mounted so the other branches retain their local state.
    if (path == AppRoute.actions.path) return Material(child: shell);
    final sos = context.watch<AppModeController>().isSos;
    final emergency =
        path == AppRoute.sos.path || path == AppRoute.riskMap.path;
    final principal = [
      AppRoute.services.path,
      AppRoute.solidarity.path,
      AppRoute.sos.path,
      AppRoute.riskMap.path,
      AppRoute.notifications.path,
      AppRoute.settings.path,
    ].contains(path);
    void back() {
      if (path == AppRoute.riskMap.path) {
        AppNavigation.open(context, AppRoute.sos);
      } else if (path == AppRoute.sos.path) {
        AppNavigation.exitSos(context);
      } else {
        AppNavigation.open(context, AppRoute.home);
      }
    }

    return PopScope(
      canPop: !principal,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && principal) back();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: emergency ? AppColors.sos : null,
          foregroundColor: emergency ? Colors.white : null,
          automaticallyImplyLeading: false,
          leading:
              emergency ||
                  path == AppRoute.notifications.path ||
                  path == AppRoute.settings.path
              ? BackButton(onPressed: back)
              : null,
          title: sos && path != AppRoute.brigades.path
              ? const Text('Modo SOS · Demo')
              : const AppAssetImage(
                  path: AppAssets.vecipulsoLogoHorizontalPNG,
                  label: 'VeciPulso',
                  height: 44,
                ),
          actions: [
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Abrir menú',
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ],
        ),
        drawer: AppDrawer(shell: shell),
        body: SafeArea(
          child: Column(
            children: [
              if (sos && !emergency)
                TextButton(
                  onPressed: () => AppNavigation.exitSos(context),
                  child: const Text('Salir del Modo SOS'),
                ),
              Expanded(child: shell),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNavigation(shell: shell),
      ),
    );
  }
}
