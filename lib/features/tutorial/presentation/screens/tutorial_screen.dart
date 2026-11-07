import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/accessibility_controller.dart';
import '../../../../shared/widgets/navigation/guide_page.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});
  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int step = 0;
  static const steps = [
    (
      Icons.storefront_outlined,
      'Encuentra cerca',
      'Busca productos y oficios de tu barrio.',
      'Abre Servicios del Barrio desde el menú. Busca un proveedor y filtra por categoría. Los proveedores son datos de demostración.',
    ),
    (
      Icons.favorite_border,
      'Comparte y recibe',
      'Presta, dona, intercambia y solicita favores en pocos pasos.',
      'Consulta Cadena de Favores en el menú. En la pestaña Publicar puedes preparar un ejemplo. Las publicaciones son demostraciones locales.',
    ),
    (
      Icons.warning_rounded,
      'Actúa en emergencias',
      'Conoce las herramientas comunitarias de apoyo y coordinación.',
      'Desde Modo SOS puedes explorar las brigadas de ejemplo y consultar los reportes ilustrativos en el mapa de emergencia.',
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GuidePage(
      title: 'Tutorial de uso',
      children: [
        Text('Aprende a usar VeciPulso', style: theme.textTheme.titleLarge),
        const Text('Guía rápida para todos los vecinos'),
        if (context.watch<AccessibilityController?>()?.clearInstructions ??
            false)
          const Text(
            'Lee el paso seleccionado. Pulsa Siguiente para destacar el próximo.',
          ),
        for (final (i, item) in steps.indexed)
          Semantics(
            selected: step == i,
            child: Card(
              shape: step == i
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    )
                  : null,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => step = i),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item.$1,
                        color: i == 2
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 6,
                          children: [
                            Text(
                              '${i + 1}. ${item.$2}',
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(item.$3),
                            if (step == i) Text(item.$4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const Text(
          'Las funciones SOS actuales son demostraciones. No sustituyen a los servicios oficiales de emergencia.',
        ),
        Semantics(liveRegion: true, child: Text('Paso ${step + 1} de 3')),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: step == 0 ? null : () => setState(() => step--),
              child: const Text('Anterior'),
            ),
            if (step < 2)
              FilledButton(
                onPressed: () => setState(() => step++),
                child: const Text('Siguiente'),
              ),
          ],
        ),
        if (step == 2)
          FilledButton(
            onPressed: () => GuidePage.close(context),
            child: const Text('Entendido, comenzar'),
          ),
      ],
    );
  }
}
