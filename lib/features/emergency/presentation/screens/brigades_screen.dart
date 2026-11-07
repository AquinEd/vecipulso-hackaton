import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/common/app_section_header.dart';
import '../../../../shared/widgets/common/app_text_field.dart';
import '../../data/demo_brigades.dart';
import '../../models/community_brigade.dart';
import '../widgets/brigade_card.dart';

class BrigadesScreen extends StatefulWidget {
  const BrigadesScreen({super.key, this.groups = demoBrigades});
  final List<CommunityBrigade> groups;

  @override
  State<BrigadesScreen> createState() => _BrigadesScreenState();
}

class _BrigadesScreenState extends State<BrigadesScreen> {
  final search = TextEditingController();
  BrigadeType? filter;
  bool contactOpen = false;

  @override
  void initState() {
    super.initState();
    search.addListener(refresh);
  }

  void refresh() => setState(() {});

  @override
  void dispose() {
    search.removeListener(refresh);
    search.dispose();
    super.dispose();
  }

  void reset() {
    search.clear();
    setState(() => filter = null);
  }

  Future<void> contact(CommunityBrigade group) async {
    if (contactOpen) return;
    contactOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('Contacto no disponible todavía'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                group.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.medium),
              const Text(
                'Podrás comunicarte con este grupo cuando se implemente el sistema de mensajería y contactos verificados',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } finally {
      contactOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups
        .where(
          (g) => (filter == null || g.type == filter) && g.matches(search.text),
        )
        .toList();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoute.sos.path);
      },
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.medium),
        itemCount: groups.isEmpty ? 2 : groups.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BackButton(onPressed: () => context.go(AppRoute.sos.path)),
                    const Expanded(
                      child: AppSectionHeader(
                        title: 'Grupos de Apoyo y Brigadas',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.medium),
                const Text(
                  'Grupos de demostración · Contactos no disponibles',
                  style: TextStyle(color: AppColors.secondaryText),
                ),
                const SizedBox(height: AppSpacing.medium),
                AppTextField(
                  controller: search,
                  label: 'Buscar grupos',
                  hint: 'Buscar por sector o nombre...',
                  icon: Icons.search,
                  validator: (_) => null,
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar búsqueda',
                          onPressed: search.clear,
                          icon: const Icon(Icons.close),
                        ),
                ),
                const SizedBox(height: AppSpacing.medium),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (value, label) in <(BrigadeType?, String)>[
                        (null, 'Todos'),
                        (BrigadeType.brigade, 'Brigadas'),
                        (BrigadeType.volunteers, 'Voluntarios'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(
                            right: AppSpacing.small,
                          ),
                          child: ChoiceChip(
                            shape: const StadiumBorder(),
                            label: Text(label),
                            selected: filter == value,
                            showCheckmark: true,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: filter == value
                                  ? Colors.white
                                  : AppColors.secondaryText,
                            ),
                            checkmarkColor: Colors.white,
                            onSelected: (_) => setState(() => filter = value),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
              ],
            );
          }
          if (groups.isEmpty) {
            return Column(
              children: [
                const Icon(
                  Icons.search_off,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.medium),
                const AppSectionHeader(
                  title: 'No encontramos grupos para esta búsqueda',
                ),
                const SizedBox(height: AppSpacing.small),
                const Text('Prueba con otro nombre, sector o categoría'),
                const SizedBox(height: AppSpacing.medium),
                OutlinedButton(
                  onPressed: reset,
                  child: const Text('Limpiar búsqueda y filtros'),
                ),
              ],
            );
          }
          final group = groups[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.medium),
            child: BrigadeCard(
              key: ValueKey(group.id),
              brigade: group,
              onContact: () => contact(group),
            ),
          );
        },
      ),
    );
  }
}
