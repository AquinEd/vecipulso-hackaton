import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/common/app_asset_image.dart';
import '../../models/emergency_report.dart';

extension EmergencyPriorityStyle on EmergencyPriority {
  Color get color => switch (this) {
    EmergencyPriority.critical => AppColors.sos,
    EmergencyPriority.urgent => AppColors.warningText,
    EmergencyPriority.underReview => AppColors.map,
  };
}

class EmergencyReportCard extends StatelessWidget {
  const EmergencyReportCard({
    super.key,
    required this.report,
    required this.onTap,
  });
  final EmergencyReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 56,
              decoration: BoxDecoration(
                color: report.priority.color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: switch (report.category) {
                EmergencyCategory.rescue => Icon(
                  Icons.warning_rounded,
                  color: report.priority.color,
                ),
                EmergencyCategory.resources => const AppAssetImage(
                  path: AppAssets.iconoAguaSVG,
                  width: 28,
                  height: 28,
                ),
                EmergencyCategory.housing => Icon(
                  Icons.home_outlined,
                  color: report.priority.color,
                ),
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${report.priority.label} · ${report.distanceLabel}',
                    style: TextStyle(
                      color: report.priority.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward,
              size: 20,
              color: AppColors.secondaryText,
            ),
          ],
        ),
      ),
    ),
  );
}
