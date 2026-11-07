import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/common/app_asset_image.dart';
import '../../../../shared/widgets/common/app_section_header.dart';
import '../../../../shared/widgets/common/app_text_field.dart';
import '../../models/publication_draft.dart';

class PublicationDetailsScreen extends StatefulWidget {
  const PublicationDetailsScreen({super.key, required this.controller});
  final PublicationDraftController controller;
  @override
  State<PublicationDetailsScreen> createState() => _DetailsState();
}

class _DetailsState extends State<PublicationDetailsScreen> {
  final form = GlobalKey<FormState>();
  late final draft = widget.controller.draft!;
  late final title = TextEditingController(text: draft.title)
    ..addListener(updateTitle);
  late final detail = TextEditingController(text: draft.description)
    ..addListener(updateDetail);
  void updateTitle() => draft.title = title.text;
  void updateDetail() => draft.description = detail.text;
  @override
  void dispose() {
    title.dispose();
    detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: AppAssetImage(
                path: AppAssets.vecipulsoLogoHorizontalPNG,
                height: 44,
                label: 'VeciPulso',
              ),
            ),
            Row(
              children: [
                BackButton(onPressed: () => context.pop()),
                const Expanded(
                  child: AppSectionHeader(title: 'Publicación rápida'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Paso 2 de 3: describe tu publicación',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            AppCard(
              child: ListTile(
                title: const Text('Categoría seleccionada'),
                subtitle: AppSectionHeader(title: draft.category),
              ),
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: title,
              label: 'Título de la solicitud',
              hint: 'Escribe un título',
              icon: Icons.edit_outlined,
              next: true,
              maxLength: PublicationDraft.titleLimit,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Escribe un título para continuar.'
                  : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: detail,
              label: 'Detalle opcional',
              hint: 'Describe tu publicación',
              icon: Icons.notes,
              maxLines: 4,
              maxLength: PublicationDraft.detailLimit,
              validator: (_) => null,
            ),
            const SizedBox(height: 16),
            const AppCard(
              child: ListTile(
                leading: Icon(Icons.location_on_outlined),
                title: Text(PublicationDraft.neighborhood),
              ),
            ),
            const SizedBox(height: 28),
            AppButton(
              label: 'Confirmar demostración',
              icon: Icons.arrow_forward,
              onPressed: () {
                if (form.currentState!.validate() &&
                    widget.controller.confirm()) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  context.go(AppRoute.success.path);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}
