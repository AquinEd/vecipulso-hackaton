enum ServiceCategory { plumbing, carpentry, education }

class ServicePreview {
  const ServicePreview({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.rating,
    required this.distanceMeters,
  });
  final String id, name, description;
  final ServiceCategory category;
  final double rating;
  final int distanceMeters;
}
