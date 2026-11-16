// One visit or stay with its wines and photos, read-only, with the app's
// own reads (visited_repository.dart, visit_wine_repository.dart,
// photo_repository.dart). Photos live in the private visit-photos bucket
// and are shown through signed URLs that expire after an hour, as in the
// app; the originals are already capped at 1600 px on upload.
import { supabase } from './client';

const VISIT_COLUMNS =
  'id, entity_type, entity_id, visited_on, rating, food_rating, service_rating, wine_rating, atmosphere_rating, '
  + 'value_rating, room_rating, experience_rating, menu_type, notes, price_paid, currency, keys_at_visit, stars_at_visit, visibility';

export interface VisitDetail {
  id: string;
  entity_type: 'restaurant' | 'hotel';
  entity_id: string;
  visited_on: string;
  rating: number | null;
  food_rating: number | null;
  service_rating: number | null;
  wine_rating: number | null;
  atmosphere_rating: number | null;
  value_rating: number | null;
  room_rating: number | null;
  experience_rating: number | null;
  menu_type: string | null;
  notes: string | null;
  price_paid: number | null;
  currency: string | null;
  keys_at_visit: number | null;
  stars_at_visit: number | null;
  visibility: 'private' | 'friends';
  wines: { producer: string | null; wine_name: string | null; vintage: number | null; non_vintage: boolean; bottle_size: string | null }[];
  photos: { url: string; caption: string | null }[];
}

export async function loadVisit(userId: string, visitId: string): Promise<VisitDetail | null> {
  if (!/^[0-9a-f-]{36}$/i.test(visitId)) return null;
  const db = supabase();
  // The member's own visit only: a friend's shared visit is readable
  // under RLS too, but this page is the member's own Passport.
  const { data: visit, error } = await db.from('visits').select(VISIT_COLUMNS).eq('id', visitId).eq('user_id', userId).maybeSingle();
  if (error) throw error;
  if (!visit) return null;
  const [wines, photos] = await Promise.all([
    db.from('visit_wines').select('producer, wine_name, vintage, non_vintage, bottle_size').eq('visit_id', visitId).order('created_at'),
    db.from('photos').select('storage_path, caption, taken_at').eq('visit_id', visitId).order('taken_at', { ascending: false }),
  ]);
  if (wines.error) throw wines.error;
  if (photos.error) throw photos.error;
  const paths = (photos.data ?? []).map((p) => p.storage_path as string);
  const signed = paths.length ? await db.storage.from('visit-photos').createSignedUrls(paths, 3600) : { data: [], error: null };
  if (signed.error) throw signed.error;
  const urlByPath = new Map((signed.data ?? []).filter((s) => s.signedUrl).map((s) => [s.path, s.signedUrl]));
  return {
    ...(visit as unknown as Omit<VisitDetail, 'wines' | 'photos'>),
    wines: (wines.data ?? []) as VisitDetail['wines'],
    photos: (photos.data ?? [])
      .filter((p) => urlByPath.has(p.storage_path as string))
      .map((p) => ({ url: urlByPath.get(p.storage_path as string)!, caption: p.caption as string | null })),
  };
}
