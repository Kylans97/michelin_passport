import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/supabase/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

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
