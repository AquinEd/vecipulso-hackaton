import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/common/app_section_header.dart';

const demoNotice = 'Datos de ejemplo · Distancias simuladas';

class ServiceHeading extends StatelessWidget {
  const ServiceHeading({
    super.key,
    required this.title,
    required this.fallback,
  });
  final String title, fallback;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(fallback),
        ),
        Expanded(child: AppSectionHeader(title: title)),
      ],
    ),
  );
}
