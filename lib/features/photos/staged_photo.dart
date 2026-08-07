import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// A locally picked photo, not yet uploaded — held in memory only. Used by
/// Add Visit / Add Stay's staged photo selection: a visit_id must exist
/// before a photo can safely reference it, so photos picked while logging
/// a visit/stay stay local (bytes + preview) until the visit/stay itself
/// has actually been saved.
class StagedPhoto {
  final XFile file;
  final Uint8List bytes;

  const StagedPhoto({required this.file, required this.bytes});
}

const allowedPhotoExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic'};

/// The extension to store a picked file under — falls back to 'jpg' for
/// anything unrecognized, same defensive behavior PhotoRepository already
/// relies on for uploaded file naming.
String extensionOfXFile(XFile file) {
  final dot = file.name.lastIndexOf('.');
  if (dot == -1 || dot == file.name.length - 1) return 'jpg';
  final ext = file.name.substring(dot + 1).toLowerCase();
  return allowedPhotoExtensions.contains(ext) ? ext : 'jpg';
}

/// Opens the photo library for multi-select, applying this app's one
/// shared compression strategy (imageQuality 85, maxWidth 1600, no
/// metadata permission prompt) and reading each result into memory. Used
/// by both the staged pre-save picker (Add Visit/Add Stay) and
/// VisitPhotosSection's post-save "add more photos" — one picker
/// configuration, not two.
Future<List<StagedPhoto>> pickStagedPhotos() async {
  final picker = ImagePicker();
  final picked = await picker.pickMultiImage(
    imageQuality: 85,
    maxWidth: 1600,
    requestFullMetadata: false,
  );
  return [
    for (final file in picked)
      StagedPhoto(file: file, bytes: await file.readAsBytes()),
  ];
}
