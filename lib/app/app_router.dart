import '../features/maps/presentation/screens/neighborhood_map_screen.dart';
import '../features/solidarity/presentation/screens/solidarity_wall_screen.dart';
import '../features/solidarity/models/solidarity_post.dart';
import '../features/services/presentation/screens/services_screen.dart';
import '../features/services/presentation/screens/provider_detail_screen.dart';

import 'package:flutter/material.dart';

import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/create_pin_screen.dart';
import '../features/auth/presentation/screens/login_pin_screen.dart';

import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/app/app_routes.dart';
import 'package:hackaton_veci_pulso/app/app_shell.dart';
import 'package:hackaton_veci_pulso/features/home/presentation/screens/home_screen.dart';
import 'package:hackaton_veci_pulso/shared/widgets/feedback/feature_placeholder_screen.dart';

import '../features/publications/models/publication_draft.dart';
import '../features/publications/presentation/screens/publication_type_screen.dart';
import '../features/publications/presentation/screens/publication_details_screen.dart';
import '../features/publications/presentation/screens/publication_success_screen.dart';

GoRouter createRouter() {
  final controller = PublicationDraftController();
  return GoRouter(
    redirect: (_, state) {
      final path = state.uri.path;
      if (path == '/publicar') return AppRoute.publish.path;
      if (path == '/publicar/confirmacion') return AppRoute.success.path;
      if (path == AppRoute.details.path && controller.draft == null ||
          path == AppRoute.success.path && controller.preview == null) {
        return AppRoute.publish.path;
      }
      if (!path.startsWith('/publicar/') ||
          path == AppRoute.publish.path && controller.preview != null) {
        controller.clear();
      }
      return null;
    },
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
                      : tab == AppRoute.map
                      ? const NeighborhoodMapScreen()
                      : tab == AppRoute.publish
                      ? PublicationTypeScreen(controller: controller)
                      : FeaturePlaceholderScreen(title: tab.title),
                ),
                if (tab == AppRoute.home) ...[
                  GoRoute(
                    path: AppRoute.solidarity.path,
                    builder: (_, _) => const SolidarityWallScreen(),
                    routes: [
                      GoRoute(
                        path: AppRoute.expanded.path.split('/').last,
                        builder: (_, _) =>
                            const SolidarityWallScreen(mode: WallMode.economy),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: AppRoute.services.path,
                    builder: (_, _) => const ServicesScreen(),
                  ),
                  GoRoute(
                    path: AppRoute.provider.path,
                    builder: (_, state) =>
                        ProviderDetailScreen(id: state.pathParameters['id']!),
                  ),
                ],
              ],
            ),
        ],
      ),
      GoRoute(path: '/publicar', redirect: (_, _) => AppRoute.publish.path),
      GoRoute(
        path: '/publicar/confirmacion',
        redirect: (_, _) => AppRoute.success.path,
      ),
      for (final route in AppRoute.values.where(
        (r) => ![
          AppRoute.solidarity,
          AppRoute.expanded,
          AppRoute.services,
          AppRoute.provider,
          AppRoute.home,
          AppRoute.map,
          AppRoute.publish,
          AppRoute.messages,
          AppRoute.profile,
        ].contains(r),
      ))
        GoRoute(
          path: route.path,
          builder: (context, state) => switch (route) {
            AppRoute.details => PublicationDetailsScreen(
              controller: controller,
            ),
            AppRoute.success => PublicationSuccessScreen(
              preview: controller.preview!,
            ),
            AppRoute.login => const LoginPinScreen(),
            AppRoute.register => const RegisterScreen(),
            AppRoute.pin => const CreatePinScreen(),
            _ => Scaffold(
              appBar: AppBar(
                leading: BackButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(AppRoute.home.path),
                ),
              ),
              body: FeaturePlaceholderScreen(title: route.title),
            ),
          },
        ),
    ],
  );
}
