import 'package:flutter/material.dart';

import 'community_brigade.dart';
import 'emergency_report.dart';

enum EmergencyMapCategory {
  urgent(
    'Solicitudes urgentes',
    'Solicitud urgente',
    Icons.warning_rounded,
    Color(0xffba2835),
  ),
  review(
    'En revisión',
    'En revisión',
    Icons.report_problem_outlined,
    Color(0xffae5200),
  ),
  resource(
    'Recursos',
    'Recurso de ejemplo',
    Icons.house_rounded,
    Color(0xff087451),
  ),
  brigade('Brigadas', 'Brigada de ejemplo', Icons.groups, Color(0xff2169ac));

  const EmergencyMapCategory(this.filter, this.label, this.icon, this.color);
  final String filter, label;
  final IconData icon;
  final Color color;
}

class EmergencyMapMarker {
  const EmergencyMapMarker._(
    this.id,
    this.title,
    this.category,
    this.position, {
    this.report,
    this.brigade,
    this.description,
  });

  factory EmergencyMapMarker.report(EmergencyReport report, Offset position) =>
      EmergencyMapMarker._(
        report.id,
        report.title,
        report.priority == EmergencyPriority.underReview
            ? EmergencyMapCategory.review
            : EmergencyMapCategory.urgent,
        position,
        report: report,
      );

  factory EmergencyMapMarker.brigade(
    CommunityBrigade brigade,
    Offset position,
  ) => EmergencyMapMarker._(
    brigade.id,
    brigade.name,
    EmergencyMapCategory.brigade,
    position,
    brigade: brigade,
  );

  const EmergencyMapMarker.resource(
    String id,
    String title,
    String description,
    Offset position,
  ) : this._(
        id,
        title,
        EmergencyMapCategory.resource,
        position,
        description: description,
      );

  final String id, title;
  final Offset position;
  final EmergencyMapCategory category;
  final EmergencyReport? report;
  final CommunityBrigade? brigade;
  final String? description;
}
