enum PostType {
  offer('Ofrezco'),
  need('Necesito'),
  donation('Dono'),
  exchange('Intercambio'),
  loan('Préstamo');

  const PostType(this.label);
  final String label;
  String get economyLabel => switch (this) {
    need => 'Solicitud',
    donation => 'Donación',
    _ => label,
  };
}

enum WallMode { wall, economy }

class SolidarityPost {
  const SolidarityPost({
    required this.id,
    required this.authorFirstName,
    required this.authorPaternalSurname,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    required this.modality,
    required this.modes,
    required this.hasNeighborhoodApproval,
    this.neighborhood = 'Los Álamos',
    this.age = 'Hace 1 h',
    this.likeCount = 24,
    this.commentCount = 8,
  });
  final String id,
      authorFirstName,
      authorPaternalSurname,
      title,
      description,
      category,
      modality,
      neighborhood,
      age;
  final PostType type;
  final Set<WallMode> modes;
  final int likeCount, commentCount;
  final bool hasNeighborhoodApproval;
}

List<SolidarityPost> visiblePosts(
  Iterable<SolidarityPost> posts,
  WallMode mode,
  PostType? filter,
) => posts
    .where(
      (post) =>
          post.modes.contains(mode) && (filter == null || post.type == filter),
    )
    .toList(growable: false);
