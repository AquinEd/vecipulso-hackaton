import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/common/app_section_header.dart';
import '../../models/publication_draft.dart';

class PublicationSuccessScreen extends StatelessWidget {
  const PublicationSuccessScreen({super.key, required this.preview});
  final PublicationDraft preview;
  @override
  Widget build(BuildContext context) {
    Widget summary({bool full = false}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          preview.category,
          style: const TextStyle(color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        AppSectionHeader(title: preview.title),
        if (full && preview.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(preview.description),
          ),
        const SizedBox(height: 12),
        const Text(PublicationDraft.neighborhood),
        const SizedBox(height: 12),
        const Text(
          'No enviada · Demostración',
          style: TextStyle(color: AppColors.primary),
        ),
      ],
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoute.home.path);
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
            children: [
              const CircleAvatar(
                radius: 54,
                backgroundColor: Color(0xffdcf5e9),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.check, size: 48, color: Colors.white),
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                child: AppSectionHeader(title: '¡Vista previa lista!'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Has completado la demostración. Tu publicación todavía no se ha enviado a otros vecinos',
              ),
              const SizedBox(height: 32),
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: summary(),
                ),
              ),
              const SizedBox(height: 40),
              AppButton(
                label: 'Ver mi publicación',
                icon: Icons.visibility_outlined,
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    scrollable: true,
                    title: const Text('Vista previa local'),
                    content: summary(full: true),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go(AppRoute.home.path),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
