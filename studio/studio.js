// Mantelier Studio — the admin dashboard (phase 1 of
// docs/Architecture/VENUE_INSIGHTS_AND_SUBSCRIPTIONS_PLAN.md).
//
// Sign-in is the app account plus a code from an authenticator app.
// Everything shown comes from two RPCs, both of which check on the server
// who is asking: admin_studio_report (admin and two-step, 20261101230000)
// and admin_get_member_insights (admin, 20261101210000). is_admin()
// itself requires two-step since 20261101220000. Nothing here is
// a permission check — a found URL shows a sign-in page and nothing else.
//
// All data is written with textContent, never innerHTML: venue and event
// names are venue-supplied text.

import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm";

const { supabaseUrl, supabaseAnonKey } = window.STUDIO_CONFIG;

// Session lives in this tab only: closing it signs you out.
const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: { storage: window.sessionStorage, persistSession: true, autoRefreshToken: true },
});

const views = ["login", "enroll", "verify", "denied", "dashboard"];
const $ = (id) => document.getElementById(id);

function show(name) {
  for (const v of views) $(`view-${v}`).hidden = v !== name;
}

function el(tag, props = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(props)) {
    if (k === "class") node.className = v;
    else if (k === "text") node.textContent = v;
    else node.setAttribute(k, v);
  }
  for (const c of children) if (c != null) node.append(c);
  return node;
}

const fmt = new Intl.NumberFormat("en-GB");
const num = (n) => (n == null ? "–" : fmt.format(n));

// ---------------------------------------------------------------- sign-in

let enrollFactorId = null;

async function route() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return show("login");

  // is_admin() is true only after the code (20261101220000). Before it,
  // admin_two_step_pending() says whether this is an admin still owing
  // the code, so a member who isn't one is never asked to set up an
  // authenticator for nothing. The report checks again on the server;
  // this only picks the screen.
  const { data: admin } = await supabase.rpc("is_admin");
  let allowed = admin === true;
  if (!allowed) {
    const { data: pending } = await supabase.rpc("admin_two_step_pending");
    allowed = pending === true;
  }
  if (!allowed) return show("denied");

  const { data: aal, error } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (error) return fail("login-error", error.message, "login");

  if (aal.currentLevel === "aal2") return openDashboard();
  if (aal.nextLevel === "aal2") {
    show("verify");
    $("verify-code").focus();
    return;
  }
  return startEnroll();
}

async function startEnroll() {
  // A half-finished set-up from an earlier visit is removed first, so
  // the QR code on screen is always the one that will be checked.
  const { data: factors } = await supabase.auth.mfa.listFactors();
  for (const f of factors?.all ?? []) {
    if (f.status !== "verified") await supabase.auth.mfa.unenroll({ factorId: f.id });
  }
  const { data, error } = await supabase.auth.mfa.enroll({
    factorType: "totp",
    friendlyName: "Mantelier Studio",
  });
  if (error) return fail("login-error", `Two-step sign-in could not start: ${error.message}`, "login");
  enrollFactorId = data.id;
  $("enroll-qr").src = data.totp.qr_code;
  $("enroll-secret").textContent = data.totp.secret;
  show("enroll");
  $("enroll-code").focus();
}

function fail(errorId, message, view) {
  if (view) show(view);
  $(errorId).textContent = message;
}

$("login-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const button = e.submitter;
  button.disabled = true;
  $("login-error").textContent = "";
  const { error } = await supabase.auth.signInWithPassword({
    email: $("login-email").value.trim(),
    password: $("login-password").value,
  });
  button.disabled = false;
  if (error) return fail("login-error", "Email or password is not right.");
  $("login-password").value = "";
  route();
});

$("enroll-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const { error } = await supabase.auth.mfa.challengeAndVerify({
    factorId: enrollFactorId,
    code: $("enroll-code").value.trim(),
  });
  if (error) return fail("enroll-error", "That code didn't match. Try the newest one.");
  $("enroll-code").value = "";
  route();
});

$("verify-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const { data: factors } = await supabase.auth.mfa.listFactors();
  const totp = factors?.totp?.[0];
  if (!totp) return startEnroll();
  const { error } = await supabase.auth.mfa.challengeAndVerify({
    factorId: totp.id,
    code: $("verify-code").value.trim(),
  });
  if (error) return fail("verify-error", "That code didn't match. Try the newest one.");
  $("verify-code").value = "";
  route();
});

document.addEventListener("click", async (e) => {
  if (e.target.closest("[data-action='sign-out']")) {
    await supabase.auth.signOut();
    show("login");
  }
});

// -------------------------------------------------------------- dashboard

let countryNames = null;

async function loadCountries() {
  if (countryNames) return countryNames;
  const { data } = await supabase.from("countries").select("country_code, name, flag_emoji");
  countryNames = Object.fromEntries((data ?? []).map((c) => [c.country_code, c]));
  return countryNames;
}

function countryLabel(code) {
  if (!code || code === "none") return "Not given";
  const c = countryNames?.[code];
  return c ? `${c.flag_emoji ?? ""} ${c.name}`.trim() : code;
}

async function openDashboard() {
  show("dashboard");
  await load();
}

async function load() {
  const days = Number($("period").value);
  const status = $("status");
  status.className = "note";
  status.textContent = "Loading…";

  const [report, insights] = await Promise.all([
    supabase.rpc("admin_studio_report", { p_days: days }),
    supabase.rpc("admin_get_member_insights"),
    loadCountries(),
  ]);

  if (report.error) {
    const msg = report.error.message ?? "";
    if (msg.includes("not_admin")) return show("denied");
    if (msg.includes("mfa_required")) return route();
    status.className = "note error";
    status.textContent = `Could not load the studio: ${msg}`;
    return;
  }

  const r = report.data;
  const when = new Date(r.generated_at).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" });
  status.textContent = `Last ${r.days} days · as of ${when}`;

  renderTiles(r);
  renderColumns($("chart-members"), r.weekly, "members_total", weekLabel);
  renderColumns($("chart-active"), r.weekly, "active_members", weekLabel);
  renderBars($("screens"), r.screens.map((s) => ({ label: titleCase(s.screen), value: s.opens, extra: `${num(s.members)} members` })));
  renderExplore(r.explore);
  renderVenues(r.top_venues);
  renderEvents(r.top_events);
  renderInsights(insights.data ?? []);
  renderBars($("trips"), r.trip_countries.map((t) => ({ label: countryLabel(t.country), value: t.trips })), "No upcoming trips yet.");
}

$("period").addEventListener("change", load);

function titleCase(s) {
  return (s ?? "").replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase());
}

function renderTiles(r) {
  const o = r.overview;
  const tiles = [
    ["Members", o.members, `+${num(o.new_members)} in ${r.days} days`],
    ["Active members", o.active_members, `in ${r.days} days`],
    ["Visits recorded", o.visits, `${num(o.visits_in_period)} in ${r.days} days`],
    ["Follows", o.follows, "restaurants, hotels, chefs"],
    ["Wishlist saves", o.wishlist, null],
    ["Trips", o.trips, null],
    ["Managed venues", o.managed_venues, "with an active manager"],
    ["Upcoming events", o.upcoming_events, "published"],
  ];
  $("tiles").replaceChildren(
    ...tiles.map(([k, v, d]) =>
      el("div", { class: "tile" },
        el("div", { class: "k", text: k }),
        el("div", { class: "v", text: num(v) }),
        d ? el("div", { class: "d", text: d }) : null,
      ),
    ),
  );
}

function renderBars(target, rows, emptyText = "Nothing in this period.") {
  if (!rows.length) return target.replaceChildren(el("p", { class: "empty", text: emptyText }));
  const max = Math.max(...rows.map((r) => r.value ?? 0), 1);
  target.replaceChildren(
    el("div", { class: "hbars" },
      ...rows.map((r) => {
        const fill = el("div", { class: "fill" });
        fill.style.width = `${((r.value ?? 0) / max) * 100}%`;
        const numCell = el("span", { class: "num", text: r.value == null ? "fewer than 5" : num(r.value) });
        if (r.extra) numCell.append(" ", el("small", { text: `· ${r.extra}` }));
        return el("div", { class: "hbar" },
          el("span", { class: "label", text: r.label, title: r.label }),
          el("div", { class: "track" }, fill),
          numCell,
        );
      }),
    ),
  );
}

// A small column chart in SVG, one column per row. [label] gives each
// column's axis label and tooltip; a null value is a group under 5 and is
// drawn as a hairline with "fewer than 5" in its tooltip.
function renderColumns(target, rows, key, label = (r) => r.week) {
  const W = 560, H = 200, padL = 36, padB = 24, padT = 10;
  const values = rows.map((r) => r[key]);
  const max = Math.max(...values.map((v) => v ?? 0), 1);
  const step = (W - padL) / Math.max(values.length, 1);
  const ns = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(ns, "svg");
  svg.setAttribute("viewBox", `0 0 ${W} ${H}`);
  svg.setAttribute("role", "img");

  const scale = (v) => padT + (H - padB - padT) * (1 - v / max);
  for (const t of [0, 0.5, 1]) {
    const y = scale(max * t);
    const line = document.createElementNS(ns, "line");
    Object.entries({ x1: padL, x2: W, y1: y, y2: y, class: "gridline" }).forEach(([a, b]) => line.setAttribute(a, b));
    const text = document.createElementNS(ns, "text");
    Object.entries({ x: padL - 6, y: y + 3, "text-anchor": "end", class: "axis" }).forEach(([a, b]) => text.setAttribute(a, b));
    text.textContent = num(Math.round(max * t));
    svg.append(line, text);
  }
  values.forEach((v, i) => {
    const x = padL + i * step + step * 0.18;
    const hidden = v == null;
    const y = hidden ? H - padB - 2 : scale(v);
    const rect = document.createElementNS(ns, "rect");
    Object.entries({
      x, y, width: step * 0.64, height: Math.max(H - padB - y, 2), rx: 3,
      fill: hidden ? "var(--line)" : "var(--bar)",
    }).forEach(([a, b]) => rect.setAttribute(a, b));
    const title = document.createElementNS(ns, "title");
    title.textContent = `${label(rows[i], true)}: ${hidden ? "fewer than 5" : num(v)}`;
    rect.append(title);
    svg.append(rect);
    const every = Math.ceil(values.length / 6);
    if (i % every === 0 || i === values.length - 1) {
      const text = document.createElementNS(ns, "text");
      Object.entries({ x: x + step * 0.32, y: H - 6, "text-anchor": "middle", class: "axis" }).forEach(([a, b]) => text.setAttribute(a, b));
      text.textContent = label(rows[i], false);
      svg.append(text);
    }
  });
  target.className = "chart";
  target.replaceChildren(svg);
}

const weekLabel = (w, long) => long
  ? `Week of ${w.week}`
  : new Date(w.week).toLocaleDateString("en-GB", { day: "numeric", month: "short" });

const monthLabel = (m, long) => new Date(`${m.month}-01`).toLocaleDateString(
  "en-GB", long ? { month: "long", year: "numeric" } : { month: "short" });

function renderExplore(x) {
  renderBars($("explore"), [
    { label: "Searches", value: x.searches, extra: `${num(x.search_members)} members` },
    { label: "Filter changes", value: x.filters, extra: `${num(x.filter_members)} members` },
  ]);
}

function table(target, columns, rows, emptyText) {
  if (!rows.length) return target.replaceChildren(el("p", { class: "empty", text: emptyText }));
  const head = el("tr", {}, ...columns.map((c) => el("th", { text: c.label })));
  const body = rows.map((row) =>
    el("tr", {}, ...columns.map((c) => {
      const value = c.value(row);
      if (value instanceof Node) return el("td", {}, value);
      const td = el("td", { text: typeof value === "number" ? num(value) : value ?? "" });
      if (value === 0) td.classList.add("zero");
      return td;
    })),
  );
  target.replaceChildren(el("table", {}, el("thead", {}, head), el("tbody", {}, ...body)));
}

const typeLabel = { restaurant: "Restaurant", hotel: "Hotel", private_chef: "Private chef" };

function renderVenues(rows) {
  table($("venues"), [
    { label: "Venue", value: (v) => {
      const cell = document.createDocumentFragment();
      cell.append(v.name ?? "Unknown venue",
        el("span", { class: "where", text: [typeLabel[v.venue_type], v.city, v.country].filter(Boolean).join(" · ") }));
      return cell;
    } },
    { label: "Opens", value: (v) => v.opens },
    { label: "Visitors", value: (v) => v.visitors },
    { label: "Website", value: (v) => v.website },
    { label: "Booking", value: (v) => v.booking },
    { label: "Phone", value: (v) => v.phone },
    { label: "Directions", value: (v) => v.directions },
    { label: "New followers", value: (v) => v.follows },
  ], rows, "No venue activity in this period.");
}

function renderEvents(rows) {
  table($("events"), [
    { label: "Event", value: (e) => {
      const cell = document.createDocumentFragment();
      const date = e.start_date ? new Date(e.start_date).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" }) : null;
      cell.append(e.name, el("span", { class: "where", text: [date, e.city, e.country].filter(Boolean).join(" · ") }));
      return cell;
    } },
    { label: "Opens", value: (e) => e.opens },
    { label: "Interested", value: (e) => e.interested },
    { label: "Going", value: (e) => e.going },
    { label: "Attended", value: (e) => e.attended },
  ], rows, "No event activity in this period.");
}

const ageOrder = ["16-24", "25-34", "35-44", "45-54", "55-64", "65+", "none"];

function renderInsights(rows) {
  const countries = rows
    .filter((r) => r.dimension === "country")
    .sort((a, b) => (b.members ?? 0) - (a.members ?? 0))
    .map((r) => ({ label: countryLabel(r.bucket), value: r.members }));
  const ages = rows
    .filter((r) => r.dimension === "age")
    .sort((a, b) => ageOrder.indexOf(a.bucket) - ageOrder.indexOf(b.bucket))
    .map((r) => ({ label: r.bucket === "none" ? "Not given" : r.bucket, value: r.members }));
  renderBars($("countries"), countries, "No members yet.");
  renderBars($("ages"), ages, "No members yet.");
}

// ------------------------------------------------------- Basic and Pro
//
// What one venue would see on each subscription, for showing venues the
// future state. Real venues come from admin_studio_venue_report and
// admin_studio_market_report (20261101240000), already with every group
// under 5 people hidden, exactly as a venue would get them. "Example
// venue" is fictional data, clearly bannered, so a conversation with one
// venue never shows another real venue's numbers. Panels for what isn't
// measured yet carry an "Example" badge whatever venue is chosen.

let activeTab = "overview";
let tierVenue = null; // { report, market, example }
let marketCache = null;

document.querySelectorAll("[data-tab]").forEach((b) =>
  b.addEventListener("click", () => openTab(b.dataset.tab)),
);

function openTab(tab) {
  activeTab = tab;
  document.querySelectorAll("[data-tab]").forEach((b) =>
    b.classList.toggle("is-active", b.dataset.tab === tab),
  );
  $("tab-overview").hidden = tab !== "overview";
  $("tab-tiers").hidden = tab === "overview";
  // Kept in the layout, only made invisible: removing it narrowed the
  // right of the bar and slid the tabs sideways on every switch.
  $("period-control").style.visibility = tab === "overview" ? "" : "hidden";
  $("tier-basic").hidden = tab === "overview";
  $("tier-pro").hidden = tab !== "pro";
  if (tab !== "overview") {
    if (!tierVenue) showExample();
    else renderTier();
  }
}

// ---- picker

let searchTimer = null;
$("venue-search").addEventListener("input", (e) => {
  clearTimeout(searchTimer);
  const q = e.target.value.trim();
  if (q.length < 2) {
    $("venue-results").hidden = true;
    return;
  }
  searchTimer = setTimeout(() => findVenues(q), 250);
});

async function findVenues(q) {
  const { data, error } = await supabase.rpc("admin_studio_find_venues", { p_query: q });
  const box = $("venue-results");
  box.hidden = false;
  if (error) return box.replaceChildren(el("p", { class: "empty", text: `Search failed: ${error.message}` }));
  if (!data.length) return box.replaceChildren(el("p", { class: "empty", text: "No venue by that name." }));
  box.replaceChildren(
    ...data.map((v) => {
      const b = el("button", { type: "button" }, v.name,
        el("span", { class: "where", text: [typeLabel[v.venue_type], v.city, v.country].filter(Boolean).join(" · ") }));
      b.addEventListener("click", () => openVenue(v.venue_type, v.venue_id));
      return b;
    }),
  );
}

$("venue-example").addEventListener("click", showExample);

async function openVenue(type, id) {
  $("venue-results").hidden = true;
  $("tier-note").textContent = "Loading…";
  const [report, market] = await Promise.all([
    supabase.rpc("admin_studio_venue_report", { p_venue_type: type, p_venue_id: id }),
    marketCache ? Promise.resolve({ data: marketCache }) : supabase.rpc("admin_studio_market_report"),
  ]);
  if (report.error || market.error) {
    $("tier-note").textContent = `Could not load: ${(report.error ?? market.error).message}`;
    return;
  }
  marketCache = market.data;
  tierVenue = { report: report.data, market: market.data, example: false };
  $("tier-note").textContent =
    "Real numbers, as this venue would see them. Show them to this venue only.";
  renderTier();
}

function showExample() {
  $("venue-results").hidden = true;
  $("venue-search").value = "";
  tierVenue = { report: exampleReport(), market: exampleMarket(), example: true };
  $("tier-note").textContent = "Search a venue for its real numbers, or show the example.";
  renderTier();
}

// ---- rendering

function renderTier() {
  const { report: r, market: m, example } = tierVenue;
  $("example-banner").hidden = !example;
  const v = r.venue;
  $("venue-kind").textContent = typeLabel[v.type] ?? "";
  $("venue-name").textContent = v.name;
  $("venue-meta").textContent = [
    v.cuisine,
    v.stars ? `${v.stars} MICHELIN ${v.stars === 1 ? "Star" : "Stars"}` : null,
    [v.city, countryLabel(v.country)].filter(Boolean).join(", "),
  ].filter(Boolean).join(" · ");

  renderBasic(r.basic);
  if (activeTab === "pro") renderPro(r, m);
}

function hiddenNum(n) {
  return n == null ? "fewer than 5" : num(n);
}

function renderBasic(b) {
  const t = b.totals;
  const tiles = [
    ["Visitors", t.visitors_12m, "last 12 months"],
    ["Followers", t.followers, "in total"],
    ["Wishlist saves", t.saves, "in total"],
    ["In Passports", t.visits, "members who recorded a visit"],
    ["Tapped through", t.tappers_12m, "website, booking, phone, route"],
    ["Rating", t.rating, t.raters ? `from ${num(t.raters)} members` : "shown from 3 ratings"],
  ];
  $("basic-tiles").replaceChildren(
    ...tiles.map(([k, val, d]) =>
      el("div", { class: "tile" },
        el("div", { class: "k", text: k }),
        el("div", { class: "v", text: val == null ? "–" : k === "Rating" ? String(val) : num(val) }),
        el("div", { class: "d", text: val == null && k !== "Rating" ? "fewer than 5" : d }),
      ),
    ),
  );
  renderColumns($("basic-visitors"), b.monthly, "visitors", monthLabel);
  renderColumns($("basic-followers"), b.monthly, "new_followers", monthLabel);
  renderColumns($("basic-saves"), b.monthly, "new_saves", monthLabel);
  const tapNames = { website: "Website", booking: "Booking", phone: "Phone", directions: "Directions" };
  renderBars($("basic-taps"), b.taps.map((x) => ({ label: tapNames[x.destination] ?? x.destination, value: x.people })),
    "No taps in the last 12 months.");
  table($("basic-events"), [
    { label: "Event", value: (e) => {
      const cell = document.createDocumentFragment();
      const date = e.start_date ? new Date(e.start_date).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" }) : null;
      cell.append(e.name, el("span", { class: "where", text: [date, e.city].filter(Boolean).join(" · ") }));
      return cell;
    } },
    { label: "Viewed", value: (e) => hiddenNum(e.viewers) },
    { label: "Interested", value: (e) => hiddenNum(e.interested) },
    { label: "Going", value: (e) => hiddenNum(e.going) },
    // An event still to come has no attendance yet, not "fewer than 5".
    { label: "Attended", value: (e) => e.start_date && new Date(e.start_date) > new Date() ? "–" : hiddenNum(e.attended) },
  ], b.events, "No events at this venue on Mantelier yet.");
}

const ageOrderTier = ["16-24", "25-34", "35-44", "45-54", "55-64", "65+", "none"];

function renderPro(r, m) {
  const p = r.pro;
  renderBars($("pro-country"), p.audience_country.map((x) => ({ label: countryLabel(x.country), value: x.people })),
    "No audience yet.");
  renderBars($("pro-age"),
    [...p.audience_age]
      .sort((a, b) => ageOrderTier.indexOf(a.age) - ageOrderTier.indexOf(b.age))
      .map((x) => ({ label: x.age === "none" ? "Not given" : x.age, value: x.people })),
    "No audience yet.");

  const bm = p.benchmark;
  $("pro-bench-sub").textContent = bm.group === "city"
    ? `Visitors in the last 90 days, next to ${num(bm.peers)} venues in the same city`
    : `Visitors in the last 90 days, next to ${num(bm.peers)} venues in the same country with the same stars`;
  if (bm.median == null) {
    $("pro-bench").replaceChildren(el("p", { class: "empty", text: "Fewer than 5 similar venues to compare with." }));
  } else {
    renderBars($("pro-bench"), [
      { label: "You", value: bm.you },
      { label: "Typical venue (median)", value: Math.round(bm.median) },
      { label: "Top quarter starts at", value: Math.round(bm.top_quarter) },
    ]);
  }
  renderColumns($("pro-trips"), p.trips, "city", monthLabel);

  renderBars($("pro-sources"), exampleSources().map((x) => ({ label: x.label, value: x.value })));
  renderBars($("pro-searches"), exampleSearches().map((x) => ({ label: x.label, value: x.value })));

  renderBars($("market-cuisines"), m.cuisines.map((x) => ({ label: x.cuisine, value: x.people })),
    "Not enough interest yet.");
  const typeNames = { dinner: "Dinner", lunch: "Lunch", festival: "Festival", gala: "Gala", tasting: "Tasting", brunch: "Brunch", party: "Party" };
  renderBars($("market-events"), [
    ...m.event_types.map((x) => ({ label: typeNames[x.type] ?? titleCase(x.type), value: x.people })),
    ...m.event_tags.map((x) => ({ label: `${x.tag} (tag)`, value: x.people })),
  ], "Not enough interest yet.");
  matrix($("market-where"), m.venue_country, "member_country", "venue_country",
    (c) => countryLabel(c), (c) => countryLabel(c), "Members from", "Not enough interest yet.");
  matrix($("market-cuisine-country"), m.cuisine_country, "member_country", "cuisine",
    (c) => countryLabel(c), (c) => c, "Members from", "Not enough interest yet.", 6);
  renderBars($("market-destinations"), m.destinations.map((x) => ({ label: countryLabel(x.country), value: x.people })),
    "No upcoming trips yet.");
  renderBars($("market-event-countries"), m.event_viewers.map((x) => ({ label: countryLabel(x.country), value: x.people })),
    "Not enough interest yet.");
}

// A small table: rows by [rowKey], columns by [colKey] (the most common
// [maxCols]), cells shaded by size; hidden groups show "<5".
function matrix(target, cells, rowKey, colKey, rowLabel, colLabel, corner, emptyText, maxCols = 8) {
  const shown = cells.filter((c) => c.people != null);
  if (!shown.length) return target.replaceChildren(el("p", { class: "empty", text: emptyText }));
  const colTotals = {};
  for (const c of shown) colTotals[c[colKey]] = (colTotals[c[colKey]] ?? 0) + c.people;
  const cols = Object.keys(colTotals).sort((a, b) => colTotals[b] - colTotals[a]).slice(0, maxCols);
  const rowTotals = {};
  for (const c of shown) rowTotals[c[rowKey]] = (rowTotals[c[rowKey]] ?? 0) + c.people;
  const rows = Object.keys(rowTotals).sort((a, b) => rowTotals[b] - rowTotals[a]);
  const max = Math.max(...shown.map((c) => c.people));
  const lookup = {};
  for (const c of cells) lookup[`${c[rowKey]}|${c[colKey]}`] = c;
  const head = el("tr", {}, el("th", { text: corner }), ...cols.map((c) => el("th", { text: colLabel(c) })));
  const body = rows.map((rk) =>
    el("tr", {}, el("td", { text: rowLabel(rk) }), ...cols.map((ck) => {
      const c = lookup[`${rk}|${ck}`];
      if (!c) return el("td", { class: "zero", text: "–" });
      if (c.people == null) return el("td", { class: "zero", text: "<5" });
      const td = el("td", { class: "heat", text: num(c.people) });
      td.style.background = `rgba(35, 71, 61, ${0.08 + 0.42 * (c.people / max)})`;
      return td;
    })),
  );
  target.replaceChildren(el("table", {}, el("thead", {}, head), el("tbody", {}, ...body)));
}

// ---- example data (fictional, deterministic)

function exampleMonths(base, growth, wobble) {
  const now = new Date();
  return Array.from({ length: 12 }, (_, i) => {
    const d = new Date(now.getFullYear(), now.getMonth() - 11 + i, 1);
    const month = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
    const seasonal = 1 + 0.18 * Math.sin((d.getMonth() / 12) * Math.PI * 2 + 1.2);
    const val = (b) => Math.round(b * (1 + growth * i) * seasonal * (1 + wobble * Math.sin(i * 2.3)));
    return {
      month,
      visitors: val(base),
      opens: val(base * 1.6),
      tappers: val(base * 0.34),
      new_followers: val(base * 0.12),
      new_saves: val(base * 0.09),
    };
  });
}

function exampleReport() {
  const now = new Date();
  const ahead = (n) => {
    const d = new Date(now.getFullYear(), now.getMonth() + n, 1);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
  };
  const inDays = (n) => new Date(now.getTime() + n * 86400000).toISOString().slice(0, 10);
  return {
    venue: { type: "restaurant", name: "Example Restaurant", city: "Amsterdam", country: "NL", stars: 2, cuisine: "Modern Cuisine" },
    basic: {
      monthly: exampleMonths(210, 0.045, 0.08),
      taps: [
        { destination: "booking", people: 486 },
        { destination: "website", people: 312 },
        { destination: "directions", people: 174 },
        { destination: "phone", people: 61 },
      ],
      totals: { visitors_12m: 2640, followers: 918, saves: 604, visits: 237, tappers_12m: 897, rating: 4.6, raters: 141 },
      events: [
        { name: "Four Hands with a guest chef", start_date: inDays(24), city: "Amsterdam", viewers: 1240, interested: 212, going: 64, attended: null },
        { name: "Winemaker dinner", start_date: inDays(-38), city: "Amsterdam", viewers: 860, interested: 140, going: 48, attended: 41 },
        { name: "Game season lunch", start_date: inDays(-96), city: "Amsterdam", viewers: 530, interested: 77, going: 29, attended: 26 },
      ],
    },
    pro: {
      audience_country: [
        { country: "NL", people: 1380 }, { country: "BE", people: 412 }, { country: "DE", people: 305 },
        { country: "GB", people: 188 }, { country: "FR", people: 121 }, { country: "US", people: 74 },
        { country: "none", people: 160 },
      ],
      audience_age: [
        { age: "16-24", people: 96 }, { age: "25-34", people: 612 }, { age: "35-44", people: 788 },
        { age: "45-54", people: 541 }, { age: "55-64", people: 302 }, { age: "65+", people: 118 },
        { age: "none", people: 183 },
      ],
      trips: [0, 1, 2, 3, 4, 5].map((n) => ({
        month: ahead(n),
        city: [148, 172, 131, 205, 244, 196][n],
        country: [410, 455, 388, 520, 610, 498][n],
      })),
      benchmark: { group: "city", peers: 38, you: 690, median: 270, top_quarter: 520 },
    },
  };
}

function exampleMarket() {
  return {
    cuisines: [
      ["Modern Cuisine", 3120], ["Creative", 2480], ["Japanese", 1760], ["French", 1540],
      ["Seafood", 1210], ["Italian", 1080], ["Farm to table", 930], ["Nordic", 640],
    ].map(([cuisine, people]) => ({ cuisine, people })),
    event_types: [
      ["dinner", 2210], ["festival", 1340], ["tasting", 860], ["lunch", 540], ["gala", 310],
    ].map(([type, people]) => ({ type, people })),
    event_tags: [["Four Hands", 1480], ["Guest Chef", 1290], ["Winemaker", 940]].map(([tag, people]) => ({ tag, people })),
    venue_country: [
      ["NL", "NL", 2410], ["NL", "BE", 980], ["NL", "FR", 760], ["NL", "DE", 410], ["NL", "IT", 520], ["NL", "DK", 230],
      ["BE", "BE", 1120], ["BE", "NL", 640], ["BE", "FR", 590], ["BE", "IT", 210],
      ["DE", "DE", 890], ["DE", "NL", 330], ["DE", "FR", 240], ["DE", "IT", 260],
      ["GB", "FR", 280], ["GB", "NL", 190], ["GB", "DK", 140], ["GB", "ES", 120],
    ].map(([member_country, venue_country, people]) => ({ member_country, venue_country, people })),
    cuisine_country: [
      ["NL", "Modern Cuisine", 1420], ["NL", "Creative", 1180], ["NL", "Japanese", 860], ["NL", "French", 610], ["NL", "Seafood", 540], ["NL", "Nordic", 300],
      ["BE", "Modern Cuisine", 690], ["BE", "French", 640], ["BE", "Creative", 520], ["BE", "Seafood", 330], ["BE", "Japanese", 210],
      ["DE", "Modern Cuisine", 540], ["DE", "Creative", 410], ["DE", "Italian", 380], ["DE", "Japanese", 270],
      ["GB", "Creative", 220], ["GB", "French", 190], ["GB", "Nordic", 150], ["GB", "Japanese", 140],
    ].map(([member_country, cuisine, people]) => ({ member_country, cuisine, people })),
    destinations: [["FR", 820], ["IT", 760], ["ES", 540], ["BE", 470], ["DK", 330], ["NL", 300], ["JP", 140]]
      .map(([country, people]) => ({ country, people })),
    event_viewers: [["NL", 3010], ["BE", 1420], ["FR", 1180], ["IT", 920], ["DE", 610], ["ES", 480]]
      .map(([country, people]) => ({ country, people })),
  };
}

// Not measured yet, for any venue: examples until plan §5 ships.
function exampleSources() {
  return [
    { label: "Search", value: 38 }, { label: "Map", value: 21 }, { label: "Guides", value: 16 },
    { label: "A friend's activity", value: 12 }, { label: "An event", value: 9 }, { label: "A notification", value: 4 },
  ].map((x) => ({ ...x, label: `${x.label} (%)` }));
}

function exampleSearches() {
  return [
    { label: "Amsterdam (city)", value: 1840 }, { label: "Japanese (cuisine)", value: 1210 },
    { label: "Four hands (event)", value: 960 }, { label: "Antwerp (city)", value: 720 },
    { label: "Seafood (cuisine)", value: 650 }, { label: "Copenhagen (city)", value: 410 },
  ];
}

supabase.auth.onAuthStateChange((event) => {
  if (event === "SIGNED_OUT") show("login");
});

route();
