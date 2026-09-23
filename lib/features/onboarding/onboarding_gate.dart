import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/branded_splash.dart';
import '../../data/repositories/profile_repository.dart';
import 'welcome_flow_screen.dart';

/// Sits between AuthGate and the real app — AuthGate only cares about
/// "is there a session"; this is specifically about "has THIS signed-in
/// account completed the first-run welcome flow", kept separate rather
/// than folded into AuthGate's own sticky-state tracking (which already
/// juggles password recovery) to keep each widget's job narrow.
///
/// [hasSeenWelcome]/[markWelcomeSeen] are optional DI seams (same
/// constructor-injection convention as every other Supabase-backed screen
/// in this app) defaulting to real ProfileRepository-backed calls.
class OnboardingGate extends StatefulWidget {
  final String userId;
  final Widget child;
  final Future<bool> Function(String userId)? hasSeenWelcome;
  final Future<void> Function(String userId)? markWelcomeSeen;

  const OnboardingGate({
    super.key,
    required this.userId,
    required this.child,
    this.hasSeenWelcome,
    this.markWelcomeSeen,
  });

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  // null = still checking (BrandedSplash shown, same "waiting" visual
  // AuthGate uses for its own first-auth-event gap).
  bool? _needsWelcome;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(covariant OnboardingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different account signed in on the same device (shared device,
    // sign-out then a different sign-in) — re-check for the NEW user
    // rather than keep showing whatever the previous account's result was.
    if (widget.userId != oldWidget.userId) _check();
  }

  Future<void> _check() async {
    final userId = widget.userId;
    setState(() => _needsWelcome = null);
    final fetch =
        widget.hasSeenWelcome ??
        (id) => ProfileRepository(
          Supabase.instance.client,
        ).hasSeenWelcome(userId: id);
    // A flaky fetch must never permanently block the whole app behind the
    // splash — default to "already seen" (skip the flow) on failure. The
    // opposite failure mode (showing the welcome flow again to someone who
    // already saw it, on the rare occasion this happens to error) is a
    // minor annoyance; blocking app entry outright would not be.
    bool seen;
    try {
      seen = await fetch(userId);
    } catch (_) {
      seen = true;
    }
    if (!mounted || userId != widget.userId) return; // stale response guard
    setState(() => _needsWelcome = !seen);
  }

  Future<void> _onDone() async {
    final mark =
        widget.markWelcomeSeen ??
        (id) => ProfileRepository(
          Supabase.instance.client,
        ).markWelcomeSeen(userId: id);
    // Same reasoning as the fetch above: if the write fails, still let the
    // person into the app rather than trap them on the welcome flow — the
    // worst case is seeing it again next launch, not being unable to
    // proceed at all.
    try {
      await mark(widget.userId);
    } catch (_) {
      // Swallowed deliberately — see above.
    }
    if (mounted) setState(() => _needsWelcome = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_needsWelcome == null) return const BrandedSplash();
    if (_needsWelcome!) return WelcomeFlow(onDone: _onDone);
    return widget.child;
  }
}
