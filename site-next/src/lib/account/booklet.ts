// How the app lays stamps out on its booklet pages
// (passport_stamp_source.dart buildYearGroupedStampPages, widgets/
// passport_page.dart _StampField): three stamps a page, every year on a
// fresh page, years newest first; on a page each stamp goes to whichever
// of eight edge anchors leaves it most room, then overlapping pairs are
// nudged apart and everything is kept on the page. The web shows no "next
// stamp" slot: stamps are added in the app.
import type { Stamp } from './passport';
import { pickInk, pickJitter, pickRotation, pickVariant, STAMP_SIZE, type Variant } from './stamps';

export const PER_PAGE = 3;

export interface StampPage { year: number; stamps: Stamp[] }

export function paginate(stampsOldestFirst: Stamp[]): StampPage[] {
  const byYear = new Map<number, Stamp[]>();
  for (const s of stampsOldestFirst) {
    const year = Number(s.date.slice(0, 4));
    byYear.set(year, [...(byYear.get(year) ?? []), s]);
  }
  const pages: StampPage[] = [];
  for (const year of [...byYear.keys()].sort((a, b) => b - a)) {
    const stamps = byYear.get(year)!;
    for (let i = 0; i < stamps.length; i += PER_PAGE) pages.push({ year, stamps: stamps.slice(i, i + PER_PAGE) });
  }
  return pages;
}

export interface Placed { stamp: Stamp; variant: Variant; ink: number; rotation: number; x: number; y: number; width: number; height: number }

// NW, NE, SE, SW, N, E, S, W: the order the app tries them in.
const DIRECTIONS: [number, number][] = [[-1, -1], [1, -1], [1, 1], [-1, 1], [0, -1], [1, 0], [0, 1], [-1, 0]];
const EDGE_MARGIN = 6;

/** Centres (x, y) of each stamp within a content box of [width] × [height]. */
export function placeStamps(stamps: Stamp[], width: number, height: number): Placed[] {
  let prevVariant: Variant | undefined;
  let prevInk: number | undefined;
  const items = stamps.map((stamp) => {
    const variant = pickVariant(stamp.id, prevVariant);
    const ink = pickInk(stamp.id, prevInk);
    prevVariant = variant;
    prevInk = ink;
    const [w, h] = STAMP_SIZE[variant];
    return { stamp, variant, ink, w, h, half: Math.hypot(w, h) / 2, jitter: pickJitter(stamp.id), x: 0, y: 0 };
  });

  items.forEach((item, i) => {
    const maxDx = Math.max(0, Math.min(width / 2, width / 2 - item.half - EDGE_MARGIN));
    const maxDy = Math.max(0, Math.min(height / 2, height / 2 - item.half - EDGE_MARGIN));
    let best: [number, number] = [width / 2, height / 2];
    let bestScore = -Infinity;
    for (const [dx, dy] of DIRECTIONS) {
      const cx = width / 2 + dx * maxDx + item.jitter[0];
      const cy = height / 2 + dy * maxDy + item.jitter[1];
      let score = Infinity;
      for (const other of items.slice(0, i)) score = Math.min(score, Math.hypot(cx - other.x, cy - other.y) - (item.half + other.half));
      if (score > bestScore) { bestScore = score; best = [cx, cy]; }
    }
    [item.x, item.y] = best;
  });

  for (let round = 0; round < 3; round++) {
    for (let a = 0; a < items.length; a++) {
      for (let b = a + 1; b < items.length; b++) {
        const A = items[a], B = items[b];
        const min = (A.half + B.half) * 0.9;
        let dx = B.x - A.x, dy = B.y - A.y;
        const dist = Math.hypot(dx, dy);
        if (dist >= min) continue;
        if (dist > 0.01) { dx /= dist; dy /= dist; } else { dx = 1; dy = 0; }
        const push = (min - dist) / 2;
        A.x -= dx * push; A.y -= dy * push;
        B.x += dx * push; B.y += dy * push;
      }
    }
  }

  // Kept on the page by the half-diagonal, leaving room for the tilt.
  const clamp = (v: number, half: number, size: number) => {
    const lo = Math.min(half, size / 2);
    const hi = Math.max(lo, Math.min(size, size - half));
    return Math.max(lo, Math.min(hi, v));
  };
  return items.map((it) => ({
    stamp: it.stamp, variant: it.variant, ink: it.ink, rotation: pickRotation(it.stamp.id),
    x: clamp(it.x, it.half, width), y: clamp(it.y, it.half, height), width: it.w, height: it.h,
  }));
}
