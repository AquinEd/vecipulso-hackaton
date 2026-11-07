import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

class HelpDemoChatSheet extends StatelessWidget {
  const HelpDemoChatSheet({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Conversación de demostración',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          const Text(
            'Estos mensajes son ejemplos. No se enviará ningún mensaje.',
          ),
          const SizedBox(height: AppSpacing.medium),
          for (final (role, message) in const [
            ('Vecina de ejemplo', '¿Dónde podríamos encontrarnos?'),
            (
              'Voluntario de ejemplo',
              'Podríamos usar el punto de encuentro ilustrado.',
            ),
          ])
            Card(
              child: ListTile(title: Text(role), subtitle: Text(message)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    ),
  );
}
