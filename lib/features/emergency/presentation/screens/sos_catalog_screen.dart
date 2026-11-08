import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../data/sos_repository.dart';
import '../../models/sos_models.dart';
import '../controllers/sos_controllers.dart';

Future<void> showResourceCatalog(
  BuildContext context,
  SosRepository repository,
) => showDialog<void>(
  context: context,
  builder: (_) => Dialog(
    child: SizedBox(
      width: 520,
      child: SosCatalogScreen(repository: repository, brigades: false),
    ),
  ),
);

class SosCatalogScreen extends StatefulWidget {
  const SosCatalogScreen({
    super.key,
    required this.repository,
    required this.brigades,
  });
  final SosRepository repository;
  final bool brigades;
  @override
  State<SosCatalogScreen> createState() => _SosCatalogScreenState();
}

class _SosCatalogScreenState extends State<SosCatalogScreen> {
  late final controller = SosCatalogController(
    widget.repository,
    widget.brigades,
  )..refresh();
  final search = TextEditingController();
  Timer? debounce;
  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    controller.dispose();
    super.dispose();
  }

  String label(Enum v) => v.name.replaceAll('_', ' ');
  Future<void> detail(String id) async {
    final c = SosController<List<String>>();
    Future<void> load() => c.perform(() async {
      if (widget.brigades) {
        final group = await widget.repository.groupDetail(id);
        final zone = await widget.repository.zoneName(group.zonaId);
        return [
          group.nombre,
          label(group.tipo),
          ?zone,
          group.especialidad ?? 'Sin especialidad publicada',
          if (group.sector != null) group.sector!,
          if (group.integrantes != null)
            'Integrantes registrados: ${group.integrantes}',
          group.contacto?.trim().isNotEmpty == true
              ? group.contacto!
              : 'Contacto no publicado',
          group.ubicacionAprox == null
              ? 'Ubicación no publicada'
              : 'Ubicación aproximada publicada',
        ];
      }
      final resource = await widget.repository.resourceDetail(id);
      final zone = await widget.repository.zoneName(resource.zonaId);
      return [
        label(resource.tipo),
        ?zone,
        resource.descripcion ?? 'Sin descripción',
        'Cantidad registrada: ${resource.cantidad}',
        resource.disponible
            ? 'Disponible según el registro'
            : 'No disponible según el registro',
        'La disponibilidad corresponde al dato publicado por el vecino.',
        resource.ubicacionAprox == null
            ? 'Ubicación no publicada'
            : 'Ubicación aproximada publicada',
      ];
    });
    unawaited(load());
    await showDialog<void>(
      context: context,
      builder: (dialog) => ListenableBuilder(
        listenable: c,
        builder: (_, _) => AlertDialog(
          scrollable: true,
          title: Text(
            widget.brigades ? 'Detalle del grupo' : 'Detalle del recurso',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.stage == SosStage.loading) const LinearProgressIndicator(),
              if (c.failure != null) Text(c.failure!.message),
              for (final text in c.data ?? <String>[]) SelectableText(text),
            ],
          ),
          actions: [
            TextButton(
              onPressed: c.stage == SosStage.loading ? null : load,
              child: const Text('Reintentar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return PopScope(
      canPop: !widget.brigades,
      onPopInvokedWithResult: (p, _) {
        if (!p && widget.brigades) context.go(AppRoute.sos.path);
      },
      child: ListenableBuilder(
        listenable: c,
        builder: (_, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                BackButton(
                  onPressed: () {
                    if (widget.brigades) {
                      context.go(AppRoute.sos.path);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
                Expanded(
                  child: Text(
                    widget.brigades
                        ? 'Grupos de Apoyo y Brigadas'
                        : 'Recursos críticos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            if (widget.brigades)
              TextField(
                controller: search,
                decoration: const InputDecoration(
                  labelText: 'Buscar por nombre',
                ),
                onChanged: (v) {
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 250), () {
                    c.query = v.trim();
                    c.offset = 0;
                    c.refresh();
                  });
                },
              ),
            Wrap(
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: widget.brigades
                      ? c.groupType == null
                      : c.resourceType == null,
                  onSelected: (_) {
                    setState(() {
                      c.groupType = null;
                      c.resourceType = null;
                      c.offset = 0;
                    });
                    c.refresh();
                  },
                ),
                if (widget.brigades)
                  for (final type in GroupType.values)
                    ChoiceChip(
                      label: Text(label(type)),
                      selected: c.groupType == type,
                      onSelected: (_) {
                        setState(() {
                          c.groupType = type;
                          c.offset = 0;
                        });
                        c.refresh();
                      },
                    )
                else
                  for (final type in ResourceType.values)
                    ChoiceChip(
                      label: Text(label(type)),
                      selected: c.resourceType == type,
                      onSelected: (_) {
                        setState(() {
                          c.resourceType = type;
                          c.offset = 0;
                        });
                        c.refresh();
                      },
                    ),
              ],
            ),
            if (c.stage == SosStage.loading)
              const Center(child: CircularProgressIndicator()),
            if (c.failure != null) Text(c.failure!.message),
            TextButton(
              onPressed: c.stage == SosStage.loading ? null : c.refresh,
              child: const Text('Actualizar'),
            ),
            if (c.data case final data?) ...[
              if (data.resources.isEmpty && data.groups.isEmpty)
                const Text('No hay registros para esta consulta'),
              for (final resource in data.resources)
                AppCard(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(label(resource.tipo)),
                    subtitle: Text(
                      resource.disponible
                          ? 'Disponible según el registro'
                          : 'No disponible según el registro',
                    ),
                    onTap: () => detail(resource.id),
                  ),
                ),
              for (final group in data.groups)
                AppCard(
                  child: ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(group.nombre),
                    subtitle: Text(group.especialidad ?? label(group.tipo)),
                    onTap: () => detail(group.id),
                  ),
                ),
              Wrap(
                children: [
                  if (c.offset > 0)
                    TextButton(
                      onPressed: () {
                        c.offset -= 50;
                        c.refresh();
                      },
                      child: const Text('Anterior'),
                    ),
                  if ((widget.brigades
                          ? data.groups.length
                          : data.resources.length) ==
                      50)
                    TextButton(
                      onPressed: () {
                        c.offset += 50;
                        c.refresh();
                      },
                      child: const Text('Siguiente'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
