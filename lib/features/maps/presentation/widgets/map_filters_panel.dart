import 'package:flutter/material.dart';

import '../../../../shared/widgets/cards/app_card.dart';
import '../../models/map_point.dart';
import '../controllers/map_filters_controller.dart';
import 'map_point_style.dart';

String mapFilterLabel(MapPointLayer layer) => switch (layer) {
  MapPointLayer.comercio => 'Servicios',
  MapPointLayer.alerta => 'Alertas SOS',
  MapPointLayer.recurso => 'Recursos críticos',
  MapPointLayer.brigada => 'Grupos de apoyo',
};

class MapFiltersPanel extends StatefulWidget {
  const MapFiltersPanel({
    super.key,
    required this.controller,
    this.compact = false,
    this.showSearch = true,
    this.showLayers = true,
  });
  final MapFiltersController controller;
  final bool compact, showSearch, showLayers;
  @override
  State<MapFiltersPanel> createState() => _MapFiltersPanelState();
}

class _MapFiltersPanelState extends State<MapFiltersPanel> {
  late final search = TextEditingController(text: widget.controller.query);
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(syncText);
  }

  void syncText() {
    if (search.text != widget.controller.query) {
      search.text = widget.controller.query;
    }
  }

  @override
  void didUpdateWidget(covariant MapFiltersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(syncText);
      widget.controller.addListener(syncText);
      syncText();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(syncText);
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (_, _) {
      final filters = widget.controller;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showSearch) ...[
            TextField(
              controller: search,
              onChanged: filters.setQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por título o categoría',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar búsqueda',
                        onPressed: () => filters.setQuery(''),
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const Text(
              'Búsqueda y filtros sobre los puntos cargados de esta consulta.',
            ),
          ],
          if (widget.showLayers) ...[
            if (widget.compact)
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Todos'),
                    selected: filters.all,
                    onSelected: (_) => filters.showAll(),
                  ),
                  for (final layer in MapPointLayer.values)
                    FilterChip(
                      label: Text(mapFilterLabel(layer)),
                      selected: !filters.all && filters.layers.contains(layer),
                      onSelected: (selected) {
                        if (filters.all) {
                          filters.only(layer);
                        } else {
                          filters.setLayer(layer, selected);
                        }
                      },
                    ),
                ],
              )
            else
              AppCard(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Leyenda del mapa'),
                    ),
                    for (final layer in MapPointLayer.values)
                      CheckboxListTile(
                        title: Text(mapFilterLabel(layer)),
                        secondary: Icon(
                          pointIcon(layer),
                          color: pointColor(layer),
                        ),
                        value: filters.layers.contains(layer),
                        onChanged: (value) =>
                            filters.setLayer(layer, value ?? false),
                      ),
                    TextButton(
                      onPressed: filters.showAll,
                      child: const Text('Mostrar todos'),
                    ),
                  ],
                ),
              ),
            if (!filters.isDefault)
              TextButton(
                onPressed: filters.restore,
                child: const Text('Restaurar filtros'),
              ),
          ],
        ],
      );
    },
  );
}
