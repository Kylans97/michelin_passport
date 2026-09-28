import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import 'venue_gallery_picker_screen.dart';

/// A locally picked venue photo, not yet validated or uploaded. Holds
/// only bytes — no XFile — since nothing downstream ever reads a file
/// path (validateVenuePhoto/VenuePhotoSubmissionRepository.submit both
/// take raw bytes), and `photo_manager`'s asset reads hand back bytes
/// directly with no path of their own to carry.
class StagedVenuePhoto {
  final Uint8List bytes;
  const StagedVenuePhoto({required this.bytes});
}

/// A single download's outcome — [cancelled] is tracked separately from a
/// plain null [bytes], so [pickVenuePhotos] can tell "the manager tapped
/// Cancel, stop asking for more" (stop the whole batch, keep what's
/// already downloaded) apart from "this one asset's download genuinely
/// failed" (skip it, keep going — matches the "one failure must not take
/// the good ones down with it" rule this feature applies at every other
/// stage: validation, upload, and now this one too).
typedef _DownloadOutcome = ({Uint8List? bytes, bool cancelled});

/// Opens a photo-library picker for up to [maxSelectable] images and
/// returns the TRUE original bytes of whichever ones were both selected
/// AND successfully downloaded — never a downscaled proxy. The returned
/// list's length is NOT guaranteed to equal [maxSelectable] or even the
/// number the manager tapped: fewer were picked (normal), a download
/// failed (skipped, the rest continue), or the manager cancelled
/// mid-batch (stops asking for more, keeps what already downloaded) all
/// produce a shorter list — callers must not assume otherwise.
///
/// Replaces an earlier `image_picker`-based implementation. That
/// package's iOS picker (`PHPickerViewController`, used on iOS 14+) has
/// `preferredAssetRepresentationMode` hardcoded to `.current` in its own
/// native code (`FLTImagePickerPlugin.m`) — unconditionally, independent
/// of `requestFullMetadata` or any other Dart-level option this app could
/// pass. `.current` means "hand back whatever representation is already
/// cached locally, never transcode or fetch" — which, when iCloud Photos'
/// "Optimize iPhone Storage" is on (the default), silently returns a
/// reduced local proxy instead of the original. Confirmed on a real
/// device: a 3024x4032 iPhone photo came back as an 1152x2048 proxy,
/// 48px under `minVenuePhotoShortSidePx` (1200) on its short side — the
/// real source of the "too small" rejections this replaces. There is no
/// Dart-level way to change that mode through `image_picker`.
///
/// `photo_manager` has no picker UI or multi-select/limit concept of its
/// own at all (unlike `image_picker.pickMultiImage(limit:)`) — it's a
/// pure PhotoKit/MediaStore data-access layer. [VenueGalleryPickerScreen]
/// is this app's own grid + selection state; [maxSelectable] is enforced
/// there exactly (every tap is ours to allow or ignore), and re-clamped
/// defensively here anyway, matching `pickStagedPhotos`/
/// `clampToRemainingCapacity`'s own established "never trust a single
/// enforcement point" pattern. `AssetEntity.getOriginBytes()` explicitly
/// requests the ORIGIN representation, downloading it from iCloud when
/// the local copy is only a proxy — with a [PMProgressHandler] this file
/// surfaces as a visible, cancellable, batch-aware progress dialog
/// ("Downloading photo 2 of 3…"), never a silent/frozen wait
/// (`_OriginalPhotoDownloadDialog` below).
///
/// Trade-off, surfaced rather than hidden: `PHPickerViewController` needs
/// NO photo-library permission at all (Apple's picker-owns-the-selection
/// privacy model) — `photo_manager` reads the library directly and DOES
/// require it (`NSPhotoLibraryUsageDescription` on iOS,
/// `READ_MEDIA_IMAGES` on Android 13+), so a manager now sees a real,
/// one-time permission prompt the first time they add a venue photo.
/// There is no way to force the true original through Apple's
/// privacy-preserving picker without this — the permission and the fix
/// are the same trade-off, not two separate costs.
Future<List<StagedVenuePhoto>> pickVenuePhotos(
  BuildContext context, {
  required int maxSelectable,
}) async {
  final permission = await PhotoManager.requestPermissionExtend(
    requestOption: const PermissionRequestOption(
      androidPermission: AndroidPermission(type: RequestType.image, mediaLocation: false),
    ),
  );
  if (!permission.hasAccess) {
    if (!context.mounted) return [];
    await _showPermissionDeniedDialog(context);
    return [];
  }

  if (!context.mounted) return [];
  final picked = await Navigator.of(context).push<List<AssetEntity>>(
    MaterialPageRoute(builder: (_) => VenueGalleryPickerScreen(maxSelectable: maxSelectable)),
  );
  if (picked == null || picked.isEmpty) return []; // cancelled

  // Defensive clamp — see this function's own doc comment. The gallery
  // screen's own selection state already enforces maxSelectable exactly,
  // so this only ever bites if that enforcement has a bug.
  final accepted = picked.length > maxSelectable ? picked.sublist(0, maxSelectable) : picked;

  final staged = <StagedVenuePhoto>[];
  for (var i = 0; i < accepted.length; i++) {
    if (!context.mounted) break;
    final outcome = await _loadOriginalBytes(
      context,
      accepted[i],
      batchPosition: accepted.length > 1 ? (index: i + 1, total: accepted.length) : null,
    );
    if (outcome.bytes != null) staged.add(StagedVenuePhoto(bytes: outcome.bytes!));
    if (outcome.cancelled) break; // stop asking for more; keep what's already downloaded
  }
  return staged;
}

/// Fetches one asset's true original bytes, showing a progress dialog
/// whenever that requires an iCloud download (iOS/macOS only —
/// `PMProgressHandler` asserts on other platforms, and Android assets are
/// always already local per `AssetEntity.isLocallyAvailable`'s own docs,
/// so there's nothing to show progress for there). [batchPosition], when
/// picking more than one photo, names this photo's place in the batch
/// ("Downloading photo 2 of 3…") so a slow multi-photo fetch never reads
/// as stuck on a single, unexplained bar.
Future<_DownloadOutcome> _loadOriginalBytes(
  BuildContext context,
  AssetEntity asset, {
  ({int index, int total})? batchPosition,
}) async {
  if (!Platform.isIOS && !Platform.isMacOS) {
    return (bytes: await asset.getOriginBytes(), cancelled: false);
  }
  final progressHandler = PMProgressHandler();
  final cancelToken = PMCancelToken(debugLabel: 'venue-photo-original-fetch');
  final result = await showDialog<_DownloadOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OriginalPhotoDownloadDialog(
      bytesFuture: asset.getOriginBytes(progressHandler: progressHandler, cancelToken: cancelToken),
      progressStream: progressHandler.stream,
      cancelToken: cancelToken,
      batchPosition: batchPosition,
    ),
  );
  return result ?? (bytes: null, cancelled: false);
}

Future<void> _showPermissionDeniedDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        'Photo access needed',
        style: CsTypography.placeTitle.copyWith(color: AppColors.forestGreen, fontSize: 18),
      ),
      content: Text(
        'To add a photo, allow Mantelier to access your photo library in Settings.',
        style: CsTypography.body.copyWith(color: AppColors.forestGreen),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            PhotoManager.openSetting();
          },
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );
}

/// Visible, cancellable progress while the true original downloads from
/// iCloud — pops itself with the resulting outcome once [bytesFuture]
/// resolves. A locally-available asset resolves near-instantly with no
/// progress events at all; the indeterminate bar (`value: null` until the
/// first event) still shows something is happening rather than a frozen
/// screen either way.
class _OriginalPhotoDownloadDialog extends StatefulWidget {
  final Future<Uint8List?> bytesFuture;
  final Stream<PMProgressState> progressStream;
  final PMCancelToken cancelToken;
  final ({int index, int total})? batchPosition;

  const _OriginalPhotoDownloadDialog({
    required this.bytesFuture,
    required this.progressStream,
    required this.cancelToken,
    this.batchPosition,
  });

  @override
  State<_OriginalPhotoDownloadDialog> createState() => _OriginalPhotoDownloadDialogState();
}

class _OriginalPhotoDownloadDialogState extends State<_OriginalPhotoDownloadDialog> {
  double? _progress;
  bool _cancelled = false;
  StreamSubscription<PMProgressState>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.progressStream.listen((state) {
      if (!mounted) return;
      setState(() => _progress = state.progress);
    });
    widget.bytesFuture.then((bytes) {
      if (!mounted || _cancelled) return;
      Navigator.of(context).pop((bytes: bytes, cancelled: false));
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _cancel() {
    _cancelled = true;
    widget.cancelToken.cancelRequest();
    Navigator.of(context).pop((bytes: null, cancelled: true));
  }

  @override
  Widget build(BuildContext context) {
    final percent = _progress == null ? null : (_progress! * 100).round();
    final position = widget.batchPosition;
    final title = position == null
        ? 'Downloading full-resolution photo…'
        : 'Downloading photo ${position.index} of ${position.total}…';
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: CsTypography.body.copyWith(color: AppColors.forestGreen, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: CsSpacing.sm),
            LinearProgressIndicator(value: _progress, color: AppColors.forestGreen),
            const SizedBox(height: CsSpacing.xs),
            Text(
              percent == null ? 'Starting…' : '$percent%',
              style: CsTypography.metadata.copyWith(color: AppColors.taupe),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: _cancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}
