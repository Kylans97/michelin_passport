// Gives the first LOCAL test member from local-sign-in-test.mjs a Passport
// to look at: restaurant visits, a hotel stay, a confirmed event (copy the
// event first with local-sign-in-test.mjs), wines and one photo.
//
//   LOCAL_SUPABASE_URL=… LOCAL_SERVICE_ROLE_KEY=… \
//   node scripts/local-passport-test.mjs <photo file> <past event id>
//
// Venue ids are production's (wishlist and visits hold ids only, no foreign
// key), so the site built from production names them. Refuses any URL that
// isn't on this machine; running it twice adds nothing twice.
import { readFileSync } from 'node:fs';
import { createClient } from '@supabase/supabase-js';

const url = process.env.LOCAL_SUPABASE_URL;
const serviceKey = process.env.LOCAL_SERVICE_ROLE_KEY;
if (!url || !serviceKey) throw new Error('Set LOCAL_SUPABASE_URL and LOCAL_SERVICE_ROLE_KEY.');
if (!['127.0.0.1', 'localhost', '[::1]'].includes(new URL(url).hostname)) throw new Error(`Not a local stack: ${url}`);
const [photoFile, eventId] = process.argv.slice(2);

const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
const { data: list } = await admin.auth.admin.listUsers();
const user = list.users.find((u) => u.email === 'web-signin@mantelier.test');
if (!user) throw new Error('Run local-sign-in-test.mjs first.');

const { count } = await admin.from('visits').select('id', { count: 'exact', head: true }).eq('user_id', user.id);
if (count) {
  console.log(`already seeded (${count} visits)`);
  process.exit(0);
}

const visits = [
  // Waterside Inn, Bray: twice, so it has two stamps.
  { entity_type: 'restaurant', entity_id: 'e61b3946-74e8-43e8-b2db-06f4575b3026', visited_on: '2024-06-12', stars_at_visit: 3 },
  { entity_type: 'restaurant', entity_id: 'bbfdcaac-44c5-46fe-8fb9-d89719d5fb43', visited_on: '2025-09-20', stars_at_visit: 2,
    food_rating: 9, service_rating: 8, wine_rating: 9, atmosphere_rating: 8, value_rating: 7, menu_type: 'tasting_menu',
    notes: 'The langoustine course with the brown butter. Sat at the counter.', price_paid: 495, currency: 'DKK', visibility: 'friends' },
  { entity_type: 'restaurant', entity_id: '5ee427db-501e-4066-8ccf-1d260b7a8a86', visited_on: '2026-03-02', stars_at_visit: 2 },
  { entity_type: 'hotel', entity_id: 'c6071336-fbd6-4e3f-aca1-fcb8e5cba02c', visited_on: '2026-07-14', keys_at_visit: 3,
    room_rating: 9, service_rating: 9, experience_rating: 10, notes: 'Sea-view room, breakfast on the terrace.' },
];
const second = { ...visits[0], visited_on: '2025-12-18' };

const { data: rows, error } = await admin
  .from('visits')
  .insert([...visits, second].map((v) => ({ user_id: user.id, visibility: 'private', ...v })))
  .select('id, entity_type, entity_id, visited_on');
if (error) throw error;
console.log(`visits: ${rows.length}`);

const koan = rows.find((r) => r.entity_id === 'bbfdcaac-44c5-46fe-8fb9-d89719d5fb43');
const { error: wineError } = await admin.from('visit_wines').insert([
  { visit_id: koan.id, user_id: user.id, producer: 'Domaine Ramonet', wine_name: 'Chassagne-Montrachet', vintage: 2019, non_vintage: false },
  { visit_id: koan.id, user_id: user.id, producer: 'Krug', wine_name: 'Grande Cuvée', non_vintage: true },
]);
if (wineError) throw wineError;

if (photoFile) {
  const path = `${user.id}/${koan.id}/local-test.webp`;
  const { error: upError } = await admin.storage.from('visit-photos').upload(path, readFileSync(photoFile), { contentType: 'image/webp', upsert: true });
  if (upError) throw upError;
  const { error: photoError } = await admin.from('photos').insert({
    user_id: user.id, visit_id: koan.id, entity_type: 'restaurant', entity_id: koan.entity_id, storage_path: path, is_public: false,
  });
  if (photoError) throw photoError;
  console.log('photo: 1');
}

if (eventId) {
  const { error: attendError } = await admin.from('event_confirmed_attendance').insert({ user_id: user.id, event_id: eventId, source: 'manual' });
  if (attendError) throw attendError;
  console.log('confirmed attendance: 1');
}

