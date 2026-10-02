import '../../models/published_venue_photo.dart';
import '../../models/venue_photo_submission_status.dart';

/// One photo in a merged preview order — just enough identity for every
/// caller of [mergePreviewPhotoOrder]: all three (Restaurant/Hotel/
/// PrivateChefDetailScreen) now need [id], not only [imageUrl] —
/// VenueDetailHero's and PrivateChefHero's own report-photo actions both
/// read `photos[i].id`. An untouched published entry keeps its own
/// published-table id; a swapped-in or appended pending entry uses its
/// submission's own id — never a fabricated one. Neither is "the id it
/// will actually have once approved" (Postgres generates a fresh one at
/// insert time, unknowable in advance) — that's fine here, since the one
/// action that would care (reporting a photo) is always inert in preview
/// mode.
class MergedPreviewPhoto {
  final String id;
  final String imageUrl;

  const MergedPreviewPhoto({required this.id, required this.imageUrl});
}

/// Merges a venue's currently-published photos with the signed-in
/// manager's own pending submissions into the order the venue WILL have
/// once everything pending today is approved — for the owner preview
/// only. Never written back anywhere.
///
/// THIS IS THE SAME ORDERING RULE `approve_venue_photo` APPLIES AT
/// APPROVAL TIME (supabase/migrations/20261005120000_add_venue_approval_
/// rpcs.sql), reimplemented here in Dart because one runs in Postgres at
/// the moment of approval and the other has to run here, before approval,
/// with no shared code path possible between the two. THE TWO MUST BE
/// KEPT IN SYNC BY HAND: a change to either's ordering logic requires the
/// identical change in the other. If they diverge, this preview goes back
/// to lying about the venue's future photo order, and nothing will
/// announce it — there is no test or check that can catch drift between
/// a SQL function and this file automatically.
///
/// The rule, mirrored exactly from `approve_venue_photo`:
/// - a pending submission whose `replacesPhotoId` names a currently
///   published photo takes that photo's exact position — a swap, not a
///   demotion to last — and the replaced photo drops out of the result;
/// - a submission with no `replacesPhotoId` is appended after the
///   current maximum `display_order`, matching `approve_venue_photo`'s
///   own `coalesce(max(display_order) + 1, 0)` exactly: gaps left by an
///   earlier deletion are never filled, never renumbered.
///
/// Pending submissions are processed oldest-submitted-first, matching the
/// order they would actually be reviewed and approved in. Only `pending`
/// submissions are included — `rejected` ones represent something that
/// will not happen and have no place in a future-state preview (`status
/// == approved` never appears here at all: an approved submission is
/// already in [published] instead, per `loadMyOpenSubmissions`'s own
/// scope). A submission with no resolved signed URL (a failed
/// [VenuePhotoSubmissionRepository.resolveDisplayUrls] lookup) is skipped
/// rather than shown broken.
///
/// Known, deliberately unhandled edge case, same spirit as
/// `approve_venue_photo`'s own header comments about what it doesn't
/// solve: two still-pending submissions naming the same `replacesPhotoId`
/// is possible today (nothing prevents submitting two candidate
/// replacements for one slot before either is reviewed). In reality the
/// second one to actually be approved would fail loudly (`replaces_photo_id
/// % does not belong to venue %`, since the first approval already
/// deleted the row it names). This merge can't simulate that failure — a
/// preview isn't a validator — so the later-submitted one simply wins the
/// slot here.
List<MergedPreviewPhoto> mergePreviewPhotoOrder({
  required List<PublishedVenuePhoto> published,
  required List<VenuePhotoSubmissionSummary> pendingSubmissions,
  required Map<String, String> pendingSignedUrls,
}) {
  final result = [
    for (final photo in published)
      MergedPreviewPhoto(id: photo.id, imageUrl: photo.imageUrl),
  ];
  final indexByPublishedId = {
    for (var i = 0; i < published.length; i++) published[i].id: i,
  };

  final pendingOnly =
      pendingSubmissions
          .where((s) => s.status == VenuePhotoSubmissionStatus.pending)
          .toList()
        ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));

  for (final submission in pendingOnly) {
    final signedUrl = pendingSignedUrls[submission.storagePath];
    if (signedUrl == null) continue;

    final entry = MergedPreviewPhoto(id: submission.id, imageUrl: signedUrl);
    final replacesIndex = submission.replacesPhotoId == null
        ? null
        : indexByPublishedId[submission.replacesPhotoId];
    if (replacesIndex != null) {
      result[replacesIndex] = entry;
    } else {
      result.add(entry);
    }
  }

  return result;
}
