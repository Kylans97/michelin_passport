import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_spacing.dart';
import '../../../core/theme/cs_typography.dart';
import '../../passport/models/passport_stamp_award.dart';
import '../friend_profile_data.dart';
import '../friend_profile_screen.dart' show FriendVenueVisit;
import 'friend_profile_stamp.dart';

StampAward? _awardFor(FriendVenueVisit fv) {
  final stars = fv.stars;
  final keys = fv.keys;
  if (stars != null && stars > 0) return StarsAward(stars);
  if (keys != null && keys > 0) return KeysAward(keys);
  return null;
}

String _semanticLabel(FriendVenueVisit fv) {
  final award = _awardFor(fv);
  final awardPhrase = switch (award) {
    null => null,
    StarsAward(:final count) => count == 1 ? '1 Michelin star' : '$count Michelin stars',
    KeysAward(:final count) => count == 1 ? '1 MICHELIN Key' : '$count MICHELIN Keys',
    EventTypeAward() => null,
  };
  final parts = [
    fv.venue.name,
    fv.cityName,
    ?awardPhrase,
    if (fv.score != null) 'rated ${fv.score} out of 10',
    '${fv.visit.visitedOn.day} '
        '${const [
          'January', 'February', 'March', 'April', 'May', 'June', 'July',
          'August', 'September', 'October', 'November', 'December',
        ][fv.visit.visitedOn.month - 1]}',
  ];
  return parts.join(', ');
}

/// Read-only passport page for layout A: the ivory card chrome (guilloché
/// background, spine shadow, `{NAME}'S ENTRIES` / `p. NN` header), 2
/// stamps per page, swipeable with page dots when there are more. Renders
/// the dashed empty state itself when [visits] is empty — no "next stamp"
/// slot (that's a first-person Passport concept; this is someone else's
/// already-settled history).
class FriendProfileStampPage extends StatefulWidget {
  final List<FriendVenueVisit> visits;
  final String ownerName;
  final ValueChanged<FriendVenueVisit> onTapStamp;

  const FriendProfileStampPage({
    super.key,
    required this.visits,
    required this.ownerName,
    required this.onTapStamp,
  });

  static const double height = 250;

  @override
  State<FriendProfileStampPage> createState() => _FriendProfileStampPageState();
}

class _FriendProfileStampPageState extends State<FriendProfileStampPage> {
  late final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<List<FriendVenueVisit>> get _pages {
    final pages = <List<FriendVenueVisit>>[];
    for (var i = 0; i < widget.visits.length; i += 2) {
      pages.add(widget.visits.skip(i).take(2).toList());
    }
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;

    return Container(
      height: FriendProfileStampPage.height,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(child: CustomPaint(painter: _GuillochePainter())),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CsSpacing.lg,
                    CsSpacing.md,
                    CsSpacing.lg,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${widget.ownerName.toUpperCase()}'S ENTRIES",
                        style: CsTypography.editorialLabel().copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'p. ${(_page + 1).toString().padLeft(2, '0')}',
                        style: CsTypography.editorialTitle(size: 15).copyWith(
                          color: AppColors.textPrimary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: pages.isEmpty
                      ? const _EmptyStampState()
                      : PageView.builder(
                          controller: _controller,
                          itemCount: pages.length,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemBuilder: (context, i) => _StampPageContent(
                            visits: pages[i],
                            onTapStamp: widget.onTapStamp,
                          ),
                        ),
                ),
                if (pages.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: CsSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < pages.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Container(
                            width: i == _page ? 14 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? AppColors.forestGreen
                                  : AppColors.textSecondary.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 12,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0x2A000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StampPageContent extends StatelessWidget {
  final List<FriendVenueVisit> visits;
  final ValueChanged<FriendVenueVisit> onTapStamp;

  const _StampPageContent({required this.visits, required this.onTapStamp});

  @override
  Widget build(BuildContext context) {
    FriendStampVariant? previousVariant;
    FriendStampInk? previousInk;
    final children = <Widget>[];

    for (var i = 0; i < visits.length; i++) {
      final fv = visits[i];
      final id = fv.visit.id;
      final variant = pickFriendStampVariant(id, avoid: previousVariant);
      final ink = pickFriendStampInk(id, avoid: previousInk);
      previousVariant = variant;
      previousInk = ink;

      final data = FriendStampPaintData(
        seedId: id,
        cityName: fv.cityName,
        countryCode: fv.venue.countryCode,
        venueName: fv.venue.name,
        date: fv.visit.visitedOn,
        score: fv.score,
        award: _awardFor(fv),
        ink: ink.color,
      );

      children.add(
        Align(
          alignment: i == 0 ? const Alignment(-0.55, 0.1) : const Alignment(0.55, 0.1),
          child: GestureDetector(
            onTap: () => onTapStamp(fv),
            child: FriendProfileStamp(
              data: data,
              variant: variant,
              rotationDegrees: pickFriendStampRotation(id),
              semanticLabel: _semanticLabel(fv),
            ),
          ),
        ),
      );
    }

    return Stack(children: children);
  }
}

class _EmptyStampState extends StatelessWidget {
  const _EmptyStampState();

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(96, 96), painter: _DashedCirclePainter()),
          Text(
            'No stamps\nyet',
            textAlign: TextAlign.center,
            style: CsTypography.editorialTitle(size: 13, italic: true).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    const dashLength = 6.0;
    const gapLength = 5.0;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    final paint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final anglePerDash = (2 * math.pi) / dashCount;
    final dashAngle = anglePerDash * (dashLength / (dashLength + gapLength));
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * anglePerDash,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) => false;
}

/// Fine concentric guilloché rings, gold at 9% opacity — a local
/// reimplementation of the main Passport page's own `_GuillochePainter`
/// (private there, and small enough that duplicating it here is cheaper
/// than promoting a fourth internal to public for one reuse).
class _GuillochePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, size.height + 20);
    final maxRadius = (center - Offset.zero).distance + size.width;
    final paint = Paint()
      ..color = AppColors.stampGuillocheLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const spacing = 8.0;
    var radius = spacing;
    while (radius < maxRadius) {
      canvas.drawCircle(center, radius, paint);
      radius += spacing;
    }
  }

  @override
  bool shouldRepaint(covariant _GuillochePainter oldDelegate) => false;
}
