import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../photos/staged_photo.dart' show extensionOfXFile;

/// PROFILE UI REDESIGN V1 — a locally picked profile photo, not yet
/// uploaded. Mirrors `StagedPhoto` (`staged_photo.dart`) exactly, kept as
/// its own tiny type rather than reusing that one directly: a staged
/// visit photo and a staged avatar are conceptually different things
/// (one of several photos vs. the single canonical avatar) even though
/// their shape happens to be identical today.
class StagedAvatar {
  final XFile file;
  final Uint8List bytes;
  const StagedAvatar({required this.file, required this.bytes});
}

/// Opens the photo library for a SINGLE image — never `pickMultiImage`,
/// since a member has exactly one current avatar, never several to
/// choose from at once. Same compression strategy `pickStagedPhotos`
/// already established (`imageQuality: 85`, `requestFullMetadata: false`
/// — no EXIF/GPS metadata read, no extra permission prompt), with a
/// tighter `1024`-px cap on the longest side: generous enough for every
/// current/near-future avatar surface (Profile hero, Friends/Community
/// rows) while keeping the uploaded object small.
///
/// No interactive 1:1 crop step exists in this pass — no crop dependency
/// is present in this repository (`pubspec.yaml` audited before writing
/// this file: only `image_picker` exists, no `image_cropper` or
/// equivalent), and adding one is real native-platform complexity this
/// task's own brief explicitly says to avoid rather than silently add.
/// [MemberAvatar] instead renders any aspect ratio as a clean circle via
/// consistent `BoxFit.cover` + circular clipping at DISPLAY time — a
/// deliberate, documented V1 limitation (see `docs/Architecture/
/// PROFILE_AVATAR_V1.md`), not an oversight.
Future<StagedAvatar?> pickAvatarImage() async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
    maxWidth: 1024,
    maxHeight: 1024,
    requestFullMetadata: false,
  );
  if (file == null) return null;
  return StagedAvatar(file: file, bytes: await file.readAsBytes());
}

/// Re-exported so callers never need a separate import for the exact
/// same extension-detection rule `pickStagedPhotos` already uses.
String extensionOfStagedAvatar(StagedAvatar avatar) =>
    extensionOfXFile(avatar.file);
