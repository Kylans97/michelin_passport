import 'dart:ui' show Color, Offset;
import '../../../core/constants/app_colors.dart';

/// The 5 ink-stamp designs a Passport stamp can be rendered as — see
/// passport_stamp_painters.dart for the actual vector drawing of each.
enum StampVariant { roundSeal, doubleFrame, oval, octagon, postmark }

/// The 3 inks a stamp can be printed in — each backed directly by one of
/// [AppColors]' own stamp-ink tokens, so those three constants stay the
/// single source of truth for the actual color values.
enum StampInk {
  gold(AppColors.stampInkGold),
  deepGold(AppColors.stampInkDeepGold),
  green(AppColors.stampInkGreen);

  final Color color;
  const StampInk(this.color);
}

/// A single, stable, deterministic hash over [input] — FNV-1a, 32-bit.
/// Deliberately NOT `Object.hashCode`/`String.hashCode`: those are only
/// guaranteed consistent within one isolate run, not across platforms or
/// Dart versions, which would make "the same visit always gets the same
/// stamp" (this file's whole purpose) false the moment the app updates.
/// Iterates [String.codeUnits] (UTF-16) rather than encoding to real UTF-8
/// bytes — every id this is ever called with (a `visits`/
/// `event_confirmed_attendance` uuid, salted with a short ASCII suffix
/// below) is pure ASCII, where the two are identical, so the extra
/// `dart:convert` encoding step would add nothing.
int stampStableHash(String input) {
  const fnvPrime = 0x01000193;
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  return hash;
}

/// [stampStableHash] mapped to [0, 1) — the common building block every
/// picker below derives its own range from.
double _unitFraction(String salted) => (stampStableHash(salted) % 10000) / 10000;

/// The stamp variant for [id] — `hash(id) % 5`, deterministic. When
/// [avoid] is given and would be picked, advances to the next variant in
/// enum order instead (wrapping), satisfying "avoid two identical
/// variants next to each other on the same page" without a second,
/// independent random draw that could just as easily collide again.
StampVariant pickStampVariant(String id, {StampVariant? avoid}) {
  final values = StampVariant.values;
  final index = stampStableHash('$id:variant') % values.length;
  final variant = values[index];
  if (avoid != null && variant == avoid) {
    return values[(index + 1) % values.length];
  }
  return variant;
}

/// The stamp ink for [id] — same "hash, then step forward once if it
/// collides with [avoid]" shape as [pickStampVariant], salted differently
/// so the two picks are decorrelated (a stamp doesn't always get the same
/// ordinal ink and variant together).
StampInk pickStampInk(String id, {StampInk? avoid}) {
  final values = StampInk.values;
  final index = stampStableHash('$id:ink') % values.length;
  final ink = values[index];
  if (avoid != null && ink == avoid) {
    return values[(index + 1) % values.length];
  }
  return ink;
}

/// Deterministic rotation in degrees, uniformly within [-12, 8] — a stamp
/// pressed slightly askew, never dead straight, never upside down.
double pickStampRotationDegrees(String id) {
  final t = _unitFraction('$id:rotation');
  return -12 + t * 20;
}

/// Deterministic (dx, dy) jitter in [-12, 12] on each axis — the ±12pt
/// "hand-stamped" offset a slot's nominal position gets nudged by.
/// Salted separately per axis so a stamp isn't always jittered along the
/// diagonal.
Offset pickStampPositionJitter(String id) {
  final tx = _unitFraction('$id:jx');
  final ty = _unitFraction('$id:jy');
  return Offset(-12 + tx * 24, -12 + ty * 24);
}
