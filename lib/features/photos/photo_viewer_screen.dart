import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/visit_photo.dart';

/// Fullscreen, swipeable photo viewer. MVP scope only: no likes, comments,
/// captions editing, or delete-from-here — delete stays on the grid (long
/// press), so this screen doesn't need to report state changes back to its
/// caller.
class PhotoViewerScreen extends StatefulWidget {
  final List<VisitPhoto> photos;
  final Map<String, String> urls;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    required this.urls,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          '${_index + 1} / ${widget.photos.length}',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final url = widget.urls[widget.photos[i].storagePath];
          return Center(
            child: url == null
                ? const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 40,
                  )
                : InteractiveViewer(
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
          );
        },
      ),
    );
  }
}
