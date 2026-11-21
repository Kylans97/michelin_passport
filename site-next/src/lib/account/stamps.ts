// The app's five ink stamps (lib/features/passport/widgets/
// passport_stamp_painters.dart, utils/passport_stamp_style.dart), drawn as
// SVG: round seal, double frame, oval, octagon and postmark, in one of the
// three stamp inks, pressed slightly askew. Every choice hangs off the
// stamp's own row id through the same FNV-1a hash as the app, so a visit
// gets the same design, ink and angle on the site as on the phone.
import type { Stamp } from './passport';
import { MONTHS } from '../event-dates';

export type Variant = 'roundSeal' | 'doubleFrame' | 'oval' | 'octagon' | 'postmark';
const VARIANTS: Variant[] = ['roundSeal', 'doubleFrame', 'oval', 'octagon', 'postmark'];
/** AppColors.stampInkGold, stampInkDeepGold, stampInkGreen. */
const INKS = ['#8E6935', '#6E5129', '#2C574B'];

export const STAMP_SIZE: Record<Variant, [number, number]> = {
  roundSeal: [176, 176], doubleFrame: [196, 140], oval: [228, 132], octagon: [176, 176], postmark: [252, 128],
};

/** stampStableHash: FNV-1a over UTF-16 code units, 32-bit. */
export function stableHash(input: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < input.length; i++) {
    hash ^= input.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}
const unit = (salted: string) => (stableHash(salted) % 10000) / 10000;

export function pickVariant(id: string, avoid?: Variant): Variant {
  const index = stableHash(`${id}:variant`) % VARIANTS.length;
  const v = VARIANTS[index];
  return avoid && v === avoid ? VARIANTS[(index + 1) % VARIANTS.length] : v;
}
export function pickInk(id: string, avoid?: number): number {
  const index = stableHash(`${id}:ink`) % INKS.length;
  return avoid !== undefined && index === avoid ? (index + 1) % INKS.length : index;
}
export const pickRotation = (id: string) => -7 + unit(`${id}:rotation`) * 13;
export const pickJitter = (id: string): [number, number] => [-12 + unit(`${id}:jx`) * 24, -12 + unit(`${id}:jy`) * 24];

const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
/** [year, month, day] of a YYYY-MM-DD date. */
const dateParts = (date: string) => date.split('-').map(Number) as [number, number, number];
/** "12 MAR 2026", the date slot every design shares. */
export const stampDate = (date: string) => {
  const p = dateParts(date);
  return `${p[2]} ${MONTHS[p[1] - 1].toUpperCase()} ${p[0]}`;
};

const SERIF = "'Spectral', Georgia, serif";
const SANS = "'Hanken Grotesk', system-ui, sans-serif";

/** The venue name in one or two balanced lines, at the largest of three
 *  sizes that fits [maxWidth]; serif glyphs average about half an em. */
function fitName(name: string, maxWidth: number, sizes: [number, number, number], perEm = 0.5): { lines: string[]; size: number } {
  const words = name.split(/\s+/).filter(Boolean);
  const fits = (line: string, size: number) => line.length * size * perEm <= maxWidth;
  for (const size of sizes) {
    if (fits(name, size)) return { lines: [name], size };
  }
  for (const size of sizes) {
    let best: string[] | null = null;
    for (let i = 1; i < words.length; i++) {
      const lines = [words.slice(0, i).join(' '), words.slice(i).join(' ')];
      if (lines.every((l) => fits(l, size)) && (!best || Math.abs(lines[0].length - lines[1].length) < Math.abs(best[0].length - best[1].length))) best = lines;
    }
    if (best) return { lines: best, size };
  }
  // A long event name: three lines at the smallest size, filled greedily.
  const size = sizes[2];
  const three: string[] = [];
  for (const word of words) {
    const last = three[three.length - 1];
    if (last && fits(`${last} ${word}`, size)) three[three.length - 1] = `${last} ${word}`;
    else three.push(word);
  }
  if (three.length <= 3 && three.every((l) => fits(l, size))) return { lines: three, size };
  const max = Math.floor(maxWidth / (size * perEm));
  return { lines: [name.length > max ? `${name.slice(0, max - 1)}…` : name], size };
}

const STAR = 'M0,-1 L0.2245,-0.309 L0.951,-0.309 L0.363,0.118 L0.588,0.809 L0,0.382 L-0.588,0.809 L-0.363,0.118 L-0.951,-0.309 L-0.2245,-0.309 Z';
// A key lying on its side: bow on the left, two teeth under the shaft.
const KEY = 'M-0.55,-0.42 a0.42,0.42 0 1 0 0.001,0 Z M-0.55,-0.17 a0.17,0.17 0 1 1 -0.001,0 Z M-0.135,-0.1 H1 V0.1 H0.92 V0.38 H0.74 V0.1 H0.6 V0.3 H0.44 V0.1 H-0.135 Z';

/** Stars, Keys or the event type, centred on (cx, cy); null draws nothing,
 *  and a venue without either has no award row at all. */
function award(s: Stamp, cx: number, cy: number, ink: string): { svg: string; height: number } | null {
  if (s.kind === 'event' && s.eventType) {
    return { svg: `<text x="${cx}" y="${cy + 3.5}" text-anchor="middle" font-family="${SANS}" font-size="10" font-weight="600" letter-spacing="1.4" fill="${ink}">${esc(s.eventType.toUpperCase())}</text>`, height: 12 };
  }
  const count = s.kind === 'restaurant' ? s.stars ?? 0 : s.keys ?? 0;
  if (count <= 0) return null;
  const glyph = s.kind === 'restaurant' ? STAR : KEY;
  const size = 7, step = s.kind === 'restaurant' ? 16.5 : 19;
  let svg = '';
  for (let i = 0; i < count; i++) {
    const x = cx - ((count - 1) * step) / 2 + i * step;
    svg += `<path d="${glyph}" transform="translate(${x} ${cy}) scale(${size})" fill="${ink}" fill-rule="evenodd"/>`;
  }
  return { svg, height: 15 };
}

interface Piece { height: number; draw: (top: number) => string }
/** A vertical stack centred as one group: absent pieces simply aren't
 *  there, so the rest shifts together (_paintCenteredStack). */
function stack(pieces: Piece[], centerY: number, gap: number): string {
  const total = pieces.reduce((sum, p) => sum + p.height, 0) + gap * (pieces.length - 1);
  let top = centerY - total / 2;
  let svg = '';
  for (const p of pieces) {
    svg += p.draw(top);
    top += p.height + gap;
  }
  return svg;
}
const textLines = (lines: string[], cx: number, size: number, font: string, ink: string, extra = '') => (top: number) =>
  lines.map((l, i) => `<text x="${cx}" y="${top + size * 0.82 + i * size * 1.02}" text-anchor="middle" font-family="${font}" font-size="${size}" font-weight="600" fill="${ink}" ${extra}>${esc(l)}</text>`).join('');
const smallCaps = (text: string, cx: number, size: number, ink: string, spacing = 2) => (top: number) =>
  `<text x="${cx}" y="${top + size * 0.85}" text-anchor="middle" font-family="${SANS}" font-size="${size}" font-weight="600" letter-spacing="${spacing}" fill="${ink}">${esc(text)}</text>`;
const awardPiece = (s: Stamp, cx: number, ink: string): Piece[] => {
  const a = award(s, cx, 0, ink);
  return a ? [{ height: a.height, draw: (top) => `<g transform="translate(0 ${top + a.height / 2})">${a.svg}</g>` }] : [];
};

function roundSeal(s: Stamp, ink: string, uid: string): string {
  const c = 88, outer = 85, inner = 60, mid = (outer + inner) / 2;
  const name = fitName(s.name, 104, [22, 17, 15]);
  return `
    <circle cx="${c}" cy="${c}" r="${outer}" fill="none" stroke="${ink}" stroke-width="2.2"/>
    <circle cx="${c}" cy="${c}" r="${inner}" fill="none" stroke="${ink}" stroke-width="1"/>
    <path id="${uid}t" d="M${c - mid},${c} A${mid},${mid} 0 0 1 ${c + mid},${c}" fill="none"/>
    <path id="${uid}b" d="M${c - mid},${c} A${mid},${mid} 0 0 0 ${c + mid},${c}" fill="none"/>
    <text font-family="${SANS}" font-size="10.5" font-weight="600" letter-spacing="2.4" fill="${ink}" dominant-baseline="middle"><textPath href="#${uid}t" startOffset="50%" text-anchor="middle">${esc(s.city.toUpperCase())}</textPath></text>
    <text font-family="${SANS}" font-size="10.5" font-weight="600" letter-spacing="2.4" fill="${ink}" dominant-baseline="middle"><textPath href="#${uid}b" startOffset="50%" text-anchor="middle">${esc(stampDate(s.date))}</textPath></text>
    <circle cx="${c - mid}" cy="${c}" r="2.2" fill="${ink}"/><circle cx="${c + mid}" cy="${c}" r="2.2" fill="${ink}"/>
    ${stack([...awardPiece(s, c, ink), { height: name.size * 1.02 * name.lines.length, draw: textLines(name.lines, c, name.size, SERIF, ink) }], c, 6)}`;
}

function doubleFrame(s: Stamp, ink: string): string {
  const [w, h] = STAMP_SIZE.doubleFrame, cx = w / 2;
  const name = fitName(s.name.toUpperCase(), 160, [24, 19, 16], 0.62);
  return `
    <rect x="1.5" y="1.5" width="${w - 3}" height="${h - 3}" fill="none" stroke="${ink}" stroke-width="3"/>
    <rect x="7" y="7" width="${w - 14}" height="${h - 14}" fill="none" stroke="${ink}" stroke-width="1.4"/>
    ${stack([
      { height: 10, draw: smallCaps(s.city.toUpperCase(), cx, 8.5, ink) },
      { height: name.size * 1.02 * name.lines.length, draw: textLines(name.lines, cx, name.size, SERIF, ink, `letter-spacing="${name.size * 0.06}"`) },
      ...awardPiece(s, cx, ink),
      { height: 1, draw: (top) => `<line x1="${cx - 20}" x2="${cx + 20}" y1="${top}" y2="${top}" stroke="${ink}" stroke-width="1"/>` },
      { height: 14, draw: smallCaps(stampDate(s.date), cx, 13, ink, 1.2) },
    ], h / 2, 5)}`;
}

function oval(s: Stamp, ink: string): string {
  const [w, h] = STAMP_SIZE.oval, cx = w / 2;
  const name = fitName(s.name, w - 64, [24, 19, 16]);
  return `
    <ellipse cx="${cx}" cy="${h / 2}" rx="${w / 2 - 1}" ry="${h / 2 - 1}" fill="none" stroke="${ink}" stroke-width="1.5"/>
    <ellipse cx="${cx}" cy="${h / 2}" rx="${w / 2 - 7}" ry="${h / 2 - 7}" fill="none" stroke="${ink}" stroke-width="1"/>
    ${stack([
      { height: 10, draw: smallCaps(s.city.toUpperCase(), cx, 8.5, ink) },
      { height: name.size * 1.02 * name.lines.length, draw: textLines(name.lines, cx, name.size, SERIF, ink, 'font-style="italic"') },
      ...awardPiece(s, cx, ink),
      { height: 12, draw: smallCaps(stampDate(s.date), cx, 11, ink, 1.2) },
    ], h / 2, 5)}`;
}

function octagonPath(x: number, y: number, size: number): string {
  const k = size * 0.2929, e = size;
  return `M${x + k},${y} H${x + e - k} L${x + e},${y + k} V${y + e - k} L${x + e - k},${y + e} H${x + k} L${x},${y + e - k} V${y + k} Z`;
}
function octagon(s: Stamp, ink: string): string {
  const d = STAMP_SIZE.octagon[0], cx = d / 2;
  const name = fitName(s.name, 132, [22, 17, 15]);
  const date = stampDate(s.date);
  const barW = date.length * 10 * 0.72 + 20;
  return `
    <path d="${octagonPath(1, 1, d - 2)}" fill="none" stroke="${ink}" stroke-width="2"/>
    <path d="${octagonPath(10, 10, d - 20)}" fill="none" stroke="${ink}" stroke-width="0.8"/>
    ${stack([
      ...awardPiece(s, cx, ink),
      { height: name.size * 1.02 * name.lines.length, draw: textLines(name.lines, cx, name.size, SERIF, ink) },
      { height: 17, draw: (top) => `<rect x="${cx - barW / 2}" y="${top}" width="${barW}" height="17" fill="${ink}"/><text x="${cx}" y="${top + 12}" text-anchor="middle" font-family="${SANS}" font-size="10" font-weight="600" letter-spacing="1.4" fill="#F4F0E7">${esc(date)}</text>` },
      { height: 11, draw: smallCaps(s.city.toUpperCase(), cx, 9, ink) },
    ], d / 2, 6)}`;
}

function postmark(s: Stamp, ink: string, uid: string): string {
  const [w, h] = STAMP_SIZE.postmark, r = 54, ccx = r + 6, ccy = h / 2, ar = r - 11;
  const p = dateParts(s.date);
  const left = ccx + r + 8;
  const rcx = (left + w) / 2;
  const name = fitName(s.name, w - left - 6, [24, 19, 16]);
  let waves = '';
  for (const dy of [-22, 0, 22]) {
    let path = `M${left},${ccy + dy}`;
    for (let x = left; x < w - 2; x += 12) path += ` q3,-4 6,0 t6,0`;
    waves += `<path d="${path}" fill="none" stroke="${ink}" stroke-width="1.2" opacity="0.55"/>`;
  }
  return `
    <circle cx="${ccx}" cy="${ccy}" r="${r}" fill="none" stroke="${ink}" stroke-width="1.5"/>
    <path id="${uid}t" d="M${ccx - ar},${ccy} A${ar},${ar} 0 0 1 ${ccx + ar},${ccy}" fill="none"/>
    <text font-family="${SANS}" font-size="8" font-weight="600" letter-spacing="2" fill="${ink}" dominant-baseline="middle"><textPath href="#${uid}t" startOffset="50%" text-anchor="middle">${esc(s.city.toUpperCase())}</textPath></text>
    <text x="${ccx}" y="${ccy + 6}" text-anchor="middle" font-family="${SERIF}" font-size="26" font-weight="600" fill="${ink}">${p[2]}</text>
    <text x="${ccx}" y="${ccy + 20}" text-anchor="middle" font-family="${SANS}" font-size="9" font-weight="600" letter-spacing="1" fill="${ink}">${MONTHS[p[1] - 1].toUpperCase()} ${p[0]}</text>
    ${waves}
    ${stack([
      { height: name.size * 1.02 * name.lines.length, draw: textLines(name.lines, rcx, name.size, SERIF, ink, 'font-style="italic" paint-order="stroke" stroke="#FBF8F1" stroke-width="4"') },
      ...awardPiece(s, rcx, ink),
    ], ccy, 4)}`;
}

/** One stamp as an SVG element, unrotated; the page sets angle and place. */
export function stampSvg(s: Stamp, variant: Variant, ink: number): string {
  const [w, h] = STAMP_SIZE[variant];
  const color = INKS[ink];
  const uid = `s${s.id.replace(/[^a-z0-9]/gi, '').slice(0, 12)}`;
  const body = variant === 'roundSeal' ? roundSeal(s, color, uid)
    : variant === 'doubleFrame' ? doubleFrame(s, color)
    : variant === 'oval' ? oval(s, color)
    : variant === 'octagon' ? octagon(s, color)
    : postmark(s, color, uid);
  return `<svg class="stamp-ink" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" aria-hidden="true">${body}</svg>`;
}
