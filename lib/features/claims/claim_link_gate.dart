import 'package:flutter/material.dart';
import 'pending_claim.dart';
import 'venue_claim_intro_screen.dart';

/// Opens [VenueClaimIntroScreen] over the signed-in app whenever someone
/// arrived from the website's venue guide (PendingClaim). AuthGate puts
/// it beside InviteLinkGate, after ProfileSetupGate: a new member sees it
/// right after "Your Passport is ready", and OnboardingGate leaves the
/// guests' welcome flow out for them (product owner, 2026-11-25: they
/// came for the claim). Someone who already has the app sees it on top
/// of whatever screen is open.
class ClaimLinkGate extends StatefulWidget {
  const ClaimLinkGate({super.key, required this.child, this.pending});

  final Widget child;
  final PendingClaim? pending;

  @override
  State<ClaimLinkGate> createState() => _ClaimLinkGateState();
}

class _ClaimLinkGateState extends State<ClaimLinkGate> {
  late final PendingClaim _store = widget.pending ?? PendingClaim.instance;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _store.waiting.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _store.waiting.removeListener(_check);
    super.dispose();
  }

  Future<void> _check() async {
    if (!_store.waiting.value || _showing || !mounted) return;
    _showing = true;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const VenueClaimIntroScreen(),
      ),
    );
    _showing = false;
    // Claimed, or set aside with Later: either way it no longer waits.
    // Claiming stays in Profile.
    await _store.clear();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
