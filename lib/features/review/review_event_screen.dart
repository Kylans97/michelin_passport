import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../data/repositories/review_repository.dart';
import '../../models/event.dart';
import '../../models/review_item.dart';
import '../events/event_date_format.dart';
import '../events/event_detail_screen.dart';
import 'review_item_screen.dart' show RejectWithNoteDialog;

/// Review for a venue's event (venue events phase 3, 20261018130000).
///
/// - **A submitted event:** its details as the venue entered them, and
///   "Preview the event page", which opens the real EventDetailScreen
///   (admins can read unpublished events). Approve publishes it; Reject
///   sends it back with a note.
/// - **A change to a live event:** already live, so this shows exactly
///   what changed, old → new. "Mark as seen" clears it from the queue;
///   "Take offline" rejects the event with a note, which hides it and
///   tells the venue.
///
/// Pops `true` once a decision has been saved.
class ReviewEventScreen extends StatefulWidget {
  final ReviewItem item;
  final ReviewRepository repository;

  /// Test seam: what "Preview the event page" opens.
  final Widget Function(String eventId)? previewBuilder;

  const ReviewEventScreen({
    super.key,
    required this.item,
    required this.repository,
    this.previewBuilder,
  });

  @override
  State<ReviewEventScreen> createState() => _ReviewEventScreenState();
}

class _ReviewEventScreenState extends State<ReviewEventScreen> {
  ReviewItem get _item => widget.item;
  bool get _isEdit => _item.kind == ReviewKind.venueEventEdit;
  late final Future<Event?> _event = _item.eventId == null
      ? Future.value(null)
      : widget.repository.loadEvent(_item.eventId!);
  bool _busy = false;
  String? _error;

  Future<void> _decide(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not save the decision. Please try again.';
      });
    }
  }

  Future<void> _reject() async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => RejectWithNoteDialog(title: _isEdit ? 'Take offline' : 'Reject'),
    );
    if (note == null || note.trim().isEmpty) return;
    await _decide(() => widget.repository.rejectEvent(_item, note.trim()));
  }

  void _preview() {
    final id = _item.eventId;
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => widget.previewBuilder?.call(id) ?? EventDetailScreen(eventId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          _item.kind.label,
          style: CsTypography.placeTitle.copyWith(color: AppColors.forestGreen, fontSize: 20),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<Event?>(
          future: _event,
          builder: (context, snap) {
            final event = snap.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.md,
                CsSpacing.pageHorizontal,
                CsSpacing.section,
              ),
              children: [
                Text(
                  event?.name ?? _item.eventName ?? 'Untitled event',
                  style: CsTypography.placeTitle.copyWith(color: AppColors.forestGreen),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    _item.venueName,
                    if (_item.venueCity != null) _item.venueCity!,
                    'from ${_item.submitterLabel}',
                  ].join(' · '),
                  style: CsTypography.metadata.copyWith(color: AppColors.taupe),
                ),
                const SizedBox(height: CsSpacing.lg),
                if (snap.connectionState == ConnectionState.waiting)
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.forestGreen, strokeWidth: 1.5),
                  )
                else if (_isEdit)
                  ..._changes()
                else if (event == null)
                  Text(
                    'Could not load this event.',
                    style: CsTypography.body.copyWith(color: AppColors.taupe),
                  )
                else
                  ..._details(event),
                const SizedBox(height: CsSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _item.eventId == null ? null : _preview,
                    icon: const Icon(Icons.visibility_outlined, color: AppColors.forestGreen),
                    label: Text(
                      _isEdit ? 'Open the live event' : 'Preview the event page',
                      style: CsTypography.bodyMedium.copyWith(color: AppColors.forestGreen),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: CsSpacing.md),
                  Text(_error!, style: CsTypography.metadata.copyWith(color: AppColors.error)),
                ],
                const SizedBox(height: CsSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: CsPrimaryButton(
                    label: _isEdit ? 'Mark as seen' : 'Approve and publish',
                    surface: CsSurface.light,
                    loading: _busy,
                    onTap: _busy
                        ? null
                        : () => _decide(
                            () => _isEdit
                                ? widget.repository.markEventEditSeen(_item)
                                : widget.repository.approveEvent(_item),
                          ),
                  ),
                ),
                const SizedBox(height: CsSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _reject,
                    child: Text(
                      _isEdit ? 'Take offline with a note' : 'Reject with a note',
                      style: CsTypography.metadata.copyWith(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _details(Event e) => [
    _field('When', formatEventDateAndTime(e)),
    _field('Type', e.eventType.label),
    _field(
      'Where',
      [e.venueName, e.address, e.city, e.countryCode]
          .where((v) => v != null && v.trim().isNotEmpty)
          .join(', '),
    ),
    if (e.ticketUrl != null) _field('Tickets', e.ticketUrl!),
    _field('Admission', e.admissionType.label),
    if (e.admissionNote != null) _field('Admission note', e.admissionNote!),
    const SizedBox(height: CsSpacing.sm),
    _label('DESCRIPTION'),
    const SizedBox(height: CsSpacing.xs),
    Text(e.description ?? '', style: CsTypography.body.copyWith(color: AppColors.forestGreen)),
  ];

  List<Widget> _changes() => [
    Text(
      'Already live. The venue changed:',
      style: CsTypography.body.copyWith(color: AppColors.forestGreen),
    ),
    const SizedBox(height: CsSpacing.md),
    for (final c in _item.eventChanges) ...[
      _label(c.field.replaceAll('_', ' ').toUpperCase()),
      const SizedBox(height: 2),
      Text(
        _show(c.oldValue),
        style: CsTypography.body.copyWith(
          color: AppColors.taupe,
          decoration: TextDecoration.lineThrough,
        ),
      ),
      Text(_show(c.newValue), style: CsTypography.body.copyWith(color: AppColors.forestGreen)),
      const SizedBox(height: CsSpacing.md),
    ],
  ];

  // A change's value as the venue would read it: nothing set shows as
  // "not given", never as a guessed value.
  static String _show(Object? value) {
    if (value == null) return 'not given';
    if (value is List) return value.isEmpty ? 'none' : value.join(', ');
    final s = value.toString();
    // "19:30:00" → "19:30"
    final time = RegExp(r'^(\d{2}:\d{2}):\d{2}$').firstMatch(s);
    return time != null ? time.group(1)! : s;
  }

  Widget _label(String text) =>
      Text(text, style: CsTypography.eyebrow.copyWith(color: AppColors.taupe));

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: CsSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label.toUpperCase()),
        const SizedBox(height: 2),
        Text(value, style: CsTypography.body.copyWith(color: AppColors.forestGreen)),
      ],
    ),
  );
}
