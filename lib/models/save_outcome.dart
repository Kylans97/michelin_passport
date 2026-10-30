import 'visit.dart';

/// Result of saving a visit or stay from its "Add" sheet. The visit/stay
/// row itself is never rolled back for a photo failure (see
/// AddVisitSheet/AddStaySheet's _save()) — [savedWithPhotoErrors] means the
/// record saved but one or more staged photos failed to upload, so the
/// caller can tell the user clearly rather than pretending everything
/// succeeded.
enum SaveOutcome { saved, savedWithPhotoErrors }

/// What an "Add" sheet returns once its visit/stay row is saved: the row
/// itself (which is what earns the Passport stamp — see
/// `celebrateNewStamp`) and how its photos fared.
class SavedVisit {
  final Visit visit;
  final SaveOutcome outcome;
  const SavedVisit(this.visit, this.outcome);
}
