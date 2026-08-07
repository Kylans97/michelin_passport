/// Result of saving a visit or stay from its "Add" sheet. The visit/stay
/// row itself is never rolled back for a photo failure (see
/// AddVisitSheet/AddStaySheet's _save()) — [savedWithPhotoErrors] means the
/// record saved but one or more staged photos failed to upload, so the
/// caller can tell the user clearly rather than pretending everything
/// succeeded.
enum SaveOutcome { saved, savedWithPhotoErrors }
