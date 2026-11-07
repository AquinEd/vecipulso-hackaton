import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/common/app_section_header.dart';
import '../../data/demo_map_markers.dart';
import '../../models/community_map_marker.dart';
import '../widgets/neighborhood_map_canvas.dart';

class NeighborhoodMapScreen extends StatefulWidget {
  const NeighborhoodMapScreen({super.key});
  @override
  State<NeighborhoodMapScreen> createState() => _NeighborhoodMapScreenState();
}

class _NeighborhoodMapScreenState extends State<NeighborhoodMapScreen> {
  final search = TextEditingController();
  final categories = MapCategory.values.toSet();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> showMarker(CommunityMapMarker marker) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final openProvider = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionHeader(title: marker.title),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  marker.category.icon,
                  color: marker.category.color,
                ),
                title: Text(marker.category.label),
              ),
              Text(marker.description),
              const SizedBox(height: 8),
              const Chip(label: Text('Dato de demostración')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  if (marker.serviceId != null)
                    AppButton(
                      label: 'Ver proveedor',
                      icon: Icons.storefront,
                      onPressed: () => Navigator.pop(sheet, true),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(sheet),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (openProvider == true && mounted) {
      context.push(
        AppRoute.provider.path.replaceFirst(':id', marker.serviceId!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = demoMapMarkers
        .where((m) => categories.contains(m.category) && m.matches(search.text))
        .toList();
    return SingleChildScrollView(
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
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar en esta zona...',
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
              const SizedBox(height: 8),
              Text(
                'Mapa ilustrativo · Ubicaciones de ejemplo',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              NeighborhoodMapCanvas(markers: markers, onSelect: showMarker),
              const SizedBox(height: 12),
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionHeader(title: 'Leyenda del mapa'),
                      for (final category in MapCategory.values)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(category.label),
                          secondary: Icon(category.icon, color: category.color),
                          value: categories.contains(category),
                          onChanged: (show) => setState(() {
                            if (show == true) {
                              categories.add(category);
                            } else {
                              categories.remove(category);
                            }
                          }),
                        ),
                      if (categories.length != MapCategory.values.length)
                        TextButton(
                          onPressed: () => setState(
                            () => categories.addAll(MapCategory.values),
                          ),
                          child: const Text('Restablecer categorías'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
