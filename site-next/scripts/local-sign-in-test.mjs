// Prepares a LOCAL Supabase stack (`supabase start`) for testing sign-in on
// the site: two test members, one with two-step sign-in on, and a few
// upcoming published events copied from production's public read so the
// event pages built from production have matching rows locally.
//
//   LOCAL_SUPABASE_URL=http://127.0.0.1:54321 \
//   LOCAL_SERVICE_ROLE_KEY=<from `supabase status`> \
//   node scripts/local-sign-in-test.mjs [event-id …]
//
// Refuses any URL that isn't on this machine. Prints the two-step secret
// and a current code, so the code step can be tested by hand too. The test
// accounts below exist only in a local stack.
import { createHmac } from 'node:crypto';
import { createClient } from '@supabase/supabase-js';
import { SUPABASE_ANON_KEY as PROD_ANON_KEY, SUPABASE_URL as PROD_URL } from '../src/lib/supabase.ts';

export const TEST_MEMBERS = [
  { email: 'web-signin@mantelier.test', password: 'local-test-only-1', display_name: 'Web Tester', username: 'web_tester' },
  { email: 'web-twostep@mantelier.test', password: 'local-test-only-2', display_name: 'Two Step Tester', username: 'two_step_tester', twoStep: true },
];

const url = process.env.LOCAL_SUPABASE_URL;
const serviceKey = process.env.LOCAL_SERVICE_ROLE_KEY;
const anonKey = process.env.LOCAL_ANON_KEY;
if (!url || !serviceKey || !anonKey) throw new Error('Set LOCAL_SUPABASE_URL, LOCAL_SERVICE_ROLE_KEY and LOCAL_ANON_KEY.');
if (!['127.0.0.1', 'localhost', '[::1]'].includes(new URL(url).hostname)) throw new Error(`Not a local stack: ${url}`);

const admin = createClient(url, serviceKey, { auth: { persistSession: false } });

function base32Decode(input) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const c of input.replace(/=+$/, '').toUpperCase()) bits += alphabet.indexOf(c).toString(2).padStart(5, '0');
  const bytes = [];
  for (let i = 0; i + 8 <= bits.length; i += 8) bytes.push(parseInt(bits.slice(i, i + 8), 2));
  return Buffer.from(bytes);
}

export function totp(secret, now = Date.now()) {
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(now / 30000)));
  const h = createHmac('sha1', base32Decode(secret)).update(counter).digest();
  const o = h[h.length - 1] & 0xf;
  return String((h.readUInt32BE(o) & 0x7fffffff) % 1_000_000).padStart(6, '0');
}

for (const m of TEST_MEMBERS) {
  const { data: list } = await admin.auth.admin.listUsers();
  let user = list.users.find((u) => u.email === m.email);
  if (!user) {
    const { data, error } = await admin.auth.admin.createUser({
      email: m.email,
      password: m.password,
      email_confirm: true,
      user_metadata: { display_name: m.display_name, username: m.username },
    });
    if (error) throw error;
    user = data.user;
  }
  console.log(`member ${m.email} ${user.id}`);
  if (!m.twoStep) continue;

  const member = createClient(url, anonKey, { auth: { persistSession: false } });
  const { error: signInError } = await member.auth.signInWithPassword({ email: m.email, password: m.password });
  if (signInError) throw signInError;
  const { data: factors } = await member.auth.mfa.listFactors();
  if (factors.totp.length === 0) {
    const { data: enrolled, error } = await member.auth.mfa.enroll({ factorType: 'totp', issuer: 'Mantelier', friendlyName: 'Authenticator' });
    if (error) throw error;
    const { error: verifyError } = await member.auth.mfa.challengeAndVerify({ factorId: enrolled.id, code: totp(enrolled.totp.secret) });
    if (verifyError) throw verifyError;
    console.log(`two-step secret ${enrolled.totp.secret} (code now: ${totp(enrolled.totp.secret)})`);
  } else {
    console.log('two-step already on');
  }
}

// Events: copied as published, from production's public read only.
const ids = process.argv.slice(2);
if (ids.length) {
  const cols = 'id,name,description,event_type,start_date,end_date,start_time,end_time,start_at,end_at,timezone,city,country_code,venue_name,address,official_url,ticket_url,cancelled_at,admission_type,moderation_status';
  const res = await fetch(`${PROD_URL}/rest/v1/events?select=${cols}&moderation_status=eq.published&id=in.(${ids.join(',')})`, {
    headers: { apikey: PROD_ANON_KEY, Authorization: `Bearer ${PROD_ANON_KEY}` },
  });
  const rows = await res.json();
  const { error } = await admin.from('events').upsert(rows);
  if (error) throw error;
  console.log(`events copied: ${rows.map((r) => r.name).join('; ')}`);
}
