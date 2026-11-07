import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/common/app_asset_image.dart';
import '../../../../shared/widgets/common/app_text_field.dart';
import '../../../services/data/demo_services.dart';
import '../../../services/models/service_preview.dart';
import '../widgets/review_star_selector.dart';

class CreateReviewScreen extends StatefulWidget {
  const CreateReviewScreen({super.key, this.providerId});
  final String? providerId;

  @override
  State<CreateReviewScreen> createState() => _CreateReviewScreenState();
}

class _CreateReviewScreenState extends State<CreateReviewScreen> {
  final comment = TextEditingController();
  final form = GlobalKey<FormState>();
  int rating = 0;
  bool showRatingError = false;
  static const limit = 300;

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  void back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoute.services.path);
    }
  }

  void preview(ServicePreview provider) {
    FocusManager.instance.primaryFocus?.unfocus();
    final validComment = form.currentState!.validate();
    setState(() => showRatingError = rating < 1 || rating > 5);
    if (showRatingError || !validComment) return;
    final note = comment.text.trim();
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: const Text('Vista previa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.providerDisplayName,
              style: Theme.of(dialog).textTheme.titleMedium,
            ),
            Text(provider.serviceName),
            Text('$rating de 5 estrellas'),
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(note),
              ),
            const SizedBox(height: 8),
            const Text(
              'Esta es una vista previa. No se publicó ninguna reseña y la valoración del proveedor no cambió.',
            ),
          ],
        ),
        actions: [
          for (final label in ['Seguir editando', 'Cerrar vista previa'])
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(label),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = demoServices
        .where((s) => s.id == widget.providerId)
        .firstOrNull;
    final theme = Theme.of(context);
    const gap = SizedBox(height: AppSpacing.medium);
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: back),
          title: const AppAssetImage(
            path: AppAssets.vecipulsoLogoHorizontalPNG,
            label: 'VeciPulso',
            height: 44,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Visto Bueno Vecinal',
                    style: theme.textTheme.headlineSmall,
                  ),
                  gap,
                  if (provider == null) ...[
                    Text(
                      widget.providerId == null
                          ? 'Selecciona un proveedor para calificar.'
                          : 'Proveedor no encontrado.',
                    ),
                    gap,
                    AppButton(
                      label: 'Volver al directorio',
                      icon: Icons.list,
                      onPressed: () => context.go(AppRoute.services.path),
                    ),
                  ] else ...[
                    AppCard(
                      child: ColoredBox(
                        color: const Color(0xffe8f5ef),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.medium),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.small),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Opiniones entre vecinos',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const Text(
                                      'Recomienda un servicio solo cuando lo hayas utilizado.',
                                    ),
                                    const SizedBox(height: AppSpacing.small),
                                    const Text(
                                      'Demostración: las valoraciones no se publican ni se verifican.',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    gap,
                    Text(
                      'Califica tu experiencia',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.providerDisplayName,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(provider.serviceName),
                            ReviewStarSelector(
                              value: rating,
                              onChanged: (value) => setState(() {
                                rating = value;
                                showRatingError = false;
                              }),
                            ),
                            if (showRatingError)
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  'Selecciona entre 1 y 5 estrellas.',
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    gap,
                    AppTextField(
                      controller: comment,
                      label: 'Deja una reseña opcional',
                      hint: 'Cuéntanos cómo fue tu experiencia con este servicio.',
                      icon: Icons.edit_outlined,
                      maxLines: 4,
                      maxLength: limit,
                      validator: (value) =>
                          (value ?? '').characters.length > limit
                          ? 'Escribe hasta 300 caracteres.'
                          : null,
                    ),
                    gap,
                    AppButton(
                      label: 'Previsualizar Visto Bueno',
                      icon: Icons.visibility_outlined,
                      onPressed: () => preview(provider),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
