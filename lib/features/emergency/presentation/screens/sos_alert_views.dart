import 'dart:math';

import 'sos_catalog_screen.dart';

import 'sos_help_board.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_navigation.dart';
import '../../../../app/app_routes.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/common/app_section_header.dart';
import '../../data/sos_repository.dart';
import '../../models/sos_models.dart';
import '../controllers/sos_controllers.dart';
import '../controllers/alert_emission_controller.dart';

const sosNotice =
    'VeciPulso brinda coordinación comunitaria y no sustituye los servicios oficiales de emergencia.';
String newAlertId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

String alertState(AlertStatus status) => status == AlertStatus.verificada
    ? 'Confirmada por vecinos'
    : status.name.replaceAll('_', ' ');
String label(Enum value) => value.name.replaceAll('_', ' ');
bool openAlert(SosAlert alert) =>
    [AlertStatus.sin_verificar, AlertStatus.verificada].contains(alert.estado);
Future<void> showSosDetail(
  BuildContext context,
  SosRepository repository,
  String id,
) => showDialog<void>(
  context: context,
  builder: (_) => ChangeNotifierProvider(
    create: (_) => AlertDetailController(repository)..refresh(id),
    child: _AlertDetail(id),
  ),
);

class _AlertDetail extends StatelessWidget {
  const _AlertDetail(this.id);
  final String id;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<AlertDetailController>();
    return AlertDialog(
      scrollable: true,
      title: const Text('Detalle de alerta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.stage == SosStage.loading) const LinearProgressIndicator(),
          if (c.failure != null) Text(c.failure!.message),
          if (c.data case final alert?) ...[
            Text(label(alert.tipo)),
            Text(label(alert.urgencia)),
            Text(alert.descripcion ?? 'Sin descripción'),
            Text(alertState(alert.estado)),
            Text(alert.creadoEn.toLocal().toIso8601String().split('.').first),
            const Text('Ubicación aproximada de la zona'),
            SosHelpBoard(
              key: ValueKey(alert.id),
              repository: c.repository,
              alertId: alert.id,
              onChanged: () => c.refresh(id),
            ),
            if (alert.autorId == c.repository.userId && openAlert(alert))
              TextButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialog) => AlertDialog(
                      title: const Text('¿Cancelar esta alerta?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('Volver'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: const Text('Confirmar cancelación'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) await c.cancel(id);
                },
                child: const Text('Cancelar mi alerta'),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: c.stage == SosStage.loading ? null : () => c.refresh(id),
          child: const Text('Actualizar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class LiveSosDashboard extends StatefulWidget {
  const LiveSosDashboard({super.key, required this.repository});
  final SosRepository repository;
  @override
  State<LiveSosDashboard> createState() => _LiveSosDashboardState();
}

class _LiveSosDashboardState extends State<LiveSosDashboard> {
  late final controller = AlertsController(widget.repository);
  bool mine = false;
  int offset = 0;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() => controller.refresh(mine: mine, offset: offset);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (_, _) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AppSectionHeader(title: 'Modo Emergencia'),
        const Text(sosNotice),
        Wrap(
          children: [
            TextButton(
              onPressed: () => showResourceCatalog(context, widget.repository),
              child: const Text('Recursos críticos'),
            ),
            TextButton(
              onPressed: () => AppNavigation.open(context, AppRoute.brigades),
              child: const Text('Grupos y Brigadas'),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: () async {
            await showDialog<void>(
              context: context,
              builder: (_) => AlertEmissionForm(repository: widget.repository),
            );
            if (mounted) {
              offset = 0;
              await refresh();
            }
          },
          icon: const Icon(Icons.warning_rounded),
          label: const Text('Emitir alerta'),
        ),
        TextButton(
          onPressed: () => AppNavigation.open(context, AppRoute.actions),
          child: const Text('Centro de ayuda vecinal'),
        ),
        Wrap(
          children: [
            for (final value in [false, true])
              ChoiceChip(
                label: Text(value ? 'Mis alertas' : 'Alertas de mi zona'),
                selected: mine == value,
                onSelected: (_) {
                  setState(() {
                    mine = value;
                    offset = 0;
                  });
                  refresh();
                },
              ),
          ],
        ),
        if (controller.stage == SosStage.loading)
          const Center(child: CircularProgressIndicator()),
        if (controller.failure != null) Text(controller.failure!.message),
        TextButton(onPressed: refresh, child: const Text('Actualizar alertas')),
        if (controller.stage == SosStage.empty)
          const Text('No hay alertas disponibles'),
        for (final alert in controller.data ?? <SosAlert>[])
          AppCard(
            child: ListTile(
              title: Text(label(alert.tipo)),
              subtitle: Text(
                '${alertState(alert.estado)} · ${alert.creadoEn.toLocal().toIso8601String().split('T').first}',
              ),
              onTap: () async {
                await showSosDetail(context, widget.repository, alert.id);
                if (mounted) await refresh();
              },
            ),
          ),
        Wrap(
          children: [
            if (offset > 0)
              TextButton(
                onPressed: () {
                  offset -= 50;
                  refresh();
                },
                child: const Text('Anterior'),
              ),
            if ((controller.data?.length ?? 0) == 50)
              TextButton(
                onPressed: () {
                  offset += 50;
                  refresh();
                },
                child: const Text('Siguiente'),
              ),
          ],
        ),
        TextButton(
          onPressed: () => AppNavigation.exitSos(context),
          child: const Text('Salir del Modo SOS'),
        ),
      ],
    ),
  );
}

class AlertEmissionForm extends StatefulWidget {
  const AlertEmissionForm({super.key, required this.repository});
  final SosRepository repository;
  @override
  State<AlertEmissionForm> createState() => _AlertEmissionFormState();
}

class _AlertEmissionFormState extends State<AlertEmissionForm> {
  final form = GlobalKey<FormState>();
  late final controller = AlertEmissionController(
    widget.repository,
    newAlertId(),
  );
  AlertClass kind = AlertClass.alerta;
  EmergencyType? type;
  AlertUrgency urgency = AlertUrgency.urgente;
  String description = '';
  bool confirmed = false;
  List<EmergencyType> get types => kind == AlertClass.alerta
      ? [
          EmergencyType.sismo,
          EmergencyType.incendio,
          EmergencyType.seguridad,
          EmergencyType.salud,
          EmergencyType.dano_vivienda,
          EmergencyType.otro,
        ]
      : [
          EmergencyType.persona_atrapada,
          EmergencyType.salud,
          EmergencyType.agua_alimentos,
          EmergencyType.traslado_refugio,
          EmergencyType.otro,
        ];
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (_, _) => PopScope(
      canPop: !controller.busy,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Emitir alerta comunitaria'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(sosNotice),
              if (controller.data case final id?) ...[
                const Text('Alerta registrada por el servidor'),
                SelectableText(id),
              ] else ...[
                AbsorbPointer(
                  absorbing: controller.busy || controller.attempted,
                  child: Column(
                    children: [
                      DropdownButtonFormField<AlertClass>(
                        initialValue: kind,
                        decoration: const InputDecoration(labelText: 'Clase'),
                        items: [
                          for (final value in AlertClass.values)
                            DropdownMenuItem(
                              value: value,
                              child: Text(label(value)),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          kind = value!;
                          type = null;
                        }),
                      ),
                      DropdownButtonFormField<EmergencyType>(
                        key: ValueKey(kind),
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de emergencia',
                        ),
                        items: [
                          for (final value in types)
                            DropdownMenuItem(
                              value: value,
                              child: Text(label(value)),
                            ),
                        ],
                        onChanged: (value) => setState(() => type = value),
                        validator: (value) =>
                            value == null || !types.contains(value)
                            ? 'Selecciona un tipo válido'
                            : null,
                      ),
                      DropdownButtonFormField<AlertUrgency>(
                        initialValue: urgency,
                        decoration: const InputDecoration(
                          labelText: 'Urgencia',
                        ),
                        items: [
                          for (final value in AlertUrgency.values)
                            DropdownMenuItem(
                              value: value,
                              child: Text(label(value)),
                            ),
                        ],
                        onChanged: (value) => setState(() => urgency = value!),
                      ),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Descripción opcional',
                        ),
                        maxLines: 3,
                        onChanged: (value) => description = value.trim(),
                      ),
                      const Text(
                        'Se utilizará el centro aproximado de tu zona registrada.',
                      ),
                      CheckboxListTile(
                        title: const Text(
                          'Confirmo que deseo registrar esta alerta',
                        ),
                        value: confirmed,
                        onChanged: (value) =>
                            setState(() => confirmed = value ?? false),
                      ),
                    ],
                  ),
                ),
                if (controller.busy) const LinearProgressIndicator(),
                if (controller.failure != null)
                  Text(controller.failure!.message),
                if (controller.uncertain) ...[
                  const Text(
                    'Envío sin confirmar. Al reintentar se consultará primero si la alerta ya existe. Si cierras este formulario, consulta Mis alertas antes de iniciar otro envío.',
                  ),
                  SelectableText(controller.id),
                ],
              ],
            ],
          ),
        ),
        actions: [
          if (controller.data == null)
            FilledButton(
              onPressed: controller.busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate() || !confirmed) {
                        if (!confirmed) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Confirma el registro de la alerta',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      await controller.send(
                        kind: kind,
                        type: type!,
                        urgency: urgency,
                        description: description.isEmpty ? null : description,
                      );
                    },
              child: Text(
                controller.uncertain
                    ? 'Comprobar y reintentar'
                    : 'Registrar alerta',
              ),
            ),
          TextButton(
            onPressed: controller.busy ? null : () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    ),
  );
}
