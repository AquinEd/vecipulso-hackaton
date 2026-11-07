import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/accessibility_controller.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/navigation/guide_page.dart';

class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AccessibilityController>();
    return GuidePage(
      title: 'Accesibilidad',
      children: [
        const Text('Adaptada para todos los vecinos'),
        if (settings.clearInstructions)
          const Text(
            'Activa un ajuste y observa el ejemplo. Puedes deshacer el cambio aquí.',
          ),
        for (final (option, title, description) in const [
          (
            AccessibilityPreference.largeText,
            'Texto grande',
            'Mayor tamaño de letras',
          ),
          (
            AccessibilityPreference.highContrast,
            'Alto contraste',
            'Colores fáciles de distinguir',
          ),
          (
            AccessibilityPreference.largeButtons,
            'Botones grandes',
            'Acciones cómodas de pulsar',
          ),
          (
            AccessibilityPreference.clearInstructions,
            'Instrucciones claras',
            'Texto corto y paso a paso',
          ),
        ])
          Card(
            child: SwitchListTile(
              title: Text(title),
              subtitle: Text(description),
              value: settings.enabled(option),
              onChanged: (value) => settings.update(option, value),
            ),
          ),
        Text('Vista previa', style: Theme.of(context).textTheme.titleMedium),
        AppButton(
          label: 'Pedir ayuda',
          icon: Icons.favorite_border,
          sos: true,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Vista previa de accesibilidad. No se enviará ninguna solicitud.',
                ),
              ),
            );
          },
        ),
        TextButton(
          onPressed: settings.resetToDefaults,
          child: const Text('Restablecer ajustes'),
        ),
      ],
    );
  }
}
