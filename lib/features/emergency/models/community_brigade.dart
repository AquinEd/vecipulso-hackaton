import '../../../core/utils/normalize_search.dart';

enum BrigadeType { brigade, volunteers }

enum BrigadeIcon { shield, community, health, mobility }

class CommunityBrigade {
  const CommunityBrigade({
    required this.id,
    required this.name,
    required this.startBlock,
    required this.endBlock,
    required this.memberCount,
    required this.type,
    required this.icon,
  });

  final String id, name;
  final int startBlock, endBlock, memberCount;
  final BrigadeType type;
  final BrigadeIcon icon;

  String get sectorLabel => 'Cuadras $startBlock–$endBlock';
  String get typeLabel => switch (type) {
    BrigadeType.brigade => 'Brigadas',
    BrigadeType.volunteers => 'Voluntarios',
  };

  bool matches(String query) {
    final searchable = normalizeSearch(
      [
        name,
        sectorLabel,
        typeLabel,
        for (var block = startBlock; block <= endBlock; block++)
          'cuadra $block cuadras $block sector $block',
      ].join(' '),
    );
    return normalizeSearch(query)
        .split(RegExp(r'\s+'))
        .every(
          (term) => RegExp(r'^\d+$').hasMatch(term)
              ? RegExp('\\b${RegExp.escape(term)}\\b').hasMatch(searchable)
              : searchable.contains(term),
        );
  }
}
