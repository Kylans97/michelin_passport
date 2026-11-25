// Run: deno test studio/website.test.js
import { assertEquals } from "jsr:@std/assert@1";
import { compareText, deviceRows, historyNote, perVisitText, websiteProblem, websiteTiles } from "./website.js";

Deno.test("comparison in plain words", () => {
  assertEquals(compareText(118, 100, 30), "Up 18% on the 30 days before");
  assertEquals(compareText(80, 100, 30), "Down 20% on the 30 days before");
  assertEquals(compareText(101, 100, 7), "About the same as the 7 days before");
  assertEquals(compareText(5, 0, 365), "None in the 12 months before");
  assertEquals(compareText(0, 0, 30), null);
  assertEquals(compareText(10, null, 30), null, "no comparison when Cloudflare no longer keeps it");
});

Deno.test("pages per visit", () => {
  assertEquals(perVisitText(3902, 1284), "About 3 per visit");
  assertEquals(perVisitText(250, 100), "About 2.5 per visit");
  assertEquals(perVisitText(105, 100), "Mostly one page per visit");
  assertEquals(perVisitText(10, 0), null);
});

Deno.test("tiles with and without Cloudflare", () => {
  const signIns = { members_signed_in: 41, sign_ins: 58, members_signed_in_before: 30 };
  const full = websiteTiles({
    days: 30,
    sign_ins: signIns,
    website: { visits: 1284, page_views: 3902, app_store: 96, visits_before: 1088 },
  });
  assertEquals(full.map((t) => t[1]), [1284, 3902, 96, 41]);
  assertEquals(full[0][2], "Up 18% on the 30 days before");
  assertEquals(full[3][2], "58 sign-ins on the website");

  const none = websiteTiles({ days: 30, sign_ins: signIns, website: null });
  assertEquals(none.map((t) => t[1]), [null, null, null, 41], "sign-ins still show without Cloudflare");
});

Deno.test("problems and history in plain words", () => {
  assertEquals(websiteProblem("not_configured").includes("Cloudflare key"), true);
  assertEquals(websiteProblem("unavailable").includes("Try again"), true);
  assertEquals(historyNote(null), null);
  assertEquals(historyNote("2026-05-26T12:00:00Z"), "Cloudflare keeps visits from 26 May 2026 onwards, so this period starts there.");
});

Deno.test("no dashes in what Studio says", () => {
  const texts = [
    compareText(118, 100, 30), perVisitText(3902, 1284), websiteProblem("not_configured"),
    websiteProblem("unavailable"), historyNote("2026-05-26T12:00:00Z"),
    ...websiteTiles({ days: 30, sign_ins: { sign_ins: 2, members_signed_in: 1 }, website: null }).flatMap((t) => [t[0], t[2]]),
  ].filter(Boolean);
  for (const t of texts) assertEquals(/[–—]| - /.test(t), false, t);
});

Deno.test("device shares", () => {
  assertEquals(deviceRows([{ label: "Phone", value: 80 }, { label: "Computer", value: 40 }], 120), [
    { label: "Phone", value: 80, extra: "67%" },
    { label: "Computer", value: 40, extra: "33%" },
  ]);
});
