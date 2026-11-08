import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/services_repository.dart';
import '../../models/service_rows.dart';
import '../controllers/services_controllers.dart';
import '../../../reviews/presentation/widgets/review_star_selector.dart';

String operationId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return [
    hex.substring(0, 8),
    hex.substring(8, 12),
    hex.substring(12, 16),
    hex.substring(16, 20),
    hex.substring(20),
  ].join('-');
}

typedef Fields = List<Widget> Function(StateSetter update);
Future<bool> operationDialog(
  BuildContext context,
  String title,
  String action,
  Fields fields,
  Future<void> Function() save,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _Operation(title: title, action: action, fields: fields, save: save),
  );
  if (confirmed == true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$title · Confirmado')));
  }
  return confirmed == true;
}

class _Operation extends StatefulWidget {
  const _Operation({
    required this.title,
    required this.action,
    required this.fields,
    required this.save,
  });
  final String title, action;
  final Fields fields;
  final Future<void> Function() save;
  @override
  State<_Operation> createState() => _OperationState();
}

class _OperationState extends State<_Operation> {
  final form = GlobalKey<FormState>();
  final controller = ServiceController<bool>();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (controller.stage == ServiceStage.loading ||
        !form.currentState!.validate()) {
      return;
    }
    await controller.load(() async {
      await widget.save();
      return true;
    }, write: true);
    if (mounted && controller.data == true) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final busy = controller.stage == ServiceStage.loading;
      return PopScope(
        canPop: !busy,
        child: AlertDialog(
          scrollable: true,
          title: Text(widget.title),
          content: Form(
            key: form,
            child: AbsorbPointer(
              absorbing: busy,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...widget.fields(setState),
                  if (busy) const LinearProgressIndicator(),
                  if (controller.failure case final error?) Text(error.message),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: busy ? null : submit,
              child: Text(widget.action),
            ),
          ],
        ),
      );
    },
  );
}

Future<bool> requestService(
  BuildContext context,
  ServicesRepository repo,
  ServiceDetail detail,
) {
  final id = operationId();
  var message = '';
  return operationDialog(
    context,
    'Solicitar servicio',
    'Enviar solicitud',
    (_) => [
      Text(detail.service.titulo),
      Text(detail.provider?.nombrePublico ?? ''),
      TextFormField(
        decoration: const InputDecoration(labelText: 'Mensaje opcional'),
        onChanged: (v) => message = v.trim(),
      ),
    ],
    () async {
      await repo.requests.create(
        id,
        detail.service.id,
        message: message.isEmpty ? null : message,
      );
    },
  );
}

Future<bool> reviewService(
  BuildContext context,
  ServicesRepository repo,
  SentRequest request,
) {
  var stars = 0, comment = '';
  final id = operationId();
  return operationDialog(
    context,
    'Recomendar servicio',
    'Enviar recomendación',
    (update) => [
      Text(request.servicio),
      Text(request.proveedor),
      FormField<int>(
        validator: (_) =>
            stars < 1 || stars > 5 ? 'Selecciona de 1 a 5 estrellas' : null,
        builder: (f) => Column(
          children: [
            ReviewStarSelector(
              value: stars,
              onChanged: (v) => update(() => stars = v),
            ),
            if (f.errorText != null) Text(f.errorText!),
          ],
        ),
      ),
      TextFormField(
        maxLength: 300,
        decoration: const InputDecoration(labelText: 'Comentario opcional'),
        onChanged: (v) => comment = v.trim(),
        validator: (v) =>
            (v ?? '').characters.length > 300 ? 'Máximo 300 caracteres' : null,
      ),
    ],
    () async {
      await repo.recommendations.recommend(
        id,
        request.servicioId,
        stars,
        comment: comment.isEmpty ? null : comment,
      );
    },
  );
}

List<RequestStatus> transitions(
  RequestStatus status, {
  required bool provider,
}) {
  if (status != RequestStatus.solicitada &&
      status != RequestStatus.contactado) {
    return [];
  }
  return [
    if (provider && status == RequestStatus.solicitada)
      RequestStatus.contactado,
    if (provider) RequestStatus.completada,
    RequestStatus.cancelada,
  ];
}

Future<void> openRequests(BuildContext context, ServicesRepository repo) =>
    showDialog<void>(context: context, builder: (_) => _Requests(repo));

class _Requests extends StatefulWidget {
  const _Requests(this.repo);
  final ServicesRepository repo;
  @override
  State<_Requests> createState() => _RequestsState();
}

class _RequestsState extends State<_Requests> {
  late final sent = SentRequestsController(widget.repo.requests)..refresh();
  late final received = ReceivedRequestsController(widget.repo.requests);
  bool incoming = false;
  @override
  void dispose() {
    sent.dispose();
    received.dispose();
    super.dispose();
  }

  String date(DateTime value) =>
      value.toLocal().toIso8601String().split('T').first;
  Future<void> refresh() => incoming ? received.refresh() : sent.refresh();
  Widget item(
    String id,
    String title,
    String party,
    RequestStatus status,
    DateTime time, {
    String? message,
    SentRequest? eligible,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text(party),
            Text('${date(time)} · ${status.name}'),
            if (message != null) Text(message),
            Wrap(
              children: [
                for (final target in transitions(status, provider: incoming))
                  TextButton(
                    onPressed: () async {
                      final ok = await operationDialog(
                        context,
                        title,
                        'Confirmar',
                        (_) => [
                          Text('Cambiar de ${status.name} a ${target.name}'),
                        ],
                        () async {
                          await widget.repo.requests.transition(id, target);
                        },
                      );
                      if (ok && mounted) await refresh();
                    },
                    child: Text(switch (target) {
                      RequestStatus.contactado => 'Marcar contactado',
                      RequestStatus.completada => 'Completar',
                      _ => 'Cancelar solicitud',
                    }),
                  ),
                if (eligible != null)
                  TextButton(
                    onPressed: () async {
                      if (await reviewService(context, widget.repo, eligible) &&
                          mounted) {
                        await refresh();
                      }
                    },
                    child: const Text('Recomendar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ServiceController<List<Object>> c = incoming ? received : sent;
    return ListenableBuilder(
      listenable: c,
      builder: (_, _) => AlertDialog(
        scrollable: true,
        title: const Text('Mis solicitudes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              children: [
                for (final v in [false, true])
                  ChoiceChip(
                    label: Text(v ? 'Recibidas' : 'Enviadas'),
                    selected: incoming == v,
                    onSelected: (_) {
                      setState(() => incoming = v);
                      refresh();
                    },
                  ),
              ],
            ),
            if (c.stage == ServiceStage.loading)
              const LinearProgressIndicator(),
            if (c.failure != null) Text(c.failure!.message),
            if (c.stage == ServiceStage.empty) const Text('No hay solicitudes'),
            if (incoming)
              for (final r in received.data ?? <ReceivedRequest>[])
                item(
                  r.id,
                  r.servicio,
                  r.solicitante,
                  r.estado,
                  r.creadoEn,
                  message: r.mensaje,
                )
            else
              for (final r in sent.data ?? <SentRequest>[])
                item(
                  r.id,
                  r.servicio,
                  r.proveedor,
                  r.estado,
                  r.creadoEn,
                  eligible: r.puedoRecomendar ? r : null,
                ),
          ],
        ),
        actions: [
          TextButton(onPressed: refresh, child: const Text('Actualizar')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
