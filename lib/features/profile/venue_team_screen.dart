import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../data/repositories/venue_photo_submission_repository.dart'
    show VenuePhotoRejectedException;
import '../../data/repositories/venue_team_repository.dart';
import '../../models/managed_venue.dart';
import '../../models/venue_about_submission.dart';
import '../../models/venue_team_member.dart';
import 'widgets/venue_photo_picker.dart';

/// Team, reached from a venue's landing page (VenueManagementScreen): the
/// chef, the manager and the sommelier the venue shows on its page, each
/// a name, a text and optionally a portrait. Restaurants and hotels only
/// — a private chef's page is the chef.
///
/// Same path as the about text (VenueProfileScreen): a new name or text
/// is reviewed before it shows, and the outcome appears here. Taking
/// someone off the page needs no review and happens at once.
class VenueTeamScreen extends StatefulWidget {
  final ManagedVenue venue;
  final VenueTeamRepository? teamRepo;

  const VenueTeamScreen({super.key, required this.venue, this.teamRepo});

  /// The landing page's one-line summary.
  static String summary(
    List<VenueTeamMember> current,
    Map<VenueTeamRole, VenueTeamSubmission> mine,
  ) {
    final waiting = mine.values.where((s) => s.isOpen).length;
    final shown = current.length;
    return [
      if (shown == 0)
        'No one shown yet'
      else if (shown == 1)
        '1 person shown'
      else
        '$shown people shown',
      if (waiting > 0) '$waiting awaiting review',
    ].join(' · ');
  }

  @override
  State<VenueTeamScreen> createState() => _VenueTeamScreenState();
}

class _TeamState {
  final List<VenueTeamMember> current;
  final Map<VenueTeamRole, VenueTeamSubmission> mine;
  const _TeamState({required this.current, required this.mine});

  VenueTeamMember? currentFor(VenueTeamRole role) {
    for (final m in current) {
      if (m.role == role) return m;
    }
    return null;
  }
}

class _VenueTeamScreenState extends State<VenueTeamScreen> {
  late final _repo =
      widget.teamRepo ?? VenueTeamRepository(Supabase.instance.client);

  // In the page's order.
  static const _roles = VenueTeamRole.pageOrder;

  late Future<_TeamState> _future;
  final _nameCtrls = {for (final r in _roles) r: TextEditingController()};
  final _bioCtrls = {for (final r in _roles) r: TextEditingController()};
  final _busy = <VenueTeamRole>{};
  final _errors = <VenueTeamRole, String>{};

  // A portrait picked but not yet submitted, and a request to take the
  // current one off. Both clear on a successful submit.
  final _pickedPhotos = <VenueTeamRole, Uint8List>{};
  final _removePhoto = <VenueTeamRole>{};

  // A portrait waiting for review, shown through a signed link.
  final _pendingPhotoUrls = <VenueTeamRole, String>{};

  // Prefilled once, on the first load — never on a reload, which would
  // overwrite what the manager is typing (same rule as the about text).
  bool _hasPrefilled = false;

  String get _type => widget.venue.venueTypeWireValue;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._nameCtrls.values, ..._bioCtrls.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load() {
    setState(() {
      _future =
          Future.wait([
            _repo.loadCurrent(venueType: _type, venueId: widget.venue.id),
            _repo.loadMyLatestSubmissions(
              venueType: _type,
              venueId: widget.venue.id,
            ),
          ]).then((results) {
            final state = _TeamState(
              current: results[0] as List<VenueTeamMember>,
              mine: results[1] as Map<VenueTeamRole, VenueTeamSubmission>,
            );
            _resolvePendingPhotos(state);
            if (!_hasPrefilled) {
              for (final role in _roles) {
                // What is waiting wins over what is shown: it is the newer
                // version, and what the manager last wrote.
                final open = state.mine[role];
                final shown = state.currentFor(role);
                final name = (open != null && open.isOpen)
                    ? open.name
                    : shown?.name;
                final bio = (open != null && open.isOpen)
                    ? open.bio
                    : shown?.bio;
                _nameCtrls[role]!.text = name ?? '';
                _bioCtrls[role]!.text = bio ?? '';
              }
              _hasPrefilled = true;
            }
            return state;
          });
    });
  }

  Future<void> _resolvePendingPhotos(_TeamState state) async {
    for (final entry in state.mine.entries) {
      final path = entry.value.photoPath;
      if (!entry.value.isOpen || path == null) continue;
      try {
        final url = await _repo.signedPhotoUrl(path);
        if (mounted) setState(() => _pendingPhotoUrls[entry.key] = url);
      } catch (_) {
        // The status line still says a version is waiting.
      }
    }
  }

  Future<void> _pickPhoto(VenueTeamRole role) async {
    final picked = await pickVenuePhotos(context, maxSelectable: 1);
    if (!mounted || picked.isEmpty) return;
    setState(() {
      _pickedPhotos[role] = picked.first.bytes;
      _removePhoto.remove(role);
      _errors.remove(role);
    });
  }

  void _clearPhoto(VenueTeamRole role, {required bool hasCurrent}) {
    setState(() {
      if (_pickedPhotos.remove(role) == null && hasCurrent) {
        _removePhoto.add(role);
      }
    });
  }

  Future<void> _submit(VenueTeamRole role) async {
    if (_busy.contains(role)) return;
    final name = _nameCtrls[role]!.text.trim();
    if (name.isEmpty) {
      setState(() => _errors[role] = 'Add a name before submitting.');
      return;
    }
    setState(() {
      _busy.add(role);
      _errors.remove(role);
    });
    try {
      await _repo.submit(
        venueType: _type,
        venueId: widget.venue.id,
        role: role,
        name: name,
        bio: _bioCtrls[role]!.text,
        photoBytes: _pickedPhotos[role],
        removePhoto: _removePhoto.contains(role),
      );
      if (!mounted) return;
      setState(() {
        _busy.remove(role);
        _pickedPhotos.remove(role);
        _removePhoto.remove(role);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Submitted for review.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy.remove(role);
        _errors[role] = switch (e) {
          StateError(:final message) => message,
          VenuePhotoRejectedException(:final rejection) => rejection.message,
          _ => 'Could not submit. Please try again.',
        };
      });
    }
  }

  Future<void> _remove(VenueTeamRole role) async {
    final label = role.labelFor(_type).toLowerCase();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove the $label?'),
        content: const Text(
          "They come off your page now, and anything still waiting for review "
          "for this role is withdrawn. You can add someone again any time.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy.add(role);
      _errors.remove(role);
    });
    try {
      await _repo.remove(
        venueType: _type,
        venueId: widget.venue.id,
        role: role,
      );
      if (!mounted) return;
      _nameCtrls[role]!.clear();
      _bioCtrls[role]!.clear();
      setState(() => _busy.remove(role));
      _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy.remove(role);
        _errors[role] = 'Could not remove. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Team',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: FutureBuilder<_TeamState>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.forestGreen,
                strokeWidth: 1.5,
              ),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(CsSpacing.xl),
                child: Text(
                  'Something went wrong. Pull down to try again.',
                  textAlign: TextAlign.center,
                  style: CsTypography.body.copyWith(color: AppColors.taupe),
                ),
              ),
            );
          }
          final state = snap.data!;
          return RefreshIndicator(
            color: AppColors.forestGreen,
            backgroundColor: AppColors.warmWhite,
            onRefresh: () async => _load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.pageHorizontal,
                vertical: CsSpacing.md,
              ),
              children: [
                Text(
                  "Show who runs the kitchen, the room and the cellar. Each name, "
                  "text and photo is reviewed by hand before it appears on your "
                  "page, and you'll see the outcome here. Please write in English.",
                  style: CsTypography.body.copyWith(
                    color: AppColors.forestGreen,
                    height: 1.5,
                  ),
                ),
                for (final role in _roles) ...[
                  const SizedBox(height: CsSpacing.xl),
                  Container(height: 1, color: AppColors.cardBorder),
                  const SizedBox(height: CsSpacing.lg),
                  _roleSection(role, state),
                ],
                const SizedBox(height: CsSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _roleSection(VenueTeamRole role, _TeamState state) {
    final shown = state.currentFor(role);
    final mine = state.mine[role];
    final busy = _busy.contains(role);
    final error = _errors[role];
    final canRemove = shown != null || (mine?.isOpen ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          role.labelFor(_type).toUpperCase(),
          style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
        ),
        const SizedBox(height: CsSpacing.sm),
        Text(
          shown == null
              ? 'Not on your page yet.'
              : 'On your page: ${shown.name}',
          style: CsTypography.body.copyWith(color: AppColors.forestGreen),
        ),
        if (mine != null &&
            mine.removedAt == null &&
            mine.status != VenueAboutSubmissionStatus.approved) ...[
          const SizedBox(height: CsSpacing.sm),
          _StatusLine(submission: mine),
        ],
        const SizedBox(height: CsSpacing.md),
        _photoRow(role, shown, mine),
        const SizedBox(height: CsSpacing.md),
        TextField(
          controller: _nameCtrls[role],
          maxLength: venueTeamNameMaxLength,
          textCapitalization: TextCapitalization.words,
          style: CsTypography.body.copyWith(color: AppColors.forestGreen),
          decoration: _decoration('Name'),
        ),
        const SizedBox(height: CsSpacing.xs),
        TextField(
          controller: _bioCtrls[role],
          maxLines: 4,
          minLines: 2,
          maxLength: venueTeamBioMaxLength,
          style: CsTypography.body.copyWith(color: AppColors.forestGreen),
          decoration: _decoration('A few words about them (optional)'),
        ),
        if (error != null) ...[
          const SizedBox(height: CsSpacing.xs),
          Text(
            error,
            style: CsTypography.metadata.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: CsSpacing.md),
        SizedBox(
          width: double.infinity,
          child: CsPrimaryButton(
            label: 'Submit for review',
            surface: CsSurface.light,
            loading: busy,
            onTap: () => _submit(role),
          ),
        ),
        if (canRemove) ...[
          const SizedBox(height: CsSpacing.xs),
          SubtleTextAction(
            label: 'Remove from page',
            onTap: busy ? () {} : () => _remove(role),
          ),
        ],
      ],
    );
  }

  // The portrait as it will be: a newly picked one, else one waiting for
  // review, else the one on the page — unless it's being removed.
  Widget _photoRow(
    VenueTeamRole role,
    VenueTeamMember? shown,
    VenueTeamSubmission? mine,
  ) {
    final picked = _pickedPhotos[role];
    final removing = _removePhoto.contains(role);
    final pendingUrl = (mine?.isOpen ?? false) ? _pendingPhotoUrls[role] : null;
    final url = removing ? null : (pendingUrl ?? shown?.photoUrl);
    final hasPhoto = picked != null || url != null;
    final Widget image = picked != null
        ? Image.memory(picked, width: 64, height: 80, fit: BoxFit.cover)
        : url != null
        ? Image.network(url, width: 64, height: 80, fit: BoxFit.cover)
        : const Icon(Icons.person_outline_rounded, color: AppColors.taupe);
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 64,
            height: 80,
            color: AppColors.ivory,
            alignment: Alignment.center,
            child: image,
          ),
        ),
        const SizedBox(width: CsSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SubtleTextAction(
                label: hasPhoto ? 'Change photo' : 'Add a photo (optional)',
                onTap: () => _pickPhoto(role),
              ),
              if (hasPhoto)
                SubtleTextAction(
                  label: picked != null ? 'Undo new photo' : 'Remove photo',
                  onTap: () => _clearPhoto(role, hasCurrent: url != null),
                ),
              if (picked != null || removing)
                Text(
                  'Sent with your next submission.',
                  style: CsTypography.metadata.copyWith(color: AppColors.taupe),
                ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: CsTypography.body.copyWith(color: AppColors.taupe),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.subtleBorderLight),
    ),
  );
}

class _StatusLine extends StatelessWidget {
  final VenueTeamSubmission submission;
  const _StatusLine({required this.submission});

  @override
  Widget build(BuildContext context) {
    final rejected = submission.status == VenueAboutSubmissionStatus.rejected;
    final note = submission.reviewNote?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              rejected
                  ? Icons.storefront_outlined
                  : Icons.hourglass_top_outlined,
              color: AppColors.forestGreen,
              size: 18,
            ),
            const SizedBox(width: CsSpacing.sm),
            Expanded(
              child: Text(
                rejected
                    ? "Your latest version (${submission.name}) wasn't approved."
                    : 'Your latest version (${submission.name}) is awaiting review.',
                style: CsTypography.metadata.copyWith(color: AppColors.taupe),
              ),
            ),
          ],
        ),
        if (rejected && note != null && note.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            note,
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
        ],
      ],
    );
  }
}
