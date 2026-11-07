import 'package:flutter/material.dart';
import 'package:hackaton_veci_pulso/app/app_routes.dart';
import 'package:go_router/go_router.dart';

class HomeCategorySelector extends StatelessWidget {
  const HomeCategorySelector({super.key});
  @override
  Widget build(BuildContext context) {
    final services = Semantics(
      selected: true,
      child: FilledButton(
        onPressed: () => context.push(AppRoute.services.path),
        child: Text(AppRoute.services.title, textAlign: TextAlign.center),
      ),
    );
    final favors = OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () => context.push(AppRoute.solidarity.path),
      child: Text(AppRoute.solidarity.title, textAlign: TextAlign.center),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <
            MediaQuery.textScalerOf(context).scale(300)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [services, const SizedBox(height: 8), favors],
          );
        }
        return Row(
          children: [
            Expanded(child: services),
            const SizedBox(width: 8),
            Expanded(child: favors),
          ],
        );
      },
    );
  }
}
