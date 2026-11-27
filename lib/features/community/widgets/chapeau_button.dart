import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/cs_typography.dart';
import '../../../data/repositories/chapeau_repository.dart';

/// "Chapeau" under a friend's visit, stay or event stamp (20261101860000):
/// a small top hat and who gave one. Tapping gives it, tapping again takes
/// it back. On the feed's deep-green canvas.
class ChapeauButton extends StatefulWidget {
  final ChapeauSubject subject;
  final String subjectId;

  /// For tests: a repository with canned answers.
  final ChapeauRepository? repository;

  const ChapeauButton({
    super.key,
    required this.subject,
    required this.subjectId,
    this.repository,
  });

  @override
  State<ChapeauButton> createState() => _ChapeauButtonState();
}

class _ChapeauButtonState extends State<ChapeauButton> {
  // Null without a Supabase client (a widget test): no Chapeau line then.
  late final ChapeauRepository? _repo = widget.repository ?? _defaultRepo();

  static ChapeauRepository? _defaultRepo() {
    try {
      return ChapeauRepository(Supabase.instance.client);
    } catch (_) {
      return null;
    }
  }
  ChapeauSummary _summary = ChapeauSummary.none;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repo?.summary(widget.subject, widget.subjectId).then((s) {
      if (mounted) setState(() => _summary = s);
    });
  }

  Future<void> _toggle() async {
    final repo = _repo;
    if (_busy || repo == null) return;
    final before = _summary;
    setState(() {
      _busy = true;
      _summary = before.toggled('You');
    });
    try {
      if (before.givenByMe) {
        await repo.takeBack(widget.subject, widget.subjectId);
      } else {
        await repo.give(widget.subject, widget.subjectId);
      }
    } catch (_) {
      if (mounted) setState(() => _summary = before);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _label {
    final s = _summary;
    if (s.count == 0) return 'Chapeau';
    final names = s.recentNames;
    if (s.count == 1 && names.isNotEmpty) return 'Chapeau from ${names.first}';
    if (names.isEmpty) return 'Chapeau · ${s.count}';
    final others = s.count - 1;
    return 'Chapeau from ${names.first} and $others '
        '${others == 1 ? 'other' : 'others'}';
  }

  @override
  Widget build(BuildContext context) {
    if (_repo == null) return const SizedBox.shrink();
    final on = _summary.givenByMe;
    final color = on ? AppColors.terracottaOnDark : AppColors.secondaryOnDark;
    return Semantics(
      button: true,
      selected: on,
      label: on ? '$_label. Tap to take back your Chapeau' : _label,
      excludeSemantics: true,
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(18, 14),
                painter: TopHatPainter(color: color, filled: on),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CsTypography.metadata.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small top hat: crown, band and brim. Outlined, or filled once given.
class TopHatPainter extends CustomPainter {
  final Color color;
  final bool filled;

  const TopHatPainter({required this.color, this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    final crown = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.24, 0, w * 0.52, h * 0.74),
      topLeft: const Radius.circular(1.5),
      topRight: const Radius.circular(1.5),
    );
    final brim = Rect.fromLTWH(0, h * 0.70, w, h * 0.26);

    if (filled) {
      canvas.drawRRect(crown, fill);
      canvas.drawOval(brim, fill);
    } else {
      canvas.drawRRect(crown, stroke);
      canvas.drawOval(brim, stroke);
      canvas.drawLine(
        Offset(w * 0.24, h * 0.52),
        Offset(w * 0.76, h * 0.52),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(TopHatPainter old) =>
      old.color != color || old.filled != filled;
}
