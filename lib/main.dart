import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'app.dart';
import 'core/supabase/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  // Loads the bundled IANA database once at startup — every Event-local
  // time conversion (lib/core/utils/event_time.dart) depends on this
  // having already run. Deliberately the "_all" variant, not the default
  // (non-"_all"/"_10y") one: verified empirically (not assumed) that the
  // default variant excludes "Europe/Amsterdam" — it's a backward-
  // compatibility LINK in IANA's own tzdata (aliased to Europe/Brussels,
  // identical civil time rules since WWII), which the default variant's
  // "no deprecated/historical zones" trim drops. That's exactly the zone
  // every one of this app's real events currently needs — the default
  // variant would have silently rendered every event in UTC instead of
  // Amsterdam time, with no error, since eventLocalDateTime's fallback
  // exists precisely to swallow an unrecognized identifier rather than
  // crash. The extra ~80kb of the "_all" variant is a trivial cost next
  // to that failure mode. This is the synchronous, non-web initializer
  // (`initializeTimeZones()`) — Flutter Web is not a build target today
  // (see EVENTS_V2_ARCHITECTURE.md §28's web-readiness note); a future
  // web build would swap this one call for `package:timezone/browser.dart`'s
  // async equivalent (pointed at the "_all" .tzf asset), with zero change
  // to any conversion/formatting logic elsewhere in the app.
  tz_data.initializeTimeZones();

  // Initialise the Supabase client once at app startup.
  // The singleton is then accessible anywhere via Supabase.instance.client.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // publishableKey is the new name for the anon/public key in supabase_flutter 2.x
    // ignore: deprecated_member_use
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const TablePassportApp());
}
