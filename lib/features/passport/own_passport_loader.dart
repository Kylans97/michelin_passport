import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/country_lookup.dart';
import '../../data/repositories/event_confirmed_attendance_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/visited_repository.dart';
import '../../models/venue_entry.dart';
import 'passport_booklet_data.dart';

/// Everything the CURRENT user's own booklet renders, loaded in one pass.
/// Shared by [PassportCollectionBody] (the Passport tab) and the stamp
/// ceremony (stamp_ceremony.dart), so the ceremony shows exactly the
/// booklet the member would see on their Passport tab — same volumes,
/// same holder identity, same stamp placement — rather than a second,
/// separately-assembled copy that could drift from it.
class OwnPassport {
  final List<PassportVolume> volumes;

  // The raw, un-capped loads [volumes] is built from — PassportAllVisitsScreen
  // shows the WHOLE history, not just buildPassportVolumes' 5-year window.
  final List<VenueEntry> entries;
  final List<EventAttendanceEntry> eventEntries;

  final String holderName;
  final String? avatarUrl;

  // Null only for the handful of pre-existing test accounts
  // 20260925120000_add_profiles_member_number.sql deliberately left
  // unnumbered — never expected for a real member.
  final int? memberNumber;
  final Map<String, String> countryNameByCode;

  const OwnPassport({
    required this.volumes,
    required this.entries,
    required this.eventEntries,
    required this.holderName,
    required this.avatarUrl,
    required this.memberNumber,
    required this.countryNameByCode,
  });
}

/// Loads the signed-in member's own [OwnPassport]. Throws only when the
/// visits/stays load itself fails — events, profile and country names
/// each fall back quietly, exactly as PassportCollectionBody always did.
Future<OwnPassport> loadOwnPassport(SupabaseClient client) async {
  final uid = client.auth.currentUser?.id ?? '';
  final entries = await VisitedRepository(client).loadPassportVenues(uid);

  var eventEntries = <EventAttendanceEntry>[];
  try {
    eventEntries = await EventConfirmedAttendanceRepository(
      client,
    ).loadPassportEventAttendance(uid);
  } catch (_) {
    // Never fails the rest of Passport — same precedent as before.
  }

  var name = 'Member';
  String? avatarUrl;
  int? memberNumber;
  try {
    final profileRepo = ProfileRepository(client);
    // `visited` only feeds UserProfile's own current-award stats, which
    // the booklet never reads (it computes ENTRIES/COUNTRIES/STARS itself
    // from stars-at-visit, not current award) — so an empty list here
    // avoids a second restaurant load for fields that would go unused.
    final profile = await profileRepo.getProfile(
      userId: uid,
      visited: const [],
    );
    name = profile.name;
    avatarUrl = await profileRepo.resolveAvatarUrl(profile.avatarPath);
    memberNumber = profile.memberNumber;
  } catch (_) {
    // Cover/data page still render with the 'Member' + initials fallback
    // — a profile-load failure never blocks Passport itself.
  }

  var countryNameByCode = <String, String>{};
  try {
    final countries = await getAllCountries(client);
    countryNameByCode = {for (final c in countries) c.code: c.name};
  } catch (_) {
    // Never fails the rest of Passport — stamp semantics labels fall back
    // to the bare country code (see stampSemanticLabel).
  }

  return OwnPassport(
    volumes: buildPassportVolumes(entries: entries, eventEntries: eventEntries),
    entries: entries,
    eventEntries: eventEntries,
    holderName: name,
    avatarUrl: avatarUrl,
    memberNumber: memberNumber,
    countryNameByCode: countryNameByCode,
  );
}
