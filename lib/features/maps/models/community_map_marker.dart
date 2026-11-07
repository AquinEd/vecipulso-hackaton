import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/normalize_search.dart';

enum MapCategory {
  resource('Recursos disponibles', Color(0xff08855e), Icons.home_outlined),
  shop('Comercios locales', AppColors.map, Icons.storefront),
  aid('Ayuda humanitaria', AppColors.sos, Icons.medical_services_outlined),
  brigade('Brigadas de apoyo', Color(0xff087f96), Icons.groups);

  const MapCategory(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;
}

class CommunityMapMarker {
  const CommunityMapMarker({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.relativeX,
    required this.relativeY,
    this.serviceId,
  });
  final String id, title, description;
  final MapCategory category;
  // Position within the illustration, measured from its upper left corner.
  final double relativeX, relativeY;
  final String? serviceId;

  bool matches(String query) =>
      normalizeSearch('$title ${category.label} $description')
          .contains(normalizeSearch(query));
}
