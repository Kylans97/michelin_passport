/// Which background family a redesigned component is sitting on — the
/// dual-surface awareness the brief's button/filter/search specs all share
/// (e.g. "ivory background on dark-green environments... or deep-green
/// button on light environments"). One shared enum so [CsPrimaryButton],
/// [CsSecondaryButton], [CsFilterChip] and [CsSearchField] all express the
/// same distinction the same way, rather than each inventing its own
/// bool/enum.
enum CsSurface {
  /// On [CsSurfaces.greenCanvas]/[CsSurfaces.greenElevated].
  dark,

  /// On [CsSurfaces.ivorySurface]/[CsSurfaces.warmWhiteSurface].
  light,
}
