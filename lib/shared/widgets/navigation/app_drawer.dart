import '../../../app/app_navigation.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/app/app_routes.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'VeciPulso',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          for (final (route, icon) in const [
            (AppRoute.home, Icons.home_outlined),
            (AppRoute.services, Icons.storefront),
            (AppRoute.solidarity, Icons.volunteer_activism),
            (AppRoute.map, Icons.map_outlined),
            (AppRoute.notifications, Icons.notifications_outlined),
            (AppRoute.settings, Icons.settings_outlined),
            (AppRoute.sos, Icons.sos),
            (AppRoute.tutorial, Icons.menu_book_outlined),
            (AppRoute.access, Icons.accessibility_new),
            (AppRoute.pending, Icons.wifi_off),
            (AppRoute.messages, Icons.forum_outlined),
            (AppRoute.profile, Icons.person_outline),
          ])
            ListTile(
              leading: Icon(icon),
              title: Text(
                route == AppRoute.pending
                    ? 'Estados offline (demo)'
                    : route.title,
              ),
              textColor: route == AppRoute.sos
                  ? Theme.of(context).colorScheme.error
                  : null,
              iconColor: route == AppRoute.sos
                  ? Theme.of(context).colorScheme.error
                  : null,
              onTap: () {
                Scaffold.of(context).closeDrawer();
                if (route == AppRoute.settings ||
                    route == AppRoute.notifications ||
                    route == AppRoute.access ||
                    route == AppRoute.tutorial ||
                    route == AppRoute.pending) {
                  context.push(route.path);
                } else {
                  AppNavigation.open(context, route);
                }
              },
            ),
        ],
      ),
    ),
  );
}
