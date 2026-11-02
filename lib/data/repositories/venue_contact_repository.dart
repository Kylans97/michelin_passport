import 'package:supabase_flutter/supabase_flutter.dart';

/// A venue's website and phone number as its page shows them.
class VenueContact {
  final String? website;
  final String? phone;

  const VenueContact({this.website, this.phone});
}

/// Why [website] can't be saved, or null when it can — the same rule
/// set_venue_contact applies (20261101190000), checked first so the
/// screen can say so before anything is sent. Empty is fine: it clears.
String? venueWebsiteProblem(String website) {
  final value = website.trim();
  if (value.isEmpty) return null;
  final ok =
      value.length <= 500 &&
      RegExp(
        r'^https?://[^\s/?#]+\.[^\s/?#]{2,}([/?#]\S*)?$',
        caseSensitive: false,
      ).hasMatch(value);
  return ok ? null : 'Enter the full address, like https://www.yourvenue.com';
}

/// Why [phone] can't be saved, or null when it can. Empty is fine.
String? venuePhoneProblem(String phone) {
  final value = phone.trim();
  if (value.isEmpty) return null;
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '').length;
  final ok =
      value.length <= 30 &&
      RegExp(r'^\+?[0-9 ()./-]+$').hasMatch(value) &&
      digits >= 6;
  return ok
      ? null
      : 'Use digits, spaces and + ( ) . / - only, like +31 20 123 4567';
}

/// A venue's own website and phone number (restaurants and hotels; a
/// private chef has a website only). The manager changes them through
/// set_venue_contact, live at once with no review; each change puts an
/// item in the admin review queue to glance at (decided 2026-11-02).
class VenueContactRepository {
  VenueContactRepository(this._client);

  final SupabaseClient _client;

  Future<VenueContact> load({
    required String venueType,
    required String venueId,
  }) async {
    final (view, columns) = switch (venueType) {
      'restaurant' => ('restaurants_full', 'website_url, phone'),
      'hotel' => ('hotels_full', 'website_url, phone'),
      _ => ('private_chefs_full', 'website_url'),
    };
    final row = await _client
        .from(view)
        .select(columns)
        .eq('id', venueId)
        .maybeSingle();
    return VenueContact(
      website: row?['website_url'] as String?,
      phone: row?['phone'] as String?,
    );
  }

  /// Sets both; a blank value clears it.
  Future<void> save({
    required String venueType,
    required String venueId,
    required String website,
    required String phone,
  }) => _client.rpc(
    'set_venue_contact',
    params: {
      'p_venue_type': venueType,
      'p_venue_id': venueId,
      'p_website': website.trim(),
      'p_phone': venueType == 'private_chef' ? null : phone.trim(),
    },
  );
}
