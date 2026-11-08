import 'package:flutter/material.dart';

import '../../data/services_repository.dart';
import '../../models/service_rows.dart';
import '../controllers/services_controllers.dart';
import 'service_operations.dart';

Future<bool> editService(
  BuildContext context,
  ServicesRepository repo,
  List<ServiceCategoryRow> categories, {
  ServiceRow? existing,
}) {
  var title = existing?.titulo ?? '',
      description = existing?.descripcion ?? '',
      active = existing?.activo ?? true;
  int? category = existing?.categoriaId;
  final id = existing?.id ?? operationId();
  return operationDialog(
    context,
    existing == null ? 'Ofrecer un servicio' : 'Editar servicio',
    'Guardar',
    (set) => [
      TextFormField(
        initialValue: title,
        decoration: const InputDecoration(labelText: 'Nombre del servicio'),
        maxLength: 120,
        onChanged: (v) => title = v,
        validator: (v) => (v ?? '').trim().runes.length < 3
            ? 'Escribe al menos 3 caracteres'
            : null,
      ),
      if (existing == null)
        DropdownButtonFormField<int>(
          initialValue: category,
          decoration: const InputDecoration(labelText: 'Categoría'),
          items: [
            for (final c in categories)
              DropdownMenuItem(value: c.id, child: Text(c.nombre)),
          ],
          onChanged: (v) => set(() => category = v),
          validator: (v) => !categories.any((c) => c.id == v)
              ? 'Selecciona una categoría disponible'
              : null,
        ),
      TextFormField(
        initialValue: description,
        decoration: const InputDecoration(labelText: 'Descripción opcional'),
        onChanged: (v) => description = v,
      ),
      if (existing != null)
        SwitchListTile(
          title: const Text('Servicio activo'),
          value: active,
          onChanged: (v) => set(() => active = v),
        ),
    ],
    () async {
      if (existing == null) {
        await repo.publish(
          id: id,
          categoryId: category!,
          title: title,
          description: description.trim(),
        );
      } else {
        await repo.update(
          id,
          title: title,
          description: description.trim(),
          years: existing.aniosExperiencia,
          active: active,
        );
      }
    },
  );
}

Future<void> openOwned(
  BuildContext context,
  ServicesRepository repo,
  List<ServiceCategoryRow> categories,
) async {
  final c = ServiceController<List<ServiceRow>>()..load(repo.mine);
  await showDialog<void>(
    context: context,
    builder: (dialog) => ListenableBuilder(
      listenable: c,
      builder: (_, _) => AlertDialog(
        scrollable: true,
        title: const Text('Mis servicios'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (c.stage == ServiceStage.loading)
              const LinearProgressIndicator(),
            if (c.failure != null) Text(c.failure!.message),
            if (c.stage == ServiceStage.empty)
              const Text('Aún no publicaste servicios'),
            for (final s in c.data ?? <ServiceRow>[])
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(s.titulo),
                      subtitle: Text(
                        [
                          categories
                              .where((x) => x.id == s.categoriaId)
                              .firstOrNull
                              ?.nombre,
                          s.descripcion,
                          s.activo ? 'Activo' : 'Inactivo',
                        ].nonNulls.join(' · '),
                      ),
                    ),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: () async {
                            if (await editService(
                                  dialog,
                                  repo,
                                  categories,
                                  existing: s,
                                ) &&
                                dialog.mounted) {
                              await c.load(repo.mine);
                            }
                          },
                          child: const Text('Editar'),
                        ),
                        TextButton(
                          onPressed: () {
                            var phone = '';
                            var consent = false;
                            operationDialog(
                              dialog,
                              'Actualizar contacto',
                              'Guardar',
                              (set) => [
                                TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Teléfono',
                                  ),
                                  keyboardType: TextInputType.phone,
                                  onChanged: (v) => phone = v.trim(),
                                  validator: (v) =>
                                      RegExp(r'^[0-9+ ]{6,15}$')
                                          .hasMatch((v ?? '').trim())
                                      ? null
                                      : 'Introduce un teléfono válido',
                                ),
                                CheckboxListTile(
                                  title: const Text(
                                    'Mostrar este teléfono a los vecinos de mi zona',
                                  ),
                                  value: consent,
                                  onChanged: (v) =>
                                      set(() => consent = v ?? false),
                                ),
                              ],
                              () => repo.saveContact(s.id, phone, consent),
                            );
                          },
                          child: const Text('Contacto'),
                        ),
                        TextButton(
                          onPressed: () {
                            var title = '';
                            final id = operationId();
                            operationDialog(
                              dialog,
                              'Añadir trabajo',
                              'Guardar',
                              (_) => [
                                TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Trabajo realizado',
                                  ),
                                  onChanged: (v) => title = v.trim(),
                                  validator: (v) => (v ?? '').trim().isEmpty
                                      ? 'Escribe un título'
                                      : null,
                                ),
                              ],
                              () => repo.addWork(s.id, title, id),
                            );
                          },
                          child: const Text('Añadir trabajo'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => c.load(repo.mine),
            child: const Text('Actualizar'),
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
