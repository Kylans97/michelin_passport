// Maps a row from `public.gault_millau_awards` (see
// supabase/migrations/20260811120000_create_gault_millau_awards.sql).
// Deliberately separate from Restaurant, mirroring MichelinAwardHistoryEntry/
// Worlds50BestListType (award_history_entry.dart) — this is a raw
// recognition-history row, joined to a real Restaurant by the repository
// layer, never folded into Restaurant itself.

/// The three structurally different shapes `gault_millau_awards` rows can
/// take, per `recognition_type`'s CHECK constraint — see the migration's
/// own extensive comment for the full research provenance of each value.
/// `scored` is the standard case (a numeric score, usually with a toque
/// count); the two unscored variants exist by design in specific markets
/// (France's Toques d'Or academy, Belgium/Switzerland's H!P/POP), not as a
/// data gap — a restaurant in either unscored tier has [GaultMillauAward.
/// score] and [GaultMillauAward.toqueCount] both null on purpose.
enum GaultMillauRecognitionType {
  scored('scored'),
  unscoredTopTier('unscored_top_tier'),
  unscoredCasual('unscored_casual');

  final String dbValue;
  const GaultMillauRecognitionType(this.dbValue);

  static GaultMillauRecognitionType fromDbValue(String? value) =>
      switch (value) {
        'unscored_top_tier' => GaultMillauRecognitionType.unscoredTopTier,
        'unscored_casual' => GaultMillauRecognitionType.unscoredCasual,
        _ => GaultMillauRecognitionType.scored,
      };
}

class GaultMillauAward {
  final String restaurantId;
  final int guideYear;

  // 0-20 scale, half-points. Null for a restaurant whose recognitionType is
  // structurally unscored — never coerced to a number, never derived from
  // toqueCount.
  final double? score;

  // 0-5. Independent of score — a restaurant can have one, both, or
  // (unscored tiers) neither. Null means "not published", never zero.
  final int? toqueCount;

  // Germany-only distinction ('black' vs 'red' at the same toque count).
  // Null for every market this app currently surfaces (AT/BE/CH/FR/NL) —
  // Germany itself remains deferred (see Guides Step 2D brief).
  final String? toqueColour;

  final GaultMillauRecognitionType recognitionType;

  // A named tier worth showing verbatim when present, e.g. "Toques d'Or",
  // "H!P" — display-only, never parsed back into score/toqueCount.
  final String? distinctionLabel;

  final String? gaultMillauUrl;

  const GaultMillauAward({
    required this.restaurantId,
    required this.guideYear,
    this.score,
    this.toqueCount,
    this.toqueColour,
    this.recognitionType = GaultMillauRecognitionType.scored,
    this.distinctionLabel,
    this.gaultMillauUrl,
  });

  factory GaultMillauAward.fromJson(Map<String, dynamic> json) =>
      GaultMillauAward(
        restaurantId: json['restaurant_id'].toString(),
        guideYear: (json['guide_year'] as num).toInt(),
        score: (json['score'] as num?)?.toDouble(),
        toqueCount: (json['toque_count'] as num?)?.toInt(),
        toqueColour: json['toque_colour'] as String?,
        recognitionType: GaultMillauRecognitionType.fromDbValue(
          json['recognition_type'] as String?,
        ),
        distinctionLabel: json['distinction_label'] as String?,
        gaultMillauUrl: json['gault_millau_url'] as String?,
      );
}
