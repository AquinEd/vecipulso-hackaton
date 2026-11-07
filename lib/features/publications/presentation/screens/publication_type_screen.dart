import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/common/app_section_header.dart';
import '../../../solidarity/models/solidarity_post.dart';
import '../../data/publication_templates.dart';
import '../../models/publication_draft.dart';

class PublicationTypeScreen extends StatefulWidget {
  const PublicationTypeScreen({super.key, required this.controller});
  final PublicationDraftController controller;
  @override
  State<PublicationTypeScreen> createState() => _TypeState();
}

class _TypeState extends State<PublicationTypeScreen> {
  bool opening = false;
  @override
  Widget build(BuildContext context) {
    final selected = widget.controller.draft?.type ?? PostType.need;
    Future<void> open(PostType type) async {
      if (opening) return;
      opening = true;
      setState(() => widget.controller.select(type));
      try {
        await context.push<void>(AppRoute.details.path);
      } finally {
        opening = false;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BackButton(onPressed: () => context.go(AppRoute.home.path)),
              const Expanded(
                child: AppSectionHeader(title: 'Publicación rápida'),
              ),
            ],
          ),
          const Text('En un máximo de tres acciones principales'),
          const SizedBox(height: 24),
          const Text('Paso 1 de 3', style: TextStyle(color: AppColors.primary)),
          const AppSectionHeader(title: '¿Qué quieres publicar?'),
          const SizedBox(height: 16),
          for (final entry in publicationTemplates.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: entry.key == selected ? const Color(0xffeff9f5) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: entry.key == selected
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  selected: entry.key == selected,
                  leading: Builder(
                    builder: (context) {
                      final (icon, color) = switch (entry.key) {
                        PostType.need => (
                          Icons.favorite_border,
                          AppColors.primary,
                        ),
                        PostType.offer => (
                          Icons.groups_outlined,
                          AppColors.map,
                        ),
                        PostType.donation => (
                          Icons.inventory_2_outlined,
                          AppColors.warning,
                        ),
                        _ => (Icons.swap_horiz, Colors.deepPurple),
                      };
                      return CircleAvatar(
                        backgroundColor: color.withValues(alpha: .09),
                        child: Icon(icon, color: color),
                      );
                    },
                  ),
                  title: Text(
                    entry.value.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(entry.value.hint),
                  onTap: () => open(entry.key),
                ),
              ),
            ),
          AppButton(
            label: 'Siguiente',
            icon: Icons.arrow_forward,
            onPressed: () => open(selected),
          ),
        ],
      ),
    );
  }
}
