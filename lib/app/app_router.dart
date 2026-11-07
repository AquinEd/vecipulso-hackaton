import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/app/app_routes.dart';
import 'package:hackaton_veci_pulso/app/app_shell.dart';
import 'package:hackaton_veci_pulso/features/home/presentation/screens/home_screen.dart';
import 'package:hackaton_veci_pulso/shared/widgets/feedback/feature_placeholder_screen.dart';

GoRouter createRouter() => GoRouter(
  initialLocation: AppRoute.home.path,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        for (final tab in [
          AppRoute.home,
          AppRoute.map,
          AppRoute.publish,
          AppRoute.messages,
          AppRoute.profile,
        ])
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: tab.path,
                builder: (context, state) => tab == AppRoute.home
                    ? const HomeScreen()
                    : FeaturePlaceholderScreen(title: tab.title),
              ),
            ],
          ),
      ],
    ),
    for (final route in AppRoute.values.where(
      (r) => ![
        AppRoute.home,
        AppRoute.map,
        AppRoute.publish,
        AppRoute.messages,
        AppRoute.profile,
      ].contains(r),
    ))
      GoRoute(
        path: route.path,
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            leading: BackButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoute.home.path),
            ),
          ),
          body: FeaturePlaceholderScreen(title: route.title),
        ),
      ),
  ],
);
