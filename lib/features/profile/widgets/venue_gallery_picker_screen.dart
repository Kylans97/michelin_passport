import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';

/// A minimal multi-select photo grid, backed directly by `photo_manager`
/// (PhotoKit/MediaStore) rather than a system picker sheet — needed
/// because [pickVenuePhotos] (`venue_photo_picker.dart`) must resolve the
/// TRUE original asset for whatever gets tapped here, which requires an
/// [AssetEntity] to call `getOriginBytes()` on, not a copied file a system
/// picker sheet would hand back. `photo_manager` itself has no picker UI
/// or selection/limit concept at all (unlike `image_picker.
/// pickMultiImage(limit:)`) — every bit of selection state below is this
/// screen's own, which is what makes [maxSelectable] an exact cap rather
/// than an advisory one; [pickVenuePhotos] still clamps the result
/// defensively anyway, matching `pickStagedPhotos`/`clampToRemainingCapacity`'s
/// own established "never trust a single enforcement point" pattern.
///
/// Two modes, chosen by [maxSelectable]:
///  * `maxSelectable == 1` (the existing at-cap "pick one to replace" flow,
///    unchanged): tapping a photo pops it immediately, matching this
///    screen's original single-pick behavior exactly.
///  * `maxSelectable > 1`: tapping toggles a numbered selection (order of
///    selection is preserved — that order becomes the step-through order),
///    disabled once the cap is reached, with a "Done" action to commit.
/// Deliberately plain otherwise: one date-ordered "all photos" album, no
/// album switcher, no search.
class VenueGalleryPickerScreen extends StatefulWidget {
  final int maxSelectable;

  const VenueGalleryPickerScreen({super.key, required this.maxSelectable});

  @override
  State<VenueGalleryPickerScreen> createState() => _VenueGalleryPickerScreenState();
}

class _VenueGalleryPickerScreenState extends State<VenueGalleryPickerScreen> {
  static const _pageSize = 60;

  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  AssetPathEntity? _album;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _nextPage = 0;

  bool get _multiSelect => widget.maxSelectable > 1;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    final albums = await PhotoManager.getAssetPathList(onlyAll: true, type: RequestType.image);
    if (!mounted) return;
    if (albums.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    _album = albums.first;
    final assets = await _album!.getAssetListPaged(page: 0, size: _pageSize);
    if (!mounted) return;
    setState(() {
      _assets.addAll(assets);
      _loading = false;
      _hasMore = assets.length == _pageSize;
      _nextPage = 1;
    });
  }

  Future<void> _loadMore() async {
    final album = _album;
    if (_loadingMore || !_hasMore || album == null) return;
    _loadingMore = true;
    final assets = await album.getAssetListPaged(page: _nextPage, size: _pageSize);
    if (!mounted) return;
    setState(() {
      _assets.addAll(assets);
      _hasMore = assets.length == _pageSize;
      _nextPage++;
      _loadingMore = false;
    });
  }

  void _onTapAsset(AssetEntity asset) {
    if (!_multiSelect) {
      Navigator.of(context).pop([asset]);
      return;
    }
    setState(() {
      final index = _selected.indexWhere((a) => a.id == asset.id);
      if (index != -1) {
        _selected.removeAt(index);
      } else if (_selected.length < widget.maxSelectable) {
        _selected.add(asset);
      }
      // Already at the cap and tapping an unselected photo: a no-op, not
      // an error — the cap was already stated up front (AppBar subtitle),
      // so there's nothing new to tell the manager at this point.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          _multiSelect ? 'Choose photos' : 'Choose a photo',
          style: CsTypography.placeTitle.copyWith(color: AppColors.forestGreen, fontSize: 20),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
        bottom: _multiSelect
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: CsSpacing.sm),
                  child: Text(
                    _selected.isEmpty
                        ? 'Choose up to ${widget.maxSelectable} photos'
                        : '${_selected.length} of ${widget.maxSelectable} selected',
                    style: CsTypography.metadata.copyWith(color: AppColors.taupe),
                  ),
                ),
              )
            : null,
        actions: [
          if (_multiSelect)
            TextButton(
              onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected),
              child: Text(
                'Done',
                style: CsTypography.body.copyWith(
                  color: _selected.isEmpty ? AppColors.taupe : AppColors.forestGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _assets.isEmpty
          ? Center(child: Text('No photos found', style: CsTypography.body.copyWith(color: AppColors.taupe)))
          : NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.pixels > notification.metrics.maxScrollExtent - 400) {
                  _loadMore();
                }
                return false;
              },
              child: GridView.builder(
                padding: const EdgeInsets.all(2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: _assets.length,
                itemBuilder: (context, index) {
                  final asset = _assets[index];
                  final selectionNumber = _multiSelect
                      ? _selected.indexWhere((a) => a.id == asset.id) + 1
                      : 0;
                  return GestureDetector(
                    onTap: () => _onTapAsset(asset),
                    child: _Thumbnail(asset: asset, selectionNumber: selectionNumber),
                  );
                },
              ),
            ),
    );
  }
}

/// Thumbnail data is always locally cached by the OS — unlike the
/// original, this never triggers an iCloud download, so no progress UI
/// is needed here (matches [pickVenuePhotos]' own doc comment: the
/// download step is specifically about the ORIGIN representation).
/// [selectionNumber] is 0 when unselected (or in single-pick mode), else
/// this photo's 1-based position in the selection order — shown as a
/// numbered badge so the manager can see the order they'll be stepped
/// through in.
class _Thumbnail extends StatelessWidget {
  final AssetEntity asset;
  final int selectionNumber;
  const _Thumbnail({required this.asset, required this.selectionNumber});

  @override
  Widget build(BuildContext context) {
    final selected = selectionNumber > 0;
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder<Uint8List?>(
          future: asset.thumbnailDataWithSize(const ThumbnailSize.square(200)),
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null) {
              return Container(color: AppColors.cardBorder);
            }
            return Image.memory(data, fit: BoxFit.cover);
          },
        ),
        if (selected)
          Positioned.fill(
            child: Container(color: AppColors.forestGreen.withValues(alpha: 0.25)),
          ),
        if (selected)
          Positioned(
            top: 4,
            right: 4,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: AppColors.forestGreen,
              child: Text(
                '$selectionNumber',
                style: CsTypography.metadata.copyWith(
                  color: AppColors.warmWhite,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
