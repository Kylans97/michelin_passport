// The build's own names and addresses for what a member saved
// (src/pages/account/catalogue/[shard].json.ts): only the parts holding
// the given ids are fetched, each once per page.
import type { AccountCatalogue } from '../../pages/account/catalogue/[shard].json';

const shards = new Map<string, Promise<AccountCatalogue>>();

function shard(key: string): Promise<AccountCatalogue> {
  let part = shards.get(key);
  if (!part) {
    part = fetch(`/account/catalogue/${key}.json`).then((res) => {
      if (!res.ok) throw new Error(`catalogue ${key}: ${res.status}`);
      return res.json() as Promise<AccountCatalogue>;
    });
    shards.set(key, part);
  }
  return part;
}

/** Everything the build knows about [ids], merged. */
export async function catalogue(ids: string[]): Promise<AccountCatalogue> {
  const keys = [...new Set(ids.map((id) => id[0]?.toLowerCase()).filter((k) => k && /[0-9a-f]/.test(k)))];
  const parts = await Promise.all(keys.map(shard));
  const out: AccountCatalogue = { r: {}, h: {}, e: {} };
  for (const p of parts) {
    Object.assign(out.r, p.r);
    Object.assign(out.h, p.h);
    Object.assign(out.e, p.e);
  }
  return out;
}

export const starLabel = (stars: number | null) =>
  stars && stars > 0 ? '★'.repeat(stars) : null;

/** Puts text into a new element; never HTML, since names come from data. */
export function el<K extends keyof HTMLElementTagNameMap>(tag: K, className?: string, text?: string): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}
