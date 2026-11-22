import 'package:flutter/material.dart';
import 'invite_confirm_screen.dart';
import 'pending_invite.dart';

/// Opens [InviteConfirmScreen] over the signed-in app whenever an
/// invitation is waiting on this phone (PendingInvite). AuthGate puts it
/// after ProfileSetupGate and before OnboardingGate, so a new member sees
/// it right after "Your Passport is ready" and only then the welcome
/// flow; someone who already has the app sees it on top of whatever
/// screen is open, which stays as it was underneath.
class InviteLinkGate extends StatefulWidget {
  const InviteLinkGate({super.key, required this.child, this.pending});

  final Widget child;
  final PendingInvite? pending;

  @override
  State<InviteLinkGate> createState() => _InviteLinkGateState();
}

class _InviteLinkGateState extends State<InviteLinkGate> {
  late final PendingInvite _store = widget.pending ?? PendingInvite.instance;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _store.token.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _store.token.removeListener(_check);
    super.dispose();
  }

  Future<void> _check() async {
    final token = _store.token.value;
    if (token == null || _showing || !mounted) return;
    _showing = true;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (routeContext) => InviteConfirmScreen(
          token: token,
          onDone: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
    _showing = false;
    // Answered or set aside: either way it no longer waits. A newer link
    // that arrived meanwhile is kept and shown next.
    if (_store.token.value == token) {
      await _store.clear();
    } else {
      _check();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
