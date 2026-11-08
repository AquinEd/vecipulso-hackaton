import 'dart:async';

import '../widgets/service_operations.dart';
import '../widgets/service_editor.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_routes.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../data/services_repository.dart';
import '../controllers/services_controllers.dart';
import '../widgets/service_heading.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ServicesRepository?>();
    if (repo == null) {
      return ListView(
        children: [
          ServiceHeading(
            title: 'Servicios de Proximidad',
            fallback: AppRoute.home.path,
          ),
          Text(ServicesFailure.session.message),
        ],
      );
    }
    return ChangeNotifierProvider(
      create: (_) => DirectoryController(repo)..refresh(),
      child: const _Directory(),
    );
  }
}

class _Directory extends StatefulWidget {
  const _Directory();
  @override
  State<_Directory> createState() => _DirectoryState();
}

class _DirectoryState extends State<_Directory> {
  final search = TextEditingController();
  Timer? debounce;
  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DirectoryController>();
    void filter(int? category) {
      debounce?.cancel();
      c.filter(search.text, category);
    }

    final entries = c.data ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        ServiceHeading(
          title: 'Servicios de Proximidad',
          fallback: AppRoute.home.path,
        ),
        Wrap(
          children: [
            TextButton(
              onPressed: c.categories.isEmpty
                  ? null
                  : () async {
                      if (await editService(
                            context,
                            c.repository,
                            c.categories,
                          ) &&
                          context.mounted) {
                        search.clear();
                        await c.filter('', null);
                        if (context.mounted) {
                          await openOwned(context, c.repository, c.categories);
                          if (context.mounted) await c.refresh();
                        }
                      }
                    },
              child: const Text('Ofrecer un servicio'),
            ),
            TextButton(
              onPressed: () async {
                await openOwned(context, c.repository, c.categories);
                if (context.mounted) await c.refresh();
              },
              child: const Text('Mis servicios'),
            ),
            TextButton(
              onPressed: () async {
                await openRequests(context, c.repository);
                if (context.mounted) await c.refresh();
              },
              child: const Text('Mis solicitudes'),
            ),
          ],
        ),
        TextField(
          controller: search,
          onChanged: (value) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 250), () {
              if (value.trim().replaceAll(RegExp(r'\s+'), ' ') != c.query) {
                filter(c.categoryId);
              }
            });
          },
          decoration: InputDecoration(
            hintText: 'Buscar por título del servicio',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Borrar búsqueda',
              icon: const Icon(Icons.clear),
              onPressed: () {
                search.clear();
                filter(c.categoryId);
              },
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: c.categoryId == null,
              onSelected: (selected) {
                if (selected) filter(null);
              },
            ),
            for (final cat in c.categories)
              ChoiceChip(
                label: Text(cat.nombre),
                selected: c.categoryId == cat.id,
                onSelected: (selected) {
                  if (selected) filter(cat.id);
                },
              ),
          ],
        ),
        Row(
          children: [
            const Expanded(child: Text('Servicios de tu zona')),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: () => c.refresh(reloadCategories: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (c.stage == ServiceStage.loading)
          const Center(child: CircularProgressIndicator()),
        if (c.failure != null) ...[
          Text(c.failure!.message),
          TextButton(
            onPressed: () => c.refresh(reloadCategories: true),
            child: const Text('Reintentar'),
          ),
        ],
        if (c.stage == ServiceStage.empty) ...[
          const Text('No se encontraron servicios para esta búsqueda.'),
          TextButton(
            onPressed: () {
              search.clear();
              filter(null);
            },
            child: const Text('Limpiar filtros'),
          ),
        ],
        for (final e in entries.take(ServicesRepository.pageSize))
          AppCard(
            child: ListTile(
              leading: const Icon(Icons.storefront),
              title: Text(e.service.titulo),
              subtitle: Text(
                [
                  for (final cat in c.categories)
                    if (cat.id == e.service.categoriaId) cat.nombre,
                  if (e.count == 0)
                    'Sin valoraciones'
                  else
                    '${e.count} recomendaciones',
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await context.push(
                  AppRoute.provider.path.replaceFirst(':id', e.service.id),
                );
                if (context.mounted) await c.refresh();
              },
            ),
          ),
        if (c.data != null)
          Wrap(
            children: [
              if (c.offset > 0)
                TextButton(
                  onPressed: () {
                    c.offset -= ServicesRepository.pageSize;
                    c.refresh();
                  },
                  child: const Text('Anterior'),
                ),
              if (entries.length > ServicesRepository.pageSize)
                TextButton(
                  onPressed: () {
                    c.offset += ServicesRepository.pageSize;
                    c.refresh();
                  },
                  child: const Text('Siguiente'),
                ),
            ],
          ),
      ],
    );
  }
}
