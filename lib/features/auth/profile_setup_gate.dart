import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/branded_splash.dart';
import '../../data/repositories/profile_repository.dart';
import 'profile_setup_screen.dart';

/// Between sign-in and the welcome flow: an account made with Apple or an
/// email code has no username yet, so [ProfileSetupScreen] comes first.
/// When the check itself fails the app opens anyway (the Profile tab still
/// offers to choose a username); a member is never locked out by a read.
class ProfileSetupGate extends StatefulWidget {
  const ProfileSetupGate({
    super.key,
    required this.userId,
    required this.child,
    this.suggestedName,
    this.needsSetup,
  });

  final String userId;
  final Widget child;
  final String? suggestedName;
  final Future<bool> Function(String userId)? needsSetup;

  @override
  State<ProfileSetupGate> createState() => _ProfileSetupGateState();
}

class _ProfileSetupGateState extends State<ProfileSetupGate> {
  bool? _needsSetup;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(covariant ProfileSetupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) _check();
  }

  Future<void> _check() async {
    setState(() => _needsSetup = null);
    bool needs;
    try {
      needs =
          await (widget.needsSetup ??
              (id) => ProfileRepository(
                Supabase.instance.client,
              ).needsProfileSetup(userId: id))(widget.userId);
    } catch (_) {
      needs = false;
    }
    if (mounted) setState(() => _needsSetup = needs);
  }

  @override
  Widget build(BuildContext context) {
    final needs = _needsSetup;
    if (needs == null) return const BrandedSplash();
    if (!needs) return widget.child;
    return ProfileSetupScreen(
      userId: widget.userId,
      suggestedName: widget.suggestedName,
      onSaved: () => setState(() => _needsSetup = false),
    );
  }
}
