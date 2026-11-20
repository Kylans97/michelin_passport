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
/// [hasSeenWelcome]/[markWelcomeSeen]/[welcomeGreeting] are optional DI seams (same
/// constructor-injection convention as every other Supabase-backed screen
/// in this app) defaulting to real ProfileRepository-backed calls.
class OnboardingGate extends StatefulWidget {
  final String userId;
  final Widget child;
  final Future<bool> Function(String userId)? hasSeenWelcome;
  final Future<void> Function(String userId)? markWelcomeSeen;

  /// The first name and member number for the flow's last page, the
  /// member's own Passport cover. Fetched only once the flow is known to
  /// be needed, while the member is still on the first pages.
  final Future<WelcomeGreeting> Function(String userId)? welcomeGreeting;

  const OnboardingGate({
    super.key,
    required this.userId,
    required this.child,
    this.hasSeenWelcome,
    this.markWelcomeSeen,
    this.welcomeGreeting,
  });

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  // null = still checking (BrandedSplash shown, same "waiting" visual
  // AuthGate uses for its own first-auth-event gap).
  bool? _needsWelcome;
  WelcomeGreeting _greeting = const WelcomeGreeting();

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
    setState(() {
      _needsWelcome = null;
      _greeting = const WelcomeGreeting();
    });
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
    if (!seen) _loadGreeting(userId);
  }

  // Best effort: without it the last page still works, it just says "Your
  // Passport is ready" and the cover's "NO. —" instead of a name and
  // number. Never blocks or delays the flow itself.
  Future<void> _loadGreeting(String userId) async {
    final fetch =
        widget.welcomeGreeting ??
        (id) => ProfileRepository(
          Supabase.instance.client,
        ).getWelcomeGreeting(userId: id);
    try {
      final greeting = await fetch(userId);
      if (!mounted || userId != widget.userId) return;
      setState(() => _greeting = greeting);
    } catch (_) {
      // Swallowed deliberately — see above.
    }
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
    if (_needsWelcome!) {
      return WelcomeFlow(
        onDone: _onDone,
        firstName: _greeting.firstName,
        memberNumber: _greeting.memberNumber,
      );
    }
    return widget.child;
  }
}
