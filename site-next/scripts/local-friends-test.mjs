// Gives the first LOCAL test member (local-sign-in-test.mjs) some company:
// a friend who shares a visit, a Going event and a wishlist; a member whose
// friend request is waiting; one to find in search; and a followed
// restaurant. Friend requests go through the app's own RPCs, signed in as
// each test member, so the notifications are the real ones.
//
//   LOCAL_SUPABASE_URL=… LOCAL_SERVICE_ROLE_KEY=… LOCAL_ANON_KEY=… \
//   node scripts/local-friends-test.mjs <upcoming event id>
//
// Refuses any URL that isn't on this machine; running it twice adds nothing twice.
import { createClient } from '@supabase/supabase-js';
import { SUPABASE_ANON_KEY as PROD_ANON_KEY, SUPABASE_URL as PROD_URL } from '../src/lib/supabase.ts';

const url = process.env.LOCAL_SUPABASE_URL;
const serviceKey = process.env.LOCAL_SERVICE_ROLE_KEY;
const anonKey = process.env.LOCAL_ANON_KEY;
if (!url || !serviceKey || !anonKey) throw new Error('Set LOCAL_SUPABASE_URL, LOCAL_SERVICE_ROLE_KEY and LOCAL_ANON_KEY.');
if (!['127.0.0.1', 'localhost', '[::1]'].includes(new URL(url).hostname)) throw new Error(`Not a local stack: ${url}`);
const [eventId] = process.argv.slice(2);

const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
const PASSWORD = 'local-test-only-3';
const PEOPLE = [
  { email: 'anna@mantelier.test', display_name: 'Anna Visser', username: 'anna_visser' },
  { email: 'bas@mantelier.test', display_name: 'Bas de Wit', username: 'bas_dewit' },
  { email: 'chris@mantelier.test', display_name: 'Chris Lambert', username: 'chris_lambert' },
];

async function memberId(email, meta) {
  const { data: list } = await admin.auth.admin.listUsers();
  const found = list.users.find((u) => u.email === email);
  if (found) return found.id;
  const { data, error } = await admin.auth.admin.createUser({ email, password: PASSWORD, email_confirm: true, user_metadata: meta });
  if (error) throw error;
  return data.user.id;
}
async function as(email, password = PASSWORD) {
  const c = createClient(url, anonKey, { auth: { persistSession: false } });
  const { error } = await c.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return c;
}
const ok = ({ error }) => { if (error && error.code !== '23505' && !/already/i.test(error.message)) throw error; };

const me = await memberId('web-signin@mantelier.test');
const [anna, bas] = await Promise.all(PEOPLE.slice(0, 2).map((p) => memberId(p.email, p)));
await memberId(PEOPLE[2].email, PEOPLE[2]);
await admin.from('profiles').update({ is_discoverable: true }).in('username', PEOPLE.map((p) => p.username));

// Anna and the test member are friends: Anna asks, the member accepts.
const annaClient = await as('anna@mantelier.test');
const meClient = await as('web-signin@mantelier.test', 'local-test-only-1');
ok(await annaClient.rpc('send_friend_request', { target_user_id: me }));
const { data: incoming } = await meClient.rpc('get_incoming_friend_requests');
const fromAnna = (incoming ?? []).find((r) => r.requester_id === anna);
if (fromAnna) ok(await meClient.rpc('accept_friend_request', { friendship_id: fromAnna.friendship_id }));

// Bas's request waits.
ok(await (await as('bas@mantelier.test')).rpc('send_friend_request', { target_user_id: me }));

// What Anna shares: a visit for friends, Going, a wishlist.
const { count } = await admin.from('visits').select('id', { count: 'exact', head: true }).eq('user_id', anna);
if (!count) {
  ok(await annaClient.from('visits').insert({ user_id: anna, entity_type: 'restaurant', entity_id: 'bbfdcaac-44c5-46fe-8fb9-d89719d5fb43', visited_on: '2026-05-04', stars_at_visit: 2, food_rating: 9, service_rating: 9, visibility: 'friends' }));
  ok(await annaClient.from('visits').insert({ user_id: anna, entity_type: 'restaurant', entity_id: 'e61b3946-74e8-43e8-b2db-06f4575b3026', visited_on: '2026-02-11', stars_at_visit: 3, visibility: 'private' }));
}
if (eventId) ok(await annaClient.from('event_attendance').insert({ user_id: anna, event_id: eventId, status: 'going', visibility: 'friends' }));
ok(await annaClient.from('wishlist').insert({ user_id: anna, entity_type: 'restaurant', entity_id: '5ee427db-501e-4066-8ccf-1d260b7a8a86' }));

// The test member follows Koan. follows_restaurants, unlike visits and
// wishlist, has a foreign key, so Koan and its city are copied into the
// local catalogue first, from production's public read.
const KOAN = 'bbfdcaac-44c5-46fe-8fb9-d89719d5fb43';
const prod = (path) => fetch(`${PROD_URL}/rest/v1/${path}`, { headers: { apikey: PROD_ANON_KEY } }).then((r) => r.json());
const [koan] = await prod(`restaurants?id=eq.${KOAN}&select=*`);
const [city] = await prod(`cities?id=eq.${koan.city_id}&select=*`);
ok(await admin.from('cities').upsert(city));
ok(await admin.from('restaurants').upsert({ ...koan, cuisine_id: null, missing_listing_report_id: null }));
ok(await meClient.from('follows_restaurants').insert({ user_id: me, restaurant_id: KOAN }));
console.log('friends seeded');
