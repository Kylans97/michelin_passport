import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/vineyard_repository.dart';
import '../../models/vineyard.dart';
import '../../models/vineyard_visit.dart';
import '../passport/stamp_ceremony.dart';
import 'widgets/log_estate_visit_sheet.dart';

/// Asks for the visit, saves it, and presses the estate's stamp — the one
/// way into an estate visit, from the estate's page and from the Passport's
/// "Where did you go?". Returns the saved visit, or null when the member
/// dismissed the sheet or the save failed (a snackbar says which).
Future<VineyardVisit?> logEstateVisit(
  BuildContext context, {
  required Vineyard vineyard,
}) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  final messenger = ScaffoldMessenger.of(context);
  if (uid == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Sign in to add it to your Passport.')),
    );
    return null;
  }
  final input = await showLogEstateVisitSheet(context, vineyard: vineyard);
  if (input == null || !context.mounted) return null;
  final VineyardVisit saved;
  try {
    saved = await VineyardRepository(client).logVisit(
      userId: uid,
      vineyardId: vineyard.id,
      visitedOn: input.visitedOn,
      activities: input.activities,
      comment: input.comment,
      friendsVisible: input.friendsVisible,
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not save. Please try again.')),
    );
    return null;
  }
  if (!context.mounted) return saved;
  HapticFeedback.mediumImpact();
  await celebrateNewStamp(context, EarnedStamp.estateVisit(saved));
  return saved;
}
