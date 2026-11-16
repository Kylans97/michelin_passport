// The app's own country outlines (assets/globe/countries.bin, Natural
// Earth 1:50m, built by scripts/build_globe_outlines.py), served beside
// the signed-in globe so both draw the same coastlines from one file.
import type { APIRoute } from 'astro';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

export const GET: APIRoute = async () => {
  const bytes = await readFile(resolve(process.cwd(), '../assets/globe/countries.bin'));
  return new Response(bytes, { headers: { 'Content-Type': 'application/octet-stream' } });
};
