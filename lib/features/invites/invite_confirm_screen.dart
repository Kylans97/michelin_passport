import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/member_avatar.dart';
import '../../data/repositories/invite_link_repository.dart';
import '../../models/invite_link.dart';
import '../auth/widgets/auth_presentation.dart';

/// "Elise Laurent invited you": the one step between an invitation link
/// and what it does. Shown by InviteLinkGate over the app, right after
/// "Your Passport is ready" for a new member and over whatever is open for
/// someone who already has the app. Nothing happens without Accept
/// (product owner, 2026-11-22): friends always, the visit unless the
/// person unticks it, and for a trip either a place on it or, through a
/// group link, a request the sender answers.
///
/// [onDone] is called once the person is finished here, accepted or not;
/// [onNotNow] keeps nothing on the phone, the link stays usable until it
/// expires.
class InviteConfirmScreen extends StatefulWidget {
  const InviteConfirmScreen({
    super.key,
    required this.token,
    required this.onDone,
    this.repository,
  });

  final String token;
  final VoidCallback onDone;
  final InviteLinkRepository? repository;

  @override
  State<InviteConfirmScreen> createState() => _InviteConfirmScreenState();
}

class _InviteConfirmScreenState extends State<InviteConfirmScreen> {
  late final InviteLinkRepository _repo =
      widget.repository ?? InviteLinkRepository(Supabase.instance.client);

  InviteLinkPreview? _preview;
  Object? _loadError;
  bool _addVisit = true;
  bool _saving = false;
  String? _error;
  InviteLinkResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final p = await _repo.preview(widget.token);
      if (mounted) setState(() => _preview = p);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _accept() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final r = await _repo.redeem(widget.token, addVisit: _addVisit);
      if (mounted) setState(() => _result = r);
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Could not accept. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    if (_loadError != null) {
      return _message(
        title: 'This invitation could not be opened',
        body: 'Check your connection and try again.',
        primary: CsPrimaryButton(
          label: 'Try again',
          surface: CsSurface.dark,
          onTap: _load,
        ),
      );
    }
    if (p == null) {
      return const Scaffold(
        backgroundColor: AppColors.deepGreen,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.textOnDark,
            strokeWidth: 1.5,
          ),
        ),
      );
    }
    if (_result != null) return _done(p, _result!);
    return switch (p.state) {
      'open' => _ask(p),
      'own' => _message(
        title: 'This is your own invitation',
        body: 'Send it to someone who isn\'t on Mantelier yet.',
      ),
      'accepted' => _message(
        title: 'You already accepted this invitation',
        body: p.kind == InviteLinkKind.trip && p.needsApproval
            ? '${p.senderFirstName} still has to let you in on the trip.'
            : 'You and ${p.senderFirstName} are friends.',
      ),
      'expired' => _message(
        title: 'This invitation has expired',
        body:
            'Links from ${p.senderFirstName} are open for 14 days. Ask for a '
            'new one, or find ${p.senderFirstName} under Friends and send a '
            'friend request.',
      ),
      _ => _message(
        title: 'This invitation is no longer available',
        body: 'Ask whoever sent it for a new link.',
      ),
    };
  }

  Widget _avatars(InviteLinkPreview p) => Align(
    alignment: Alignment.centerLeft,
    child: MemberAvatar(avatarUrl: null, displayName: p.sender, size: 56),
  );

  Widget _ask(InviteLinkPreview p) {
    final first = p.senderFirstName;
    final options = <Widget>[
      _Option(
        checked: true,
        title: 'Become friends with $first',
        subtitle:
            'You see each other\'s Passport and plans, the way all friends do.',
      ),
      if (p.kind == InviteLinkKind.visit) ...[
        const _Rule(),
        _Option(
          checked: _addVisit,
          onTap: () => setState(() => _addVisit = !_addVisit),
          title: 'Add ${p.venueName ?? 'this visit'} to my Passport',
          subtitle:
              '${p.venueType == 'hotel' ? 'Stay' : 'Dinner'} on '
              '${p.visitedOn == null ? 'the same day' : inviteDate(p.visitedOn!)}. '
              'Only if you were there. Your score and notes stay your own.',
        ),
      ],
      if (p.kind == InviteLinkKind.trip) ...[
        const _Rule(),
        _Option(
          checked: true,
          title: 'Join ${p.tripTitle ?? 'the trip'}',
          subtitle: [
            if (p.tripStartDate != null)
              inviteMonths(p.tripStartDate!, p.tripEndDate ?? p.tripStartDate!),
            p.needsApproval
                ? '$first lets you in on the trip.'
                : 'You see the plan and can add to it. Leave whenever you like.',
          ].join('. '),
        ),
      ],
    ];
    return AuthStepLayout(
      header: _avatars(p),
      title: p.kind == InviteLinkKind.trip
          ? '${p.sender} invited you on a trip'
          : '${p.sender} invited you',
      subtitle: 'Choose what to accept.',
      footer: [
        if (_error != null) ...[
          AuthErrorBanner(message: _error!),
          const SizedBox(height: CsSpacing.base),
        ],
        CsPrimaryButton(
          label: p.kind == InviteLinkKind.trip ? 'Join the trip' : 'Accept',
          surface: CsSurface.dark,
          loading: _saving,
          onTap: _saving ? null : _accept,
        ),
        Center(
          child: AuthQuietAction(
            label: 'Not now',
            onTap: _saving ? null : widget.onDone,
          ),
        ),
      ],
      children: options,
    );
  }

  Widget _done(InviteLinkPreview p, InviteLinkResult r) {
    final first = p.senderFirstName;
    final title = r.becameFriends
        ? 'You and $first are friends'
        : 'You and $first were already friends';
    final body = switch ((r.kind, r.tripState)) {
      (InviteLinkKind.visit, _) when r.visitId != null =>
        '${p.venueName ?? 'The visit'} is in your Passport. Add your own score '
            'whenever you like.',
      (InviteLinkKind.visit, _) when r.visitAlreadyPresent =>
        '${p.venueName ?? 'This visit'} was already in your Passport.',
      (InviteLinkKind.trip, 'joined') =>
        'You are on ${p.tripTitle ?? 'the trip'}. Find it under Trips.',
      (InviteLinkKind.trip, 'already_on_trip') =>
        'You were already on ${p.tripTitle ?? 'the trip'}.',
      (InviteLinkKind.trip, 'awaiting_approval') =>
        '$first has your request to join ${p.tripTitle ?? 'the trip'}. You '
            'hear as soon as $first lets you in.',
      (InviteLinkKind.trip, 'sender_left') =>
        '$first is no longer on ${p.tripTitle ?? 'that trip'}, so there was '
            'no place to give you.',
      _ => 'Find $first under Friends.',
    };
    return _message(
      title: title,
      body: body,
      header: _avatars(p),
      primaryLabel: 'Continue',
    );
  }

  Widget _message({
    required String title,
    required String body,
    Widget? header,
    Widget? primary,
    String primaryLabel = 'Close',
  }) => AuthStepLayout(
    header: header,
    title: title,
    subtitle: body,
    footer: [
      primary ??
          CsPrimaryButton(
            label: primaryLabel,
            surface: CsSurface.dark,
            onTap: widget.onDone,
          ),
      if (primary != null)
        Center(
          child: AuthQuietAction(label: 'Close', onTap: widget.onDone),
        ),
    ],
    children: const [],
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.checked,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final bool checked;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: checked,
    button: onTap != null,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.base),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: checked ? AppColors.textOnDark : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: checked
                    ? null
                    : Border.all(color: AppColors.secondaryOnDark, width: 1.5),
              ),
              child: checked
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.deepGreen,
                    )
                  : null,
            ),
            const SizedBox(width: CsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: CsTypography.bodyMedium.copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: AppColors.subtleBorderDark);
}
