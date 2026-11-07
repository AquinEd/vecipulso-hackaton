import 'package:flutter/material.dart';

import '../../../../shared/widgets/common/app_section_header.dart';
import '../../models/emergency_report.dart';
import 'emergency_report_card.dart';

class EmergencyReportDetails extends StatelessWidget {
  const EmergencyReportDetails({super.key, required this.report});
  final EmergencyReport report;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(title: report.title),
          const SizedBox(height: 16),
          if (report.isDemo)
            const Text(
              'Reporte de demostración',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 16),
          Text('Categoría: ${report.category.label}'),
          Text(
            'Prioridad / estado: ${report.priority.label}',
            style: TextStyle(color: report.priority.color),
          ),
          Text('Distancia: ${report.distanceLabel} (simulada)'),
          const SizedBox(height: 16),
          Text(report.description),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    ),
  );
}
