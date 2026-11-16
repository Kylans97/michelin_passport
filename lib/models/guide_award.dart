// Maps rows from the shared guide tables (see
// supabase/migrations/20261101410000_add_shared_guide_tables.sql): every
// guide beyond MICHELIN, The World's 50 Best and Gault&Millau — today the
// regional 50 Best lists. Like GaultMillauAward, a raw recognition row kept
// apart from Restaurant, never folded into it.

/// How a guide measures, per `guides.measure`. Rank sorts lower-is-better,
/// score and tier higher-is-better, which is why they stay separate fields.
enum GuideMeasure {
  rank,
  score,
  tier;

  static GuideMeasure fromDbValue(String? value) => switch (value) {
    'score' => GuideMeasure.score,
    'tier' => GuideMeasure.tier,
    _ => GuideMeasure.rank,
  };
}

class GuideAward {
  final String guideCode;
  final String guideName;
  final GuideMeasure measure;
  final int editionYear;
  final String listName;
  final int? rank;
  final double? score;
  final double? scoreMax;
  final int? tier;
  // guides.tier_labels, e.g. {"3": "3 Soles"}: how the guide names its own
  // tiers. Display only, never parsed back into a tier.
  final Map<String, String> tierLabels;
  // A named distinction kept verbatim; display only.
  final String? distinctionLabel;

  const GuideAward({
    required this.guideCode,
    required this.guideName,
    required this.measure,
    required this.editionYear,
    required this.listName,
    this.rank,
    this.score,
    this.scoreMax,
    this.tier,
    this.tierLabels = const {},
    this.distinctionLabel,
  });

  /// A `guide_awards` row with its embedded `guides` row
  /// (`select('..., guides(name, measure, score_max)')`).
  factory GuideAward.fromJson(Map<String, dynamic> json) {
    final guide = (json['guides'] as Map<String, dynamic>?) ?? const {};
    return GuideAward(
      guideCode: json['guide_code'] as String,
      guideName: (guide['name'] as String?) ?? json['guide_code'] as String,
      measure: GuideMeasure.fromDbValue(guide['measure'] as String?),
      editionYear: (json['edition_year'] as num).toInt(),
      listName: (json['list_name'] as String?) ?? 'main',
      rank: (json['rank'] as num?)?.toInt(),
      score: (json['score'] as num?)?.toDouble(),
      scoreMax: (guide['score_max'] as num?)?.toDouble(),
      tier: (json['tier'] as num?)?.toInt(),
      tierLabels: {
        for (final e
            in ((guide['tier_labels'] as Map<String, dynamic>?) ?? const {})
                .entries)
          e.key: e.value as String,
      },
      distinctionLabel: json['distinction_label'] as String?,
    );
  }
}

/// What a guide's value reads as, in the guide's own measure: "#12" for a
/// rank, "98.5" for a score, the guide's own name for a tier ("3 Soles")
/// or else its number, or the verbatim distinction.
/// Null when the row carries nothing showable — never a made-up value.
String? formatGuideAwardValue(GuideAward award) {
  switch (award.measure) {
    case GuideMeasure.rank:
      if (award.rank != null) return '#${award.rank}';
    case GuideMeasure.score:
      final score = award.score;
      if (score != null) {
        return score == score.roundToDouble()
            ? score.toStringAsFixed(0)
            : score.toString();
      }
    case GuideMeasure.tier:
      final tier = award.tier;
      if (tier != null) return award.tierLabels['$tier'] ?? '$tier';
  }
  return award.distinctionLabel;
}

/// One guide edition's coverage note from `guide_coverage`: what we hold,
/// said plainly (as the Gault&Millau guide page does).
class GuideCoverage {
  final String guideCode;
  final int editionYear;
  final bool isComplete;
  final String note;

  const GuideCoverage({
    required this.guideCode,
    required this.editionYear,
    required this.isComplete,
    required this.note,
  });

  factory GuideCoverage.fromJson(Map<String, dynamic> json) => GuideCoverage(
    guideCode: json['guide_code'] as String,
    editionYear: (json['edition_year'] as num).toInt(),
    isComplete: json['coverage'] == 'complete',
    note: json['note'] as String,
  );
}
