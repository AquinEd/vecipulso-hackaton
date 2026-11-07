import '../../../../app/app_navigation.dart';
import '../../../../app/accessibility_controller.dart';

import 'package:provider/provider.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hackaton_veci_pulso/app/app_routes.dart';
import 'package:hackaton_veci_pulso/features/home/data/dashboard_demo_data.dart';
import 'package:hackaton_veci_pulso/features/services/models/service_preview.dart';
import 'package:hackaton_veci_pulso/shared/widgets/buttons/app_button.dart';
import 'package:hackaton_veci_pulso/shared/widgets/common/app_section_header.dart';
import 'package:hackaton_veci_pulso/features/home/presentation/widgets/home_greeting.dart';
import 'package:hackaton_veci_pulso/features/home/presentation/widgets/home_hero_banner.dart';
import 'package:hackaton_veci_pulso/features/home/presentation/widgets/home_category_selector.dart';
import 'package:hackaton_veci_pulso/features/home/presentation/widgets/nearby_service_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.services = dashboardDemoData});
  final List<ServicePreview> services;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.services.where(
      (service) => service.matches(search.text),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const HomeGreeting(),
        const SizedBox(height: 16),
        const HomeHeroBanner(),
        const SizedBox(height: 16),
        const HomeCategorySelector(),
        if (context.watch<AccessibilityController?>()?.clearInstructions ??
            false)
          const Text(
            'Escribe el nombre de un servicio y toca un resultado para ver su ficha.',
          ),
        const SizedBox(height: 12),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            hintText: 'Busca servicios o productos...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Borrar búsqueda',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(search.clear),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        const Wrap(
          spacing: 8,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppSectionHeader(title: 'Servicios cercanos'),
            Text('Datos de ejemplo'),
          ],
        ),
        const SizedBox(height: 8),
        if (matches.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No se encontraron servicios para esta búsqueda.'),
          ),
        for (final service in matches)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NearbyServiceCard(
              service: service,
              onTap: () {
                FocusScope.of(context).unfocus();
                context.push(
                  AppRoute.provider.path.replaceFirst(
                    ':id',
                    Uri.encodeComponent(service.id),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        AppButton(
          label: AppRoute.sos.title,
          icon: Icons.sos,
          sos: true,
          onPressed: () => AppNavigation.open(context, AppRoute.sos),
        ),
        if (context.watch<AccessibilityController?>()?.clearInstructions ??
            false)
          const Text(
            'Modo SOS abre el tablero de demostración. Allí puedes consultar reportes de ejemplo.',
          ),
        ExpansionTile(
          title: const Text('Pruebas de desarrollo'),
          children: [
            for (final (label, route) in const [
              ('Probar registro', AppRoute.register),
              ('Probar inicio con PIN', AppRoute.login),
            ])
              ListTile(
                title: Text(label),
                onTap: () => context.push(route.path),
              ),
          ],
        ),
      ],
    );
  }
}
