import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/subtle_text_action.dart';
import '../../data/repositories/venue_team_repository.dart';
import '../../models/managed_venue.dart';
import '../../models/venue_about_submission.dart';
import '../../models/venue_team_member.dart';

/// Team, reached from a venue's landing page (VenueManagementScreen): the
/// chef and the manager the venue shows on its page, each a name and a
/// short text. Restaurants and hotels only — a private chef's page is the
/// chef.
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

  // The chef first, as on the page.
  static const _roles = [VenueTeamRole.chef, VenueTeamRole.manager];

  late Future<_TeamState> _future;
  final _nameCtrls = {for (final r in _roles) r: TextEditingController()};
  final _bioCtrls = {for (final r in _roles) r: TextEditingController()};
  final _busy = <VenueTeamRole>{};
  final _errors = <VenueTeamRole, String>{};

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
      );
      if (!mounted) return;
      setState(() => _busy.remove(role));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Submitted for review.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy.remove(role);
        _errors[role] = e is StateError
            ? e.message
            : 'Could not submit. Please try again.';
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
                  "Show who runs the kitchen and the room. Each name and text is "
                  "reviewed by hand before it appears on your page, and you'll see "
                  "the outcome here.",
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
