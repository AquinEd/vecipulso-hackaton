import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../data/demo_services.dart';
import '../widgets/service_heading.dart';
import '../widgets/service_list_card.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final search = TextEditingController();
  int? maxMeters;
  bool fourStars = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = demoServices.where(
      (s) => s.matches(search.text, maxMeters: maxMeters, fourStars: fourStars),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        ServiceHeading(
          title: 'Servicios de Proximidad',
          fallback: AppRoute.home.path,
        ),
        TextField(
          controller: search,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar oficio o profesional...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Borrar búsqueda',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(search.clear),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (label, meters) in const [
                ('Todos', null),
                ('Hasta 500 m', 500),
                ('1 km', 1000),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(label),
                    showCheckmark: false,
                    selected:
                        maxMeters == meters && (meters != null || !fourStars),
                    onSelected: (_) => setState(() {
                      maxMeters = meters;
                      if (meters == null) fourStars = false;
                    }),
                  ),
                ),
              FilterChip(
                label: const Text('4+ estrellas'),
                selected: fourStars,
                onSelected: (value) => setState(() => fourStars = value),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(demoNotice, style: Theme.of(context).textTheme.bodySmall),
        ),
        if (matches.isEmpty)
          const Text('No se encontraron servicios para esta búsqueda.'),
        for (final service in matches)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ServiceListCard(
              service: service,
              directory: true,
              onTap: () {
                FocusScope.of(context).unfocus();
                context.push(
                  AppRoute.provider.path.replaceFirst(
                    ':id',
                    Uri.encodeComponent(service.id),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
