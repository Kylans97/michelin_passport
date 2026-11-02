// Mantelier Studio — the admin dashboard (phase 1 of
// docs/Architecture/VENUE_INSIGHTS_AND_SUBSCRIPTIONS_PLAN.md).
//
// Sign-in is the app account plus a code from an authenticator app.
// Everything shown comes from two RPCs, both of which check on the server
// who is asking: admin_studio_report (admin and two-step, 20261101220000)
// and admin_get_member_insights (admin, 20261101210000). Nothing here is
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

  // Admins only, asked before two-step sign-in, so a member who isn't
  // one is never asked to set up an authenticator for nothing. The
  // report itself checks again on the server; this only picks the screen.
  const { data: admin } = await supabase.rpc("is_admin");
  if (admin !== true) return show("denied");

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
  renderColumns($("chart-members"), r.weekly, "members_total");
  renderColumns($("chart-active"), r.weekly, "active_members");
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

// A small column chart in SVG, one column per week.
function renderColumns(target, weeks, key) {
  const W = 560, H = 200, padL = 36, padB = 24, padT = 10;
  const values = weeks.map((w) => w[key] ?? 0);
  const max = Math.max(...values, 1);
  const step = (W - padL) / values.length;
  const ns = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(ns, "svg");
  svg.setAttribute("viewBox", `0 0 ${W} ${H}`);
  svg.setAttribute("role", "img");

  const scale = (v) => padT + (H - padB - padT) * (1 - v / max);
  for (const t of [0, 0.5, 1]) {
    const y = scale(max * t);
    const line = document.createElementNS(ns, "line");
    Object.entries({ x1: padL, x2: W, y1: y, y2: y, class: "gridline" }).forEach(([a, b]) => line.setAttribute(a, b));
    const label = document.createElementNS(ns, "text");
    Object.entries({ x: padL - 6, y: y + 3, "text-anchor": "end", class: "axis" }).forEach(([a, b]) => label.setAttribute(a, b));
    label.textContent = num(Math.round(max * t));
    svg.append(line, label);
  }
  values.forEach((v, i) => {
    const x = padL + i * step + step * 0.18;
    const y = scale(v);
    const rect = document.createElementNS(ns, "rect");
    Object.entries({ x, y, width: step * 0.64, height: H - padB - y, rx: 3, fill: "var(--bar)" }).forEach(([a, b]) => rect.setAttribute(a, b));
    const title = document.createElementNS(ns, "title");
    title.textContent = `Week of ${weeks[i].week}: ${num(v)}`;
    rect.append(title);
    svg.append(rect);
    const every = Math.ceil(values.length / 6);
    if (i % every === 0 || i === values.length - 1) {
      const label = document.createElementNS(ns, "text");
      Object.entries({ x: x + step * 0.32, y: H - 6, "text-anchor": "middle", class: "axis" }).forEach(([a, b]) => label.setAttribute(a, b));
      label.textContent = new Date(weeks[i].week).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
      svg.append(label);
    }
  });
  target.className = "chart";
  target.replaceChildren(svg);
}

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

supabase.auth.onAuthStateChange((event) => {
  if (event === "SIGNED_OUT") show("login");
});

route();
