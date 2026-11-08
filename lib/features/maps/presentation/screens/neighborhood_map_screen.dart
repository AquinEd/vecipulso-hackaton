import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/common/app_section_header.dart';
import '../controllers/map_filters_controller.dart';
import '../widgets/geographic_map_canvas.dart';
import '../widgets/map_filters_panel.dart';

class NeighborhoodMapScreen extends StatefulWidget {
  const NeighborhoodMapScreen({super.key});
  @override
  State<NeighborhoodMapScreen> createState() => _NeighborhoodMapScreenState();
}

class _NeighborhoodMapScreenState extends State<NeighborhoodMapScreen> {
  final filters = MapFiltersController();
  @override
  void dispose() {
    filters.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.all(16),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (context.canPop())
                  BackButton(onPressed: () => context.pop()),
                const Expanded(
                  child: AppSectionHeader(title: 'Mapa de recursos'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MapFiltersPanel(controller: filters, showLayers: false),
            const Text('Cartografía real · puntos públicos sujetos a permisos'),
            const SizedBox(height: 8),
            GeographicMapCanvas(filters: filters),
            const SizedBox(height: 12),
            MapFiltersPanel(controller: filters, showSearch: false),
          ],
        ),
      ),
    ),
  );
}
