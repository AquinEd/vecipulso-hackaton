import 'package:provider/provider.dart';

import '../../data/services_repository.dart';
import '../../models/service_rows.dart';
import '../controllers/services_controllers.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/common/app_section_header.dart';
import '../../data/demo_services.dart';
import '../../models/service_preview.dart';
import '../widgets/service_heading.dart';

class ProviderDetailScreen extends StatelessWidget {
  const ProviderDetailScreen({super.key, required this.id});
  final String id;

  void _notice(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<ServicesRepository?>();
    if (repository != null &&
        RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')
            .hasMatch(id)) {
      return ChangeNotifierProvider(
        key: ValueKey(id),
        create: (_) =>
            ServiceController<ServiceRow>()..load(() => repository.detail(id)),
        child: Consumer<ServiceController<ServiceRow>>(
          builder: (context, c, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ServiceHeading(
                title: 'Perfil del proveedor',
                fallback: AppRoute.services.path,
              ),
              if (c.stage == ServiceStage.loading)
                const Center(child: CircularProgressIndicator()),
              if (c.data case final service?)
                AppCard(
                  child: ListTile(
                    title: Text(service.titulo),
                    subtitle: Text(service.descripcion ?? ''),
                  ),
                ),
              if (c.failure != null) ...[
                Text(c.failure!.message),
                TextButton(
                  onPressed: () => c.load(() => repository.detail(id)),
                  child: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final provider = demoServices.where((s) => s.id == id).firstOrNull;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ServiceHeading(
          title: 'Perfil del proveedor',
          fallback: AppRoute.services.path,
        ),
        if (provider == null) ...[
          const Text('Proveedor no encontrado'),
          TextButton(
            onPressed: () => context.go(AppRoute.services.path),
            child: const Text('Volver al directorio'),
          ),
        ] else ...[
          _ProviderHeader(provider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              demoNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const AppSectionHeader(title: 'Trabajos realizados'),
          const SizedBox(height: 8),
          if (provider.completedWorks.isEmpty)
            const Text('Sin trabajos de ejemplo para este proveedor.'),
          LayoutBuilder(
            builder: (context, size) {
              final columns =
                  (size.maxWidth /
                          (104 * MediaQuery.textScalerOf(context).scale(1)))
                      .floor()
                      .clamp(1, 3);
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final work in provider.completedWorks)
                    Container(
                      width: (size.maxWidth - (columns - 1) * 8) / columns,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xffe8f5ef),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.carpenter_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 10),
                          Text(work),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const AppSectionHeader(title: 'Reseñas de vecinos'),
          const SizedBox(height: 8),
          if (provider.reviews.isEmpty)
            const Text('Sin reseñas de ejemplo para este proveedor.'),
          for (final review in provider.reviews)
            AppCard(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(review.author),
                subtitle: Text('${review.comment}  ${'★' * review.stars}'),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.push(
              Uri(
                path: AppRoute.review.path,
                queryParameters: {'providerId': provider.id},
              ).toString(),
            ),
            child: const Text('Calificar experiencia (demo)'),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _notice(
                  context,
                  'El contacto telefónico estará disponible cuando se registren proveedores reales',
                ),
                icon: const Icon(Icons.phone_outlined),
                label: const Text('Llamar'),
              ),
              AppButton(
                label: 'Solicitar servicio',
                icon: Icons.handshake_outlined,
                onPressed: () => _notice(
                  context,
                  'La solicitud de servicios estará disponible cuando se conecte el sistema',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ProviderHeader extends StatelessWidget {
  const _ProviderHeader(this.provider);
  final ServicePreview provider;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xffddf3e9),
                  child: Icon(Icons.person, size: 40, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.providerDisplayName,
                        style: theme.textTheme.titleLarge,
                      ),
                      Text('Servicio: ${provider.serviceName}'),
                      Text(provider.occupation ?? provider.category.label),
                      if (provider.hasNeighborhoodApproval)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            '✓ Visto Bueno Vecinal',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              [
                '★ ${provider.rating}',
                if (provider.reviewCount != null)
                  '${provider.reviewCount} reseñas',
              ].join('   ·   '),
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xff9a5100),
              ),
            ),
            Text(
              [
                'A ${provider.distanceMeters} m',
                if (provider.yearsExperience != null)
                  '${provider.yearsExperience} años de experiencia',
              ].join('   ·   '),
            ),
            const SizedBox(height: 10),
            Text(provider.description),
          ],
        ),
      ),
    );
  }
}
