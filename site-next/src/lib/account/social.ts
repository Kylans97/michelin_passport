// Following, friends and notifications, with the app's own calls
// (follow_repository.dart, friendship_repository.dart,
// member_avatar_repository.dart, notifications_repository.dart). Every
// friendship change goes through the same SECURITY DEFINER RPCs as the
// app, which hold the rules (blocking, discoverability, re-requests); the
// site never writes `friendships` except the owner-only delete the app
// also uses to cancel a request or end a friendship.
import { supabase } from './client';

// ── Following ────────────────────────────────────────────────────────────

export type FollowKind = 'restaurant' | 'hotel' | 'private_chef';
const FOLLOW_TABLE: Record<FollowKind, [string, string]> = {
  restaurant: ['follows_restaurants', 'restaurant_id'],
  hotel: ['follows_hotels', 'hotel_id'],
  private_chef: ['follows_private_chefs', 'private_chef_id'],
};

export async function isFollowing(userId: string, kind: FollowKind, id: string): Promise<boolean> {
  const [table, column] = FOLLOW_TABLE[kind];
  const { data, error } = await supabase().from(table).select('id').eq('user_id', userId).eq(column, id).limit(1);
  if (error) throw error;
  return (data ?? []).length > 0;
}

export async function follow(userId: string, kind: FollowKind, id: string): Promise<void> {
  const [table, column] = FOLLOW_TABLE[kind];
  const { error } = await supabase().from(table).insert({ user_id: userId, [column]: id });
  // 23505: already following, which is what was asked for.
  if (error && error.code !== '23505') throw error;
}

export async function unfollow(userId: string, kind: FollowKind, id: string): Promise<void> {
  const [table, column] = FOLLOW_TABLE[kind];
  const { error } = await supabase().from(table).delete().eq('user_id', userId).eq(column, id);
  if (error) throw error;
}

/** Everything the member follows, newest first, as kind and id. */
export async function loadFollowing(userId: string): Promise<{ kind: FollowKind; id: string }[]> {
  const db = supabase();
  const out: { kind: FollowKind; id: string; at: string }[] = [];
  for (const kind of Object.keys(FOLLOW_TABLE) as FollowKind[]) {
    const [table, column] = FOLLOW_TABLE[kind];
    const { data, error } = await db.from(table).select(`${column}, created_at`).eq('user_id', userId);
    if (error) throw error;
    for (const row of (data ?? []) as Record<string, string>[]) out.push({ kind, id: row[column], at: row.created_at });
  }
  return out.sort((a, b) => b.at.localeCompare(a.at));
}

// ── Members ──────────────────────────────────────────────────────────────

export type Relationship = 'accepted' | 'pending_sent' | 'pending_received' | 'declined' | 'none';

export interface Member {
  id: string;
  username: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  relationship?: Relationship;
  memberNumber?: number | null;
  /** The friendships row, where there is one: to accept, decline, cancel or unfriend. */
  friendshipId?: string;
}

export const memberName = (m: Pick<Member, 'displayName' | 'username'>) => m.displayName?.trim() || (m.username ? `@${m.username}` : 'Member');

const avatarCache = new Map<string, string | null>();

/** Signed photo URLs for the members the viewer may see, as
 *  MemberAvatarRepository.urlsFor: get_member_avatar_paths decides who,
 *  the profile-photos storage policy lets the viewer sign exactly those.
 *  Best effort: a member without one keeps their initials. */
export async function avatarUrls(ids: string[]): Promise<Map<string, string>> {
  const missing = [...new Set(ids)].filter((id) => !avatarCache.has(id));
  if (missing.length) {
    try {
      const { data } = await supabase().rpc('get_member_avatar_paths', { p_user_ids: missing });
      const paths = new Map(((data ?? []) as { user_id: string; avatar_path: string | null }[]).map((r) => [r.user_id, r.avatar_path]));
      await Promise.all(missing.map(async (id) => {
        const path = paths.get(id);
        if (!path) { avatarCache.set(id, null); return; }
        const { data: signed } = await supabase().storage.from('profile-photos').createSignedUrl(path, 3600);
        avatarCache.set(id, signed?.signedUrl ?? null);
      }));
    } catch {
      for (const id of missing) avatarCache.set(id, null);
    }
  }
  const out = new Map<string, string>();
  for (const id of ids) { const url = avatarCache.get(id); if (url) out.set(id, url); }
  return out;
}

async function withAvatars(members: Member[]): Promise<Member[]> {
  const urls = await avatarUrls(members.map((m) => m.id));
  return members.map((m) => ({ ...m, avatarUrl: urls.get(m.id) ?? null }));
}

async function rpcRows<T>(name: string, params?: Record<string, unknown>): Promise<T[]> {
  const { data, error } = await supabase().rpc(name, params);
  if (error) throw error;
  return (data ?? []) as T[];
}

export async function loadFriends(): Promise<Member[]> {
  const rows = await rpcRows<{ friendship_id: string; friend_id: string; username: string; display_name: string }>('get_friends');
  return withAvatars(rows.map((r) => ({ id: r.friend_id, username: r.username, displayName: r.display_name, avatarUrl: null, friendshipId: r.friendship_id, relationship: 'accepted' as const })));
}

export async function loadIncoming(): Promise<Member[]> {
  const rows = await rpcRows<{ friendship_id: string; requester_id: string; username: string; display_name: string }>('get_incoming_friend_requests');
  return withAvatars(rows.map((r) => ({ id: r.requester_id, username: r.username, displayName: r.display_name, avatarUrl: null, friendshipId: r.friendship_id, relationship: 'pending_received' as const })));
}

export async function loadOutgoing(): Promise<Member[]> {
  const rows = await rpcRows<{ friendship_id: string; addressee_id: string; username: string; display_name: string }>('get_outgoing_friend_requests');
  return withAvatars(rows.map((r) => ({ id: r.addressee_id, username: r.username, displayName: r.display_name, avatarUrl: null, friendshipId: r.friendship_id, relationship: 'pending_sent' as const })));
}

export async function loadBlocked(): Promise<Member[]> {
  const rows = await rpcRows<{ user_id: string; username: string; display_name: string }>('get_blocked_users');
  return rows.map((r) => ({ id: r.user_id, username: r.username, displayName: r.display_name, avatarUrl: null }));
}

/** At least two characters, as search_profiles' own floor. */
export async function searchMembers(query: string): Promise<Member[]> {
  if (query.trim().length < 2) return [];
  const rows = await rpcRows<{ id: string; username: string; display_name: string; relationship_status: Relationship }>('search_profiles', { query: query.trim() });
  return withAvatars(rows.map((r) => ({ id: r.id, username: r.username, displayName: r.display_name, avatarUrl: null, relationship: r.relationship_status ?? 'none' })));
}

export async function memberIdentity(userId: string): Promise<Member | null> {
  const rows = await rpcRows<{ id: string; username: string; display_name: string; relationship_status: Relationship; member_number: number | null }>('get_profile_identity', { target_user_id: userId });
  if (!rows[0]) return null;
  const [m] = await withAvatars([{ id: rows[0].id, username: rows[0].username, displayName: rows[0].display_name, avatarUrl: null, relationship: rows[0].relationship_status ?? 'none', memberNumber: rows[0].member_number }]);
  return m;
}

const call = async (name: string, params: Record<string, unknown>) => {
  const { error } = await supabase().rpc(name, params);
  if (error) throw error;
};
export const sendRequest = (targetUserId: string) => call('send_friend_request', { target_user_id: targetUserId });
export const acceptRequest = (friendshipId: string) => call('accept_friend_request', { friendship_id: friendshipId });
export const declineRequest = (friendshipId: string) => call('decline_friend_request', { friendship_id: friendshipId });
export const blockMember = (targetUserId: string) => call('block_user', { target_user_id: targetUserId });
export const unblockMember = (targetUserId: string) => call('unblock_user', { target_user_id: targetUserId });

/** Cancels a sent request or ends a friendship: the one direct write the
 *  app makes (friendships_delete allows only pending or accepted rows the
 *  member is part of, so a block can't be lifted this way). */
export async function removeFriendship(friendshipId: string): Promise<void> {
  const { error } = await supabase().from('friendships').delete().eq('id', friendshipId);
  if (error) throw error;
}

// ── Notifications ────────────────────────────────────────────────────────

export interface Notice {
  id: string;
  type: string;
  is_read: boolean;
  created_at: string;
  other_user_id: string | null;
  other_username: string | null;
  other_display_name: string | null;
  subject_id: string | null;
  friendship_status: string | null;
  listing_name: string | null;
  listing_city: string | null;
  invite_venue_name: string | null;
  invite_venue_city: string | null;
  invite_status: string | null;
  claim_venue_name: string | null;
  submission_venue_name: string | null;
  submission_venue_type: string | null;
  event_name: string | null;
  event_venue_name: string | null;
  trip_title: string | null;
  trip_member_status: string | null;
}

export const NOTICES_PER_PAGE = 50;

/** The newest notification functions this server has, as the app: _v5,
 *  else _v4, … each step down on "function not found" (PGRST202). */
async function withFallback<T>(names: string[], run: (name: string) => PromiseLike<{ data: T | null; error: { code?: string } | null }>): Promise<T> {
  for (const [i, name] of names.entries()) {
    const { data, error } = await run(name);
    if (!error) return data as T;
    if (error.code !== 'PGRST202' || i === names.length - 1) throw error;
  }
  throw new Error('unreachable');
}

export async function loadNotices(offset = 0): Promise<{ notices: Notice[]; hasMore: boolean }> {
  const rows = await withFallback<Notice[]>(
    ['get_notifications_v5', 'get_notifications_v4', 'get_notifications_v3', 'get_notifications_v2', 'get_notifications'],
    (name) => supabase().rpc(name).order('created_at', { ascending: false }).order('id', { ascending: false }).range(offset, offset + NOTICES_PER_PAGE - 1),
  );
  return { notices: rows ?? [], hasMore: (rows ?? []).length === NOTICES_PER_PAGE };
}

export const unreadCount = () => withFallback<number>(
  ['get_unread_notification_count_v5', 'get_unread_notification_count_v4', 'get_unread_notification_count_v3', 'get_unread_notification_count_v2', 'get_unread_notification_count'],
  (name) => supabase().rpc(name),
);

/** Only `is_read`, though RLS would let a member change more of their own row. */
export async function markRead(id?: string): Promise<void> {
  const q = supabase().from('notifications').update({ is_read: true });
  const { error } = await (id ? q.eq('id', id) : q.eq('is_read', false));
  if (error) throw error;
}

export interface PushPrefs { push_friend_requests: boolean; push_followed_venue_events: boolean }

/** The phone-push preferences; a member without a row has both on. */
export async function loadPushPrefs(userId: string): Promise<PushPrefs> {
  const { data, error } = await supabase().from('notification_preferences').select('push_friend_requests, push_followed_venue_events').eq('user_id', userId).maybeSingle();
  if (error) throw error;
  return (data as PushPrefs | null) ?? { push_friend_requests: true, push_followed_venue_events: true };
}

export async function savePushPrefs(userId: string, prefs: PushPrefs): Promise<void> {
  const { error } = await supabase().from('notification_preferences').upsert({ user_id: userId, ...prefs, updated_at: new Date().toISOString() });
  if (error) throw error;
}
