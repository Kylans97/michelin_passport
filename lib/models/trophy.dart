class Trophy {
  final String key;
  final String name;
  final String description;
  final String category; // milestone / travel / country / social
  final DateTime? earnedAt;

  const Trophy({
    required this.key,
    required this.name,
    required this.description,
    required this.category,
    this.earnedAt,
  });

  bool get isEarned => earnedAt != null;

  Trophy copyWithEarned(DateTime at) => Trophy(
    key: key,
    name: name,
    description: description,
    category: category,
    earnedAt: at,
  );

  factory Trophy.fromRow({
    required Map<String, dynamic> trophyRow,
    DateTime? earnedAt,
  }) => Trophy(
    key: trophyRow['key'] as String,
    name: trophyRow['name'] as String,
    description: (trophyRow['description'] as String?) ?? '',
    category: (trophyRow['category'] as String?) ?? 'milestone',
    earnedAt: earnedAt,
  );
}
