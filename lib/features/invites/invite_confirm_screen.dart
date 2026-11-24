import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/cs_editorial_glyphs.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/framed_image.dart';
import '../../core/widgets/member_avatar.dart';
import '../../data/repositories/hotel_repository.dart';
import '../../data/repositories/invite_link_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../models/invite_link.dart';
import '../auth/widgets/auth_presentation.dart';
import '../hotels/hotel_detail_screen.dart';
import '../private_chefs/private_chef_detail_screen.dart';
import '../restaurants/restaurant_detail_screen.dart';

/// "Elise Laurent invited you": the one step between an invitation link
/// and what it does. Shown by InviteLinkGate over the app, right after
/// "Your Passport is ready" for a new member and over whatever is open for
/// someone who already has the app. Nothing happens without Accept
/// (product owner, 2026-11-22): friends always, the visit unless the
/// person unticks it, and for a trip either a place on it or, through a
/// group link, a request the sender answers.
///
/// A venue's link (20261101750000) asks one thing: Follow. Following
/// sends that venue's event pushes to the phone, so it still waits for
/// the tap (product owner, 2026-11-23); it never makes a friend, and the
/// manager who shared it is never named.
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
    if (_result != null) {
      return p.kind == InviteLinkKind.venue
          ? _venueDone(p)
          : _done(p, _result!);
    }
    if (p.kind == InviteLinkKind.venue) return _venue(p);
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

  // A venue link: Follow, or what is already true.
  Widget _venue(InviteLinkPreview p) {
    final name = p.venueName ?? 'This venue';
    return switch (p.state) {
      'open' => AuthStepLayout(
        header: _venueHeader(p),
        title: name,
        subtitle:
            'Follow ${p.venueName ?? 'them'} and you hear first when they '
            'announce a dinner, a guest chef or a festival.',
        footer: [
          if (_error != null) ...[
            AuthErrorBanner(message: _error!),
            const SizedBox(height: CsSpacing.base),
          ],
          CsPrimaryButton(
            label: 'Follow',
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
        children: const [],
      ),
      'following' || 'accepted' => _venueMessage(
        p,
        title: 'You already follow $name',
        body: 'Nothing to do. Their events already reach you.',
      ),
      'own' => _message(
        title: 'This is your venue\'s link',
        body: 'Share it with your guests, so they can follow $name.',
      ),
      _ => _message(
        title: 'This link is no longer available',
        body:
            'The venue has made a new one. You can still find them in '
            'Explore.',
      ),
    };
  }

  Widget _venueDone(InviteLinkPreview p) => _venueMessage(
    p,
    title: 'You follow ${p.venueName ?? 'them'}',
    body: 'Their events reach you first, in the app and on your phone.',
  );

  Widget _venueMessage(
    InviteLinkPreview p, {
    required String title,
    required String body,
  }) => AuthStepLayout(
    header: _venueHeader(p),
    title: title,
    subtitle: body,
    footer: [
      if (p.venueId != null && p.venueType != null)
        CsPrimaryButton(
          label: 'View ${p.venueName ?? 'the venue'}',
          surface: CsSurface.dark,
          onTap: () => _openVenue(p.venueType!, p.venueId!),
        ),
      Center(child: AuthQuietAction(label: 'Close', onTap: widget.onDone)),
    ],
    children: const [],
  );

  // The card photo as the venue framed it, then its place and stars or
  // Keys in gold, which is what gold is for.
  Widget _venueHeader(InviteLinkPreview p) {
    final url = p.cardPhotoUrl;
    final stars = p.michelinStars ?? 0;
    final keys = p.michelinKeys ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (url != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 3 / 2,
              child: FramedImage(
                framing: p.cardFraming,
                builder: (alignment) => AppNetworkImage(
                  url,
                  zoom: p.cardFraming.zoom,
                  fit: BoxFit.cover,
                  alignment: alignment,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          const SizedBox(height: CsSpacing.base),
        ],
        Row(
          children: [
            if (stars > 0) ...[
              CsEditorialStarRow(count: stars),
              const SizedBox(width: CsSpacing.sm),
            ],
            if (keys > 0) ...[
              CsEditorialKeyRow(count: keys),
              const SizedBox(width: CsSpacing.sm),
            ],
            if (p.venuePlace != null)
              Flexible(
                child: Text(
                  p.venuePlace!,
                  style: CsTypography.metadata.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // Replaces this screen, so InviteLinkGate's push completes and the
  // link is cleared, and Back leads to wherever the person was.
  Future<void> _openVenue(String type, String id) async {
    final navigator = Navigator.of(context);
    Widget? screen;
    try {
      final client = Supabase.instance.client;
      screen = switch (type) {
        'restaurant' => switch (await RestaurantRepository(client).getById(id)) {
          final r? => RestaurantDetailScreen(restaurant: r),
          null => null,
        },
        'hotel' => switch (await HotelRepository(client).getById(id)) {
          final h? => HotelDetailScreen(hotel: h),
          null => null,
        },
        'private_chef' => PrivateChefDetailScreen(chefId: id),
        _ => null,
      };
    } catch (_) {
      screen = null;
    }
    if (!mounted) return;
    if (screen == null) {
      widget.onDone();
      return;
    }
    navigator.pushReplacement(MaterialPageRoute<void>(builder: (_) => screen!));
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
