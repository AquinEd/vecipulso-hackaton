import 'package:flutter/material.dart';
import 'package:hackaton_veci_pulso/shared/widgets/common/app_section_header.dart';

class HomeGreeting extends StatelessWidget {
  const HomeGreeting({
    super.key,
    this.name = 'vecino',
    this.location = 'Ubicación por configurar',
  });
  final String name, location;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppSectionHeader(title: '¡Hola, $name!'),
      const SizedBox(height: 6),
      Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Expanded(child: Text(location)),
        ],
      ),
    ],
  );
}
