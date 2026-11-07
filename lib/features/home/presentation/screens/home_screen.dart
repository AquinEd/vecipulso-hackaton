import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/app/app_routes.dart';
import 'package:hackaton_veci_pulso/shared/widgets/common/app_section_header.dart';
import 'package:hackaton_veci_pulso/shared/widgets/buttons/app_button.dart';
import 'package:hackaton_veci_pulso/shared/widgets/cards/app_card.dart';
import 'package:hackaton_veci_pulso/core/theme/app_spacing.dart';
import 'package:hackaton_veci_pulso/core/theme/app_colors.dart';
import 'package:hackaton_veci_pulso/core/theme/app_radius.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.medium),
    children: [
      const AppSectionHeader(title: 'Tu barrio'),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.location_on_outlined),
        title: Text('Ubicación pendiente'),
      ),
      Container(
        padding: const EdgeInsets.all(AppSpacing.large),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: const Text(
          'Servicios, favores y apoyo cerca de ti',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.large),
      const AppSectionHeader(title: 'Explora tu barrio'),
      const SizedBox(height: AppSpacing.small),
      AppCard(
        child: Column(
          children: [
            for (final (route, icon) in const [
              (AppRoute.services, Icons.storefront_outlined),
              (AppRoute.solidarity, Icons.volunteer_activism_outlined),
              (AppRoute.map, Icons.map_outlined),
            ])
              ListTile(
                leading: Icon(icon, color: AppColors.primary),
                title: Text(route.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => route == AppRoute.map
                    ? context.go(route.path)
                    : context.push(route.path),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.medium),
      AppButton(
        label: 'Modo SOS',
        icon: Icons.sos,
        sos: true,
        onPressed: () => context.push(AppRoute.sos.path),
      ),
    ],
  );
}
