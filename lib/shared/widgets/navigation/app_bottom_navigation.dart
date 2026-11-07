import '../../../app/app_navigation.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/app/app_routes.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: shell.currentIndex,
    onDestinationSelected: (index) {
      if (index < 2) {
        AppNavigation.open(context, index == 0 ? AppRoute.home : AppRoute.map);
      } else {
        shell.goBranch(index);
      }
    },
    destinations: [
      NavigationDestination(
        icon: const Icon(Icons.home),
        label: AppRoute.home.title,
      ),
      NavigationDestination(
        icon: const Icon(Icons.map_outlined),
        label: AppRoute.map.title,
      ),
      NavigationDestination(
        icon: const Icon(Icons.add_circle_outline),
        label: AppRoute.publish.title,
      ),
      NavigationDestination(
        icon: const Icon(Icons.chat_bubble_outline),
        label: AppRoute.messages.title,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        label: AppRoute.profile.title,
      ),
    ],
  );
}
