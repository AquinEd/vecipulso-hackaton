import 'package:flutter/material.dart';

import '../../data/sos_repository.dart';
import '../../models/sos_models.dart';
import '../controllers/sos_controllers.dart';
import '../controllers/help_board_controller.dart';
import 'sos_alert_views.dart';

class SosHelpBoard extends StatefulWidget {
  const SosHelpBoard({
    super.key,
    required this.repository,
    required this.alertId,
    required this.onChanged,
  });
  final SosRepository repository;
  final String alertId;
  final Future<void> Function() onChanged;
  @override
  State<SosHelpBoard> createState() => _SosHelpBoardState();
}

class _SosHelpBoardState extends State<SosHelpBoard> {
  bool acting = false;
  late final controller = HelpBoardController(widget.repository, widget.alertId)
    ..refresh();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String action(HelpStatus s) => switch (s) {
    HelpStatus.aceptada => 'Aceptar ayuda',
    HelpStatus.en_camino => 'Estoy en camino',
    HelpStatus.completada => 'Completar ayuda',
    _ => 'Cancelar ofrecimiento',
  };
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (_, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ofrecimientos de ayuda',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        if (controller.stage == SosStage.loading)
          const LinearProgressIndicator(),
        if (controller.failure != null) Text(controller.failure!.message),
        if (controller.uncertain)
          const Text(
            'Actualización sin confirmar. Actualiza las respuestas antes de decidir otra acción.',
          ),
        if (controller.data case final data?) ...[
          if (data.responses.isEmpty)
            const Text('No hay ofrecimientos visibles para tu cuenta'),
          if (openAlert(data.alert) &&
              widget.repository.userId != null &&
              data.alert.autorId != widget.repository.userId &&
              !data.responses.any(
                (r) =>
                    r.voluntarioId == widget.repository.userId &&
                    r.estado != HelpStatus.cancelada,
              ))
            FilledButton(
              onPressed: acting
                  ? null
                  : () async {
                      if (acting) return;
                      setState(() => acting = true);
                      final success = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => _Offer(controller),
                      );
                      if (mounted) setState(() => acting = false);
                      if (success == true && mounted) {
                        await controller.refresh();
                        if (mounted) await widget.onChanged();
                      }
                    },
              child: const Text('Ofrecer ayuda'),
            ),
          for (final response in data.responses)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.names[response.voluntarioId] ??
                          'Vecino de la comunidad',
                    ),
                    Text(response.estado.name.replaceAll('_', ' ')),
                    Text(
                      response.creadoEn
                          .toLocal()
                          .toIso8601String()
                          .split('.')
                          .first,
                    ),
                    if (response.mensaje?.isNotEmpty ?? false)
                      Text(response.mensaje!),
                    Wrap(
                      children: [
                        for (final target in helpTransitions(
                          response,
                          data.alert,
                          widget.repository.userId,
                          data.responses,
                        ))
                          TextButton(
                            onPressed: acting
                                ? null
                                : () async {
                                    if (acting) return;
                                    setState(() => acting = true);
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (dialog) => AlertDialog(
                                        title: Text('¿${action(target)}?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialog, false),
                                            child: const Text('Volver'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(dialog, true),
                                            child: const Text(
                                              'Confirmar acción',
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true && context.mounted) {
                                      await controller.update(
                                        response.id,
                                        target,
                                      );
                                      if (context.mounted &&
                                          controller.failure == null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Estado actualizado por el servidor',
                                                ),
                                              ),
                                            );
                                        await widget.onChanged();
                                      }
                                    }
                                    if (mounted) setState(() => acting = false);
                                  },
                            child: Text(action(target)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
        TextButton(
          onPressed: controller.stage == SosStage.loading || acting
              ? null
              : () => controller.refresh(),
          child: const Text('Actualizar respuestas'),
        ),
      ],
    ),
  );
}

class _Offer extends StatefulWidget {
  const _Offer(this.board);
  final HelpBoardController board;
  @override
  State<_Offer> createState() => _OfferState();
}

class _OfferState extends State<_Offer> {
  final controller = SosController<HelpResponse>();
  final id = newAlertId();
  String message = '';
  bool confirmed = false;
  bool attempted = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (_, _) {
      final busy = controller.stage == SosStage.loading;
      return PopScope(
        canPop: !busy,
        child: AlertDialog(
          scrollable: true,
          title: const Text('Ofrecer ayuda a esta alerta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.board.data?.alert.descripcion ?? 'Alerta comunitaria',
              ),
              AbsorbPointer(
                absorbing: busy || attempted,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Mensaje opcional',
                      ),
                      onChanged: (v) => message = v.trim(),
                    ),
                    CheckboxListTile(
                      title: const Text('Confirmo mi ofrecimiento'),
                      value: confirmed,
                      onChanged: (v) => setState(() => confirmed = v ?? false),
                    ),
                  ],
                ),
              ),
              if (busy) const LinearProgressIndicator(),
              if (controller.failure != null) ...[
                Text(controller.failure!.message),
                const Text(
                  'Si se perdió la respuesta, reintentar consultará primero el mismo UUID. Al salir, actualiza tus ofrecimientos antes de crear otro.',
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: busy || !confirmed
                  ? null
                  : () async {
                      attempted = true;
                      await controller.perform(
                        () => widget.board.offer(
                          id,
                          message.isEmpty ? null : message,
                        ),
                        write: true,
                      );
                      if (context.mounted && controller.data != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Ofrecimiento registrado por el servidor',
                            ),
                          ),
                        );
                        Navigator.pop(context, true);
                      }
                    },
              child: const Text('Confirmar ofrecimiento'),
            ),
          ],
        ),
      );
    },
  );
}
