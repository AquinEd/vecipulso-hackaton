import '../utils/provider_display_name.dart';

enum ServiceCategory {
  plumbing('Gasfitería'),
  electricity('Electricidad'),
  carpentry('Carpintería'),
  education('Clases particulares'),
  locksmith('Cerrajería');

  const ServiceCategory(this.label);
  final String label;
}

typedef ProviderReview = ({String author, String comment, int stars});

class ServicePreview {
  const ServicePreview({
    required this.id,
    required this.serviceName,
    required this.providerFirstName,
    required this.providerPaternalSurname,
    required this.description,
    required this.category,
    required this.rating,
    required this.distanceMeters,
    this.occupation,
    this.summary,
    this.hasNeighborhoodApproval = false,
    this.reviewCount,
    this.yearsExperience,
    this.completedWorks = const [],
    this.reviews = const [],
  });
  final String id, serviceName, description;
  final String providerFirstName, providerPaternalSurname;
  final String? occupation, summary;
  String get providerDisplayName =>
      formatProviderDisplayName(providerFirstName, providerPaternalSurname);
  final ServiceCategory category;
  final double rating;
  final int distanceMeters;
  final bool hasNeighborhoodApproval;
  final int? reviewCount, yearsExperience;
  final List<String> completedWorks;
  final List<ProviderReview> reviews;

  bool matches(String query, {int? maxMeters, bool fourStars = false}) {
    final searchable = [
      serviceName,
      providerDisplayName,
      category.label,
      occupation,
      description,
      summary,
    ].nonNulls.join(' ');
    return (maxMeters == null || distanceMeters <= maxMeters) &&
        (!fourStars || rating >= 4) &&
        _normalize(searchable).contains(_normalize(query));
  }

  static String _normalize(String text) => text
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
}
