import 'package:provider/provider.dart';

import '../features/emergency/presentation/screens/brigades_screen.dart';
import '../features/emergency/presentation/screens/help_confirmation_screen.dart';
import '../features/emergency/models/emergency_action_option.dart';

import '../features/emergency/models/emergency_action_type.dart';
import '../features/emergency/presentation/screens/emergency_actions_screen.dart';

import 'app_mode_controller.dart';
import 'app_mode_destination.dart';

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

import 'package:hackaton_veci_pulso/shared/widgets/feedback/feature_placeholder_screen.dart';

import '../features/publications/models/publication_draft.dart';
import '../features/publications/presentation/screens/publication_type_screen.dart';
import '../features/publications/presentation/screens/publication_details_screen.dart';
import '../features/publications/presentation/screens/publication_success_screen.dart';

GoRouter createRouter({AppModeController? modeController}) {
  final controller = PublicationDraftController();
  final mode = modeController ?? AppModeController();
  return GoRouter(
    redirect: (_, state) {
      final path = state.uri.path;
      if (path == AppRoute.sos.path ||
          path == AppRoute.riskMap.path ||
          path == AppRoute.actions.path ||
          path == AppRoute.help.path ||
          path == AppRoute.brigades.path ||
          path == '/sos') {
        mode.activateSos();
      }
      if (mode.isSos && path == AppRoute.home.path) return AppRoute.sos.path;
      if (mode.isSos && path == AppRoute.map.path) return AppRoute.riskMap.path;
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
        builder: (context, state, shell) => ChangeNotifierProvider.value(
          value: mode,
          child: AppShell(shell: shell, path: state.uri.path),
        ),
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
                  pageBuilder: (context, state) => NoTransitionPage(
                    key: ValueKey(tab.name),
                    child: tab == AppRoute.home || tab == AppRoute.map
                        ? AppModeDestination(map: tab == AppRoute.map)
                        : tab == AppRoute.publish
                        ? PublicationTypeScreen(controller: controller)
                        : FeaturePlaceholderScreen(title: tab.title),
                  ),
                ),
                if (tab == AppRoute.home || tab == AppRoute.map)
                  GoRoute(
                    path: tab == AppRoute.home
                        ? AppRoute.sos.path
                        : AppRoute.riskMap.path,
                    pageBuilder: (_, state) => NoTransitionPage(
                      key: ValueKey(tab.name),
                      child: AppModeDestination(map: tab == AppRoute.map),
                    ),
                  ),
                if (tab == AppRoute.home) ...[
                  GoRoute(
                    path: AppRoute.help.path,
                    builder: (_, state) => HelpConfirmationScreen(
                      category: switch (state.extra) {
                        EmergencyActionCategory category => category,
                        _ => null,
                      },
                    ),
                  ),
                  GoRoute(
                    path: AppRoute.brigades.path,
                    builder: (_, _) => const BrigadesScreen(),
                  ),
                  GoRoute(
                    path: AppRoute.actions.path,
                    builder: (_, state) => EmergencyActionsScreen(
                      initialAction: EmergencyActionType.fromParameter(
                        state.uri.queryParameters['action'],
                      ),
                    ),
                  ),
                  for (final route in [
                    AppRoute.notifications,
                    AppRoute.settings,
                  ])
                    GoRoute(
                      path: route.path,
                      builder: (_, _) =>
                          FeaturePlaceholderScreen(title: route.title),
                    ),

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
      GoRoute(path: '/sos', redirect: (_, _) => AppRoute.sos.path),
      GoRoute(path: '/publicar', redirect: (_, _) => AppRoute.publish.path),
      GoRoute(
        path: '/publicar/confirmacion',
        redirect: (_, _) => AppRoute.success.path,
      ),
      for (final route in AppRoute.values.where(
        (r) => ![
          AppRoute.solidarity,
          AppRoute.sos,
          AppRoute.actions,
          AppRoute.help,
          AppRoute.brigades,
          AppRoute.riskMap,
          AppRoute.notifications,
          AppRoute.settings,
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
