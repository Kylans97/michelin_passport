// Read-only access to the public catalogue at build time, with the same
// public anon key the app and site/index.html already ship. Row level
// security decides what it can see: only published content.

export const SUPABASE_URL = 'https://wcmxugunvwsrulcpeyrc.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndjbXh1Z3VudndzcnVsY3BleXJjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2NTI0MzksImV4cCI6MjA5NjIyODQzOX0.zGpFb-_zhFKL281kYZVcrboSHbcjbLGl_e_lE1GehQg';

/** GET one PostgREST query, e.g. `select('news_articles', 'select=id,title')`.
 *  Throws on any non-200, so a failed read fails the build instead of
 *  publishing a site with silently missing content. */
export async function select<T>(table: string, query: string): Promise<T[]> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${query}`, {
    headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${SUPABASE_ANON_KEY}` },
  });
  if (!res.ok) {
    throw new Error(`Supabase read of ${table} failed: ${res.status} ${await res.text()}`);
  }
  return (await res.json()) as T[];
}

/** `in.(a,b,c)` for a PostgREST filter. */
export const inList = (ids: string[]) => `in.(${ids.join(',')})`;

/** Every row of a query, read 1000 at a time (PostgREST's page size).
 *  [query] must carry its own `order=` so pages never overlap or skip. */
export async function selectAll<T>(table: string, query: string): Promise<T[]> {
  const pageSize = 1000;
  const all: T[] = [];
  for (let offset = 0; ; offset += pageSize) {
    const page = await select<T>(table, `${query}&limit=${pageSize}&offset=${offset}`);
    all.push(...page);
    if (page.length < pageSize) return all;
  }
}
