import 'package:flutter/material.dart';
import 'package:hackaton_veci_pulso/shared/widgets/common/app_section_header.dart';

class FeaturePlaceholderScreen extends StatelessWidget {
  const FeaturePlaceholderScreen({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSectionHeader(title: title),
          const SizedBox(height: 8),
          const Text('Funcionalidad en preparación.'),
        ],
      ),
    ),
  );
}
