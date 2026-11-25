// The Website tab's words, kept apart from the DOM so they can be tested
// (studio/website.test.js). Numbers come from the studio-web-analytics
// Edge Function; see supabase/functions/studio-web-analytics/index.ts for
// what each one means.

const fmt = new Intl.NumberFormat("en-GB");
const num = (n) => (n == null ? "–" : fmt.format(n));

/** "Up 18% on the 30 days before", or null when there is nothing to compare. */
export function compareText(now, before, days) {
  if (before == null || now == null) return null;
  const span = days === 365 ? "12 months" : `${days} days`;
  if (before === 0) return now === 0 ? null : `None in the ${span} before`;
  const change = Math.round(((now - before) / before) * 100);
  if (Math.abs(change) < 3) return `About the same as the ${span} before`;
  return `${change > 0 ? "Up" : "Down"} ${Math.abs(change)}% on the ${span} before`;
}

/** Pages per visit in words, or null with no visits. */
export function perVisitText(pageViews, visits) {
  if (!visits) return null;
  const per = pageViews / visits;
  if (per < 1.15) return "Mostly one page per visit";
  return `About ${per < 10 ? per.toFixed(1).replace(/\.0$/, "") : Math.round(per)} per visit`;
}

/** The four tiles: [label, value, detail]. */
export function websiteTiles(res) {
  const w = res.website;
  const s = res.sign_ins ?? {};
  const signedIn = s.sign_ins
    ? `${num(s.sign_ins)} sign-in${s.sign_ins === 1 ? "" : "s"} on the website`
    : "On the website, in this period";
  return [
    ["Visits", w ? w.visits : null, w ? compareText(w.visits, w.visits_before, res.days) : null],
    ["Pages opened", w ? w.page_views : null, w ? perVisitText(w.page_views, w.visits) : null],
    ["Went to the App Store", w ? w.app_store : null, "From the website's App Store buttons"],
    ["Members signed in", s.members_signed_in ?? null, signedIn],
  ];
}

/** What to say when Cloudflare's numbers are missing. */
export function websiteProblem(error) {
  if (error === "not_configured") {
    return "Website visits will show here once the Cloudflare key is added to Supabase.";
  }
  return "Cloudflare did not answer just now, so website visits are missing. Try again in a few minutes.";
}

/** A note when the period reaches back further than Cloudflare keeps. */
export function historyNote(historyFrom) {
  if (!historyFrom) return null;
  const date = new Date(historyFrom).toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric" });
  return `Cloudflare keeps visits from ${date} onwards, so this period starts there.`;
}

/** Devices as shares of all visits. */
export function deviceRows(devices, visits) {
  return devices.map((d) => ({
    label: d.label,
    value: d.value,
    extra: visits ? `${Math.round((d.value / visits) * 100)}%` : null,
  }));
}
