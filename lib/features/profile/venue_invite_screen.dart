import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../data/repositories/invite_link_repository.dart';
import '../../models/invite_link.dart';
import '../../models/managed_venue.dart';

/// "Invite guests to follow", reached from a venue's landing page
/// (VenueManagementScreen). The venue's one standing link
/// (20261101750000): whoever opens it and taps Follow follows the venue,
/// even when they still have to install the app. It speaks for the venue,
/// never for the manager who shares it, and it is the same link for every
/// manager. The count is everyone who followed through any of the venue's
/// links; under 5 the server leaves it out, and it never says who.
///
/// The link is made the first time this screen opens. "Make a new link"
/// stops it and its QR code, for a link that went somewhere it shouldn't.
class VenueInviteScreen extends StatefulWidget {
  final ManagedVenue venue;
  final InviteLinkRepository? repository;

  const VenueInviteScreen({super.key, required this.venue, this.repository});

  /// The landing page's one-line summary.
  static String summary(VenueInviteLink link) => link.summary;

  @override
  State<VenueInviteScreen> createState() => _VenueInviteScreenState();
}

class _VenueInviteScreenState extends State<VenueInviteScreen> {
  late final InviteLinkRepository _repo =
      widget.repository ?? InviteLinkRepository(Supabase.instance.client);
  final _shareKey = GlobalKey();
  final _qrShareKey = GlobalKey();

  VenueInviteLink? _link;
  bool _loading = true;
  bool _loadFailed = false;
  bool _busy = false;

  String get _type => widget.venue.venueTypeWireValue;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      var link = await _repo.venueLink(_type, widget.venue.id);
      if (link.token == null) {
        await _repo.createVenueLink(_type, widget.venue.id);
        link = await _repo.venueLink(_type, widget.venue.id);
      }
      if (mounted) setState(() => _link = link);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Rect? _origin(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _shareLink() async {
    final url = _link?.url;
    if (url == null) return;
    await SharePlus.instance.share(
      ShareParams(
        text: venueShareMessage(widget.venue.name, url),
        subject: 'Follow ${widget.venue.name} on Mantelier',
        sharePositionOrigin: _origin(_shareKey),
      ),
    );
  }

  Future<void> _copy() async {
    final url = _link?.url;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  // A print-ready PNG: the code on the page's own ivory, with a quiet
  // zone around it so a scanner finds the edges on a menu or a card.
  Future<void> _shareQr() async {
    final url = _link?.url;
    if (url == null || _busy) return;
    setState(() => _busy = true);
    try {
      const side = 1200.0;
      const margin = 120.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, side, side),
        Paint()..color = AppColors.warmWhite,
      );
      canvas.translate(margin, margin);
      QrPainter(
        data: url,
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: AppColors.deepGreen,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: AppColors.deepGreen,
        ),
      ).paint(canvas, const Size(side - 2 * margin, side - 2 * margin));
      final image = await recorder.endRecording().toImage(
        side.toInt(),
        side.toInt(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'Follow ${widget.venue.name}.png',
            ),
          ],
          fileNameOverrides: ['Follow ${widget.venue.name}.png'],
          sharePositionOrigin: _origin(_qrShareKey),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not make the QR code. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _replace() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.warmWhite,
        title: Text(
          'Make a new link?',
          style: CsTypography.sectionTitle.copyWith(
            color: AppColors.forestGreen,
          ),
        ),
        content: Text(
          'The current link and its QR code stop working. Everyone who '
          'already follows ${widget.venue.name} keeps following.',
          style: CsTypography.body.copyWith(color: AppColors.forestGreen),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Make a new link'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.createVenueLink(_type, widget.venue.id, replace: true);
      final link = await _repo.venueLink(_type, widget.venue.id);
      if (mounted) setState(() => _link = link);
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not make a new link. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Invite guests to follow',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.forestGreen,
                strokeWidth: 1.5,
              ),
            )
          : _loadFailed || _link?.url == null
          ? Center(
              child: TextButton(
                onPressed: _load,
                child: Text(
                  'Could not load your link. Tap to try again.',
                  textAlign: TextAlign.center,
                  style: CsTypography.body.copyWith(color: AppColors.taupe),
                ),
              ),
            )
          : _body(_link!),
    );
  }

  Widget _body(VenueInviteLink link) => ListView(
    padding: const EdgeInsets.symmetric(
      horizontal: CsSpacing.pageHorizontal,
      vertical: CsSpacing.md,
    ),
    children: [
      Text(
        'Anyone who opens this link can follow ${widget.venue.name} on '
        'Mantelier with one tap, even if they still need the app. They hear '
        'first when you announce an event.',
        style: CsTypography.body.copyWith(
          color: AppColors.forestGreen,
          height: 1.5,
        ),
      ),
      const SizedBox(height: CsSpacing.lg),
      Container(
        padding: const EdgeInsets.all(CsSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR LINK',
              style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
            ),
            const SizedBox(height: CsSpacing.xs),
            SelectableText(
              link.url!.replaceFirst('https://', ''),
              style: CsTypography.body.copyWith(color: AppColors.forestGreen),
            ),
            if (link.displayCode != null) ...[
              const SizedBox(height: CsSpacing.xs),
              Text(
                'Or the code ${link.displayCode}, typed at the entrance of '
                'the app.',
                style: CsTypography.metadata.copyWith(color: AppColors.taupe),
              ),
            ],
            const SizedBox(height: CsSpacing.base),
            Center(
              child: Semantics(
                label: 'QR code for the link',
                child: QrImageView(
                  data: link.url!,
                  size: 176,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.deepGreen,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.deepGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: CsSpacing.lg),
      CsPrimaryButton(
        key: _shareKey,
        label: 'Share link',
        surface: CsSurface.light,
        onTap: _shareLink,
      ),
      const SizedBox(height: CsSpacing.sm),
      Row(
        children: [
          Expanded(
            child: CsSecondaryButton(
              label: 'Copy link',
              surface: CsSurface.light,
              onTap: _copy,
            ),
          ),
          const SizedBox(width: CsSpacing.sm),
          Expanded(
            child: CsSecondaryButton(
              key: _qrShareKey,
              label: 'Share QR code',
              surface: CsSurface.light,
              onTap: _busy ? null : _shareQr,
            ),
          ),
        ],
      ),
      const SizedBox(height: CsSpacing.xl),
      Container(height: 1, color: AppColors.cardBorder),
      const SizedBox(height: CsSpacing.base),
      Text(
        link.followedCount == null
            ? 'Fewer than 5 followed so far'
            : '${link.followedCount} followed through your link',
        style: CsTypography.bodyMedium.copyWith(color: AppColors.forestGreen),
      ),
      const SizedBox(height: 2),
      Text(
        'Counted from ${_date(link.followedSince ?? link.createdAt!)}. You '
        'see how many, never who.',
        style: CsTypography.metadata.copyWith(color: AppColors.taupe),
      ),
      const SizedBox(height: CsSpacing.xl),
      SubtleTextAction(
        label: _busy ? 'One moment…' : 'Make a new link',
        onTap: _busy ? () {} : _replace,
      ),
      const SizedBox(height: CsSpacing.xxl),
    ],
  );

  static String _date(DateTime d) => inviteDate(d.toLocal());
}
