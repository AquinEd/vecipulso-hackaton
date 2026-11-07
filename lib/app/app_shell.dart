import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/shared/widgets/navigation/app_drawer.dart';
import 'package:hackaton_veci_pulso/shared/widgets/navigation/app_bottom_navigation.dart';
import 'package:hackaton_veci_pulso/core/constants/app_assets.dart';
import 'package:hackaton_veci_pulso/shared/widgets/common/app_asset_image.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const AppAssetImage(
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
    body: SafeArea(child: shell),
    bottomNavigationBar: AppBottomNavigation(shell: shell),
  );
}
