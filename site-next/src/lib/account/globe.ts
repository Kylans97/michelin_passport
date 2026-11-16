// The app's My Map globe (lib/features/map/globe/), drawn on a canvas:
// the same outlines file, projection, colours and horizon clipping, so the
// site shows the same globe. Countries with a stamp are lit ivory; gold
// stays for stars and Keys. No map tiles, no API key, nothing per view.

export interface GlobeCountry { code: string; rings: Float32Array[]; cx: number; cy: number; cz: number; radius: number }
export interface Camera { latitude: number; longitude: number; zoom: number }

export const MIN_ZOOM = 1;
export const MAX_ZOOM = 60;
const MAX_LATITUDE = 80;

/** GlobeOutlines.decode: GLB1, then per country its code and rings of i16 lon/lat. */
export function decodeOutlines(buffer: ArrayBuffer): GlobeCountry[] {
  const data = new DataView(buffer);
  const magic = String.fromCharCode(data.getUint8(0), data.getUint8(1), data.getUint8(2), data.getUint8(3));
  if (magic !== 'GLB1') throw new Error('Not a GLB1 globe outline asset');
  let offset = 4;
  const u16 = () => { const v = data.getUint16(offset, true); offset += 2; return v; };
  const i16 = () => { const v = data.getInt16(offset, true); offset += 2; return v; };
  const countries: GlobeCountry[] = [];
  const count = u16();
  for (let c = 0; c < count; c++) {
    const code = String.fromCharCode(data.getUint8(offset), data.getUint8(offset + 1));
    offset += 2;
    const ringCount = u16();
    const rings: Float32Array[] = [];
    let sx = 0, sy = 0, sz = 0;
    for (let r = 0; r < ringCount; r++) {
      const n = u16();
      const ring = new Float32Array(n * 3);
      for (let i = 0; i < n; i++) {
        const lon = (i16() * 180 / 32767) * Math.PI / 180;
        const lat = (i16() * 90 / 32767) * Math.PI / 180;
        const cosLat = Math.cos(lat);
        ring[i * 3] = cosLat * Math.cos(lon);
        ring[i * 3 + 1] = cosLat * Math.sin(lon);
        ring[i * 3 + 2] = Math.sin(lat);
        sx += ring[i * 3]; sy += ring[i * 3 + 1]; sz += ring[i * 3 + 2];
      }
      rings.push(ring);
    }
    let len = Math.hypot(sx, sy, sz);
    const degenerate = len < 1e-9;
    if (degenerate) { sx = 1; len = 1; }
    const cx = sx / len, cy = sy / len, cz = sz / len;
    let minDot = 1;
    for (const ring of rings) {
      for (let i = 0; i < ring.length; i += 3) minDot = Math.min(minDot, ring[i] * cx + ring[i + 1] * cy + ring[i + 2] * cz);
    }
    countries.push({ code, rings, cx, cy, cz, radius: degenerate ? Math.PI : Math.acos(Math.max(-1, Math.min(1, minDot))) });
  }
  return countries;
}

export const wrapLongitude = (lon: number) => ((((lon + 180) % 360) + 360) % 360) - 180;
export const clampCamera = (c: Camera): Camera => ({
  latitude: Math.max(-MAX_LATITUDE, Math.min(MAX_LATITUDE, c.latitude)),
  longitude: wrapLongitude(c.longitude),
  zoom: Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, c.zoom)),
});

export function unitVector(lat: number, lon: number): [number, number, number] {
  const la = lat * Math.PI / 180, lo = lon * Math.PI / 180;
  const c = Math.cos(la);
  return [c * Math.cos(lo), c * Math.sin(lo), Math.sin(la)];
}

/** GlobeProjection: rotate earth-frame vectors so the camera's point faces the viewer. */
export class Projection {
  readonly cxp: number; readonly cyp: number; readonly radius: number;
  private sLat: number; private cLat: number; private sLon: number; private cLon: number;
  constructor(camera: Camera, width: number, height: number) {
    this.cxp = width / 2;
    this.cyp = height / 2;
    this.radius = Math.min(width, height) * 0.42 * camera.zoom;
    this.sLat = Math.sin(camera.latitude * Math.PI / 180);
    this.cLat = Math.cos(camera.latitude * Math.PI / 180);
    this.sLon = Math.sin(camera.longitude * Math.PI / 180);
    this.cLon = Math.cos(camera.longitude * Math.PI / 180);
  }
  rotate(ex: number, ey: number, ez: number): [number, number, number] {
    const c = ex * this.cLon + ey * this.sLon;
    return [ey * this.cLon - ex * this.sLon, this.cLat * ez - this.sLat * c, this.sLat * ez + this.cLat * c];
  }
  /** Screen position and depth (z > 0 faces the viewer). */
  project(lat: number, lon: number): [number, number, number] {
    const [x, y, z] = this.rotate(...unitVector(lat, lon));
    return [this.cxp + x * this.radius, this.cyp - y * this.radius, z];
  }
}

/** fitGlobeCamera: centre on the stamps and zoom until they all show. */
export function fitCamera(points: [number, number][], fallback: Camera, singlePointZoom = 6): Camera {
  if (points.length === 0) return { ...fallback, zoom: MIN_ZOOM };
  let sx = 0, sy = 0, sz = 0;
  for (const [lat, lon] of points) { const [x, y, z] = unitVector(lat, lon); sx += x; sy += y; sz += z; }
  const len = Math.hypot(sx, sy, sz);
  if (len < 1e-6 * points.length) return { ...fallback, zoom: MIN_ZOOM };
  const lat = Math.asin(Math.max(-1, Math.min(1, sz / len))) * 180 / Math.PI;
  const lon = Math.atan2(sy, sx) * 180 / Math.PI;
  const [ax, ay, az] = unitVector(lat, lon);
  let spread = 0;
  for (const [pLat, pLon] of points) {
    const [bx, by, bz] = unitVector(pLat, pLon);
    spread = Math.max(spread, Math.acos(Math.max(-1, Math.min(1, ax * bx + ay * by + az * bz))) * 180 / Math.PI);
  }
  const sinSpread = Math.sin(spread * Math.PI / 180);
  const zoom = spread >= 70 ? MIN_ZOOM : sinSpread < 1e-6 ? singlePointZoom : 0.85 / sinSpread;
  return clampCamera({ latitude: lat, longitude: lon, zoom: Math.min(zoom, singlePointZoom) });
}

const wrapAngle = (d: number) => { while (d > Math.PI) d -= 2 * Math.PI; while (d <= -Math.PI) d += 2 * Math.PI; return d; };

/** GlobePainter._addRing: one ring clipped to the visible hemisphere; a
 *  stretch behind the globe becomes an arc along the rim, swept the same
 *  way round, so a coastline over the horizon still encloses the right side. */
function addRing(path: Path2D, ring: Float32Array, p: Projection) {
  const n = ring.length / 3 - 1; // the last point repeats the first
  if (n < 3) return;
  const xs = new Float64Array(n), ys = new Float64Array(n), zs = new Float64Array(n);
  let start = -1, anyHidden = false;
  for (let i = 0; i < n; i++) {
    const [x, y, z] = p.rotate(ring[i * 3], ring[i * 3 + 1], ring[i * 3 + 2]);
    xs[i] = x; ys[i] = y; zs[i] = z;
    if (z > 0) { if (start < 0) start = i; } else anyHidden = true;
  }
  if (start < 0) return;
  const r = p.radius;
  let lastX = NaN, lastY = NaN;
  const emit = (x: number, y: number, force = false) => {
    const sx = p.cxp + x * r, sy = p.cyp - y * r;
    if (!force && Math.abs(sx - lastX) < 0.6 && Math.abs(sy - lastY) < 0.6) return;
    if (Number.isNaN(lastX)) path.moveTo(sx, sy); else path.lineTo(sx, sy);
    lastX = sx; lastY = sy;
  };
  if (!anyHidden) {
    for (let i = 0; i < n; i++) emit(xs[i], ys[i]);
    path.closePath();
    return;
  }
  let exitAngle = 0, prevAngle = 0, sweep = 0;
  emit(xs[start], ys[start], true);
  for (let k = 0; k < n; k++) {
    const a = (start + k) % n, b = (start + k + 1) % n;
    const za = zs[a], zb = zs[b];
    if (za > 0 && zb > 0) {
      emit(xs[b], ys[b], b === start);
    } else if (za > 0) {
      const t = za / (za - zb);
      exitAngle = Math.atan2(ys[a] + (ys[b] - ys[a]) * t, xs[a] + (xs[b] - xs[a]) * t);
      emit(Math.cos(exitAngle), Math.sin(exitAngle), true);
      prevAngle = exitAngle;
      sweep = wrapAngle(Math.atan2(ys[b], xs[b]) - prevAngle);
      prevAngle = Math.atan2(ys[b], xs[b]);
    } else if (zb <= 0) {
      const angle = Math.atan2(ys[b], xs[b]);
      sweep += wrapAngle(angle - prevAngle);
      prevAngle = angle;
    } else {
      const t = za / (za - zb);
      const entry = Math.atan2(ys[a] + (ys[b] - ys[a]) * t, xs[a] + (xs[b] - xs[a]) * t);
      sweep += wrapAngle(entry - prevAngle);
      const steps = Math.ceil(Math.abs(sweep) / (Math.PI / 36));
      for (let s = 1; s <= steps; s++) {
        const angle = exitAngle + (sweep * s) / steps;
        emit(Math.cos(angle), Math.sin(angle), s === steps);
      }
      emit(xs[b], ys[b], b === start);
    }
  }
  path.closePath();
}

const IVORY = '244, 240, 231';

/** GlobePainter.paint: the sea, the graticule, the land (visited lit), the rim. */
export function paintGlobe(ctx: CanvasRenderingContext2D, width: number, height: number, camera: Camera, countries: GlobeCountry[], visited: Set<string>) {
  const p = new Projection(camera, width, height);
  const { cxp: cx, cyp: cy, radius: r } = p;
  ctx.clearRect(0, 0, width, height);

  // A soft halo just outside the disc.
  const halo = ctx.createRadialGradient(cx, cy, r, cx, cy, r * 1.07);
  halo.addColorStop(0, `rgba(${IVORY}, 0.10)`);
  halo.addColorStop(1, `rgba(${IVORY}, 0)`);
  ctx.fillStyle = halo;
  ctx.beginPath(); ctx.arc(cx, cy, r * 1.07, 0, Math.PI * 2); ctx.fill();

  // Sea: forestGreen → deepGreen → darkGreen, lit from the upper left.
  const sea = ctx.createRadialGradient(cx - 0.35 * r, cy - 0.45 * r, 0, cx - 0.35 * r, cy - 0.45 * r, r * 2.2);
  sea.addColorStop(0, '#23473D'); sea.addColorStop(0.6, '#16302A'); sea.addColorStop(1, '#0E241F');
  ctx.fillStyle = sea;
  ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();

  ctx.save();
  ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.clip();

  const grid = new Path2D();
  const line = (points: [number, number][]) => {
    let drawing = false;
    for (const [lat, lon] of points) {
      const [x, y, z] = p.project(lat, lon);
      if (z <= 0) drawing = false;
      else if (drawing) grid.lineTo(x, y);
      else { grid.moveTo(x, y); drawing = true; }
    }
  };
  for (let lat = -60; lat <= 60; lat += 30) line(Array.from({ length: 121 }, (_, i) => [lat, -180 + i * 3] as [number, number]));
  for (let lon = -180; lon < 180; lon += 30) line(Array.from({ length: 57 }, (_, i) => [-84 + i * 3, lon] as [number, number]));
  ctx.strokeStyle = `rgba(${IVORY}, 0.07)`;
  ctx.lineWidth = 0.6;
  ctx.stroke(grid);

  const lit = new Path2D(), other = new Path2D();
  for (const c of countries) {
    const [, , z] = p.rotate(c.cx, c.cy, c.cz);
    if (z < -Math.sin(Math.min(c.radius, Math.PI / 2))) continue;
    const target = visited.has(c.code) ? lit : other;
    for (const ring of c.rings) addRing(target, ring, p);
  }
  ctx.fillStyle = `rgba(${IVORY}, 0.34)`;
  ctx.fill(other, 'evenodd');
  ctx.fillStyle = `rgb(${IVORY})`;
  ctx.fill(lit, 'evenodd');
  ctx.strokeStyle = 'rgba(22, 48, 42, 0.35)';
  ctx.lineWidth = 0.5;
  ctx.stroke(other);
  ctx.stroke(lit);

  // Shade towards the rim so the disc reads as a sphere.
  const shade = ctx.createRadialGradient(cx - 0.3 * r, cy - 0.4 * r, 0, cx - 0.3 * r, cy - 0.4 * r, r * 2.3);
  shade.addColorStop(0, 'rgba(14, 33, 28, 0)');
  shade.addColorStop(0.55, 'rgba(14, 33, 28, 0)');
  shade.addColorStop(1, 'rgba(14, 33, 28, 0.55)');
  ctx.fillStyle = shade;
  ctx.fillRect(cx - r, cy - r, r * 2, r * 2);
  ctx.restore();

  ctx.strokeStyle = `rgba(${IVORY}, 0.18)`;
  ctx.lineWidth = 0.75;
  ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
  return p;
}

const HIDE_DEPTH = 0.06, FULL_DEPTH = 0.25;

/** clusterOnGlobe: pins closer than [merge] px share one marker; pins on
 *  the far side are left out, those near the rim fade. */
export function clusterPins<T>(items: T[], p: Projection, lat: (t: T) => number, lon: (t: T) => number, merge = 30) {
  const groups: { members: T[]; ax: number; ay: number; sx: number; sy: number; depth: number }[] = [];
  for (const item of items) {
    const [x, y, z] = p.project(lat(item), lon(item));
    if (z <= HIDE_DEPTH) continue;
    const g = groups.find((g) => Math.hypot(g.ax - x, g.ay - y) < merge);
    if (g) { g.members.push(item); g.sx += x; g.sy += y; g.depth = Math.max(g.depth, z); }
    else groups.push({ members: [item], ax: x, ay: y, sx: x, sy: y, depth: z });
  }
  return groups.map((g) => ({
    members: g.members,
    x: g.sx / g.members.length,
    y: g.sy / g.members.length,
    opacity: Math.max(0, Math.min(1, (g.depth - HIDE_DEPTH) / (FULL_DEPTH - HIDE_DEPTH))),
  }));
}
