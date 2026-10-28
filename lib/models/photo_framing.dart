import 'package:flutter/widgets.dart';

/// How a venue photo sits in whatever frame shows it — set by the venue's
/// own manager (at upload, or later via set_venue_photo_framing,
/// 20261014120000) and honoured by the detail hero and every card.
///
/// [focusX]/[focusY] are 0..1 across the image; [zoom] is 1..4. Same
/// meaning as news_articles.focus_x/focus_y: with BoxFit.cover, the image
/// is aligned at [alignment], then scaled by [zoom] around that same
/// point (see FramedImage). One framing serves every frame shape.
@immutable
class PhotoFraming {
  final double focusX;
  final double focusY;
  final double zoom;

  const PhotoFraming({this.focusX = 0.5, this.focusY = 0.5, this.zoom = 1});

  /// A plain centred crop — every photo before framing existed.
  static const center = PhotoFraming();

  /// Where a private chef photo that has never been framed is shown, and
  /// where the editor starts for one: high in the frame, the old
  /// PrivateChefHero alignment (0, -0.8). See [forChef].
  static const chefDefault = PhotoFraming(focusY: 0.1);

  /// The chef discovery card's own untouched placement, the old
  /// _ChefCoverPhoto Alignment(0, -0.3) — a different box shape from the
  /// hero, so a different long-standing default. See [forChefCard].
  static const chefCardDefault = PhotoFraming(focusY: 0.35);

  /// A private chef photo's framing in the HERO: an untouched (centred)
  /// photo keeps the high placement chef photos have always had, rather
  /// than every existing chef photo dropping to a centre crop.
  PhotoFraming get forChef => isCentered ? chefDefault : this;

  /// The same for the chef CARD.
  PhotoFraming get forChefCard => isCentered ? chefCardDefault : this;

  /// What to store for a chef photo framed in the editor: leaving it at
  /// [chefDefault] (where the editor starts) means "untouched", stored as
  /// centred so the hero and the card each keep their own default.
  PhotoFraming get storedForChef => this == chefDefault ? center : this;

  static const double minZoom = 1;
  static const double maxZoom = 4;

  /// Reads `focus_x`/`focus_y`/`zoom` (or, with [prefix], e.g. `cover_`,
  /// `cover_focus_x`...). Anything missing falls back to centred, so a
  /// row from a source without these columns still renders.
  factory PhotoFraming.fromJson(
    Map<String, dynamic> json, {
    String prefix = '',
  }) => PhotoFraming(
    focusX: ((json['${prefix}focus_x'] as num?) ?? 0.5).toDouble(),
    focusY: ((json['${prefix}focus_y'] as num?) ?? 0.5).toDouble(),
    zoom: ((json['${prefix}zoom'] as num?) ?? 1).toDouble(),
  ).clamped();

  PhotoFraming clamped() => PhotoFraming(
    focusX: focusX.clamp(0.0, 1.0),
    focusY: focusY.clamp(0.0, 1.0),
    zoom: zoom.clamp(minZoom, maxZoom),
  );

  PhotoFraming copyWith({double? focusX, double? focusY, double? zoom}) =>
      PhotoFraming(
        focusX: focusX ?? this.focusX,
        focusY: focusY ?? this.focusY,
        zoom: zoom ?? this.zoom,
      ).clamped();

  Alignment get alignment => Alignment(focusX * 2 - 1, focusY * 2 - 1);

  bool get isCentered => focusX == 0.5 && focusY == 0.5 && zoom == 1;

  @override
  bool operator ==(Object other) =>
      other is PhotoFraming &&
      other.focusX == focusX &&
      other.focusY == focusY &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(focusX, focusY, zoom);

  @override
  String toString() => 'PhotoFraming($focusX, $focusY, x$zoom)';
}
