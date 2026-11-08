import 'dart:async';

import 'package:hackaton_veci_pulso/features/services/data/services_repository.dart';
import 'package:hackaton_veci_pulso/features/services/models/service_rows.dart';

class DirectoryFixture implements ServicesRepository {
  static const id = '11111111-1111-4111-8111-111111111111';
  final row = DirectoryEntry.fromJson({
    'id': id,
    'titulo': 'Mesas',
    'descripcion': 'Madera',
    'proveedor_id': id,
    'zona_id': id,
    'categoria_id': 1,
    'activo': true,
    'creado_en': '2026-01-01T00:00:00Z',
    'recomendaciones': [
      {'count': 0},
    ],
  });
  ServicesFailure? failure;
  bool emptyZone = false;
  Completer<List<DirectoryEntry>>? slow;
  @override
  Future<List<ServiceCategoryRow>> categories() async => [
    ServiceCategoryRow.fromJson({'id': 1, 'nombre': 'Carpintería'}),
    ServiceCategoryRow.fromJson({'id': 2, 'nombre': 'Cocina'}),
  ];
  @override
  Future<List<DirectoryEntry>> page({
    String query = '',
    int? categoryId,
    int offset = 0,
  }) async {
    if (failure case final e?) throw e;
    if (categoryId == 2 && slow != null) return slow!.future;
    return !emptyZone &&
            categoryId != 2 &&
            'mesas'.contains(query.toLowerCase())
        ? [row]
        : [];
  }

  @override
  RecommendationsRepository get recommendations =>
      DetailRecommendationsFixture();
  @override
  Future<String?> zoneName(String id) async => 'Zona de prueba';
  @override
  Future<PublicProvider?> provider(String id) async => null;
  @override
  Future<ServiceContact?> contact(String id) async => null;
  @override
  Future<List<ServiceWork>> works(String id) async => [];
  @override
  Future<ServiceRow> detail(String id) async => row.service;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DetailRecommendationsFixture implements RecommendationsRepository {
  @override
  Future<List<ServiceReview>> reviews(String id) async => [];
  @override
  Future<({int count, double? average, bool approved})> statistics(
    String id,
  ) async => (count: 0, average: null, approved: false);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
