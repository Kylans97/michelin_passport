import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/branded_splash.dart';
import '../onboarding/onboarding_gate.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';

// AuthGate listens to Supabase's auth state stream and shows the main app
// (behind OnboardingGate — see below), the login screen, or — mid password
// recovery — ResetPasswordScreen.
//
// A StatefulWidget with its own subscription, not a StreamBuilder, because
// "are we mid password recovery" has to survive events that aren't
// passwordRecovery itself. A recovery link leaves a real (if short-lived)
// session behind, and Supabase auto-refreshes it while the app is open —
// that later tokenRefreshed event would be the STREAM's latest value the
// moment it fires. A StreamBuilder keyed on "the latest event" would read
// that as "back to normal" and drop the person into the main app before
// they've actually set a new password. _passwordRecoveryPending is set by
// passwordRecovery and cleared only by signedOut (which
// completePasswordRecovery's own explicit sign-out triggers once the flow
// actually finishes) — nothing in between resets it.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.child,
    this.authStateChanges,
    this.hasSeenWelcome,
    this.markWelcomeSeen,
  });

  // The main app scaffold — shown (via OnboardingGate) when a session is
  // active and no password recovery is in progress.
  final Widget child;

  // Defaults to the real Supabase.instance.client.auth.onAuthStateChange —
  // same constructor-injection convention as every other auth-adjacent
  // screen in this app. Overridden in tests with a plain StreamController
  // so the sticky passwordRecovery-vs-tokenRefreshed logic above can be
  // driven directly, without reaching into gotrue's own @internal
  // notifyAllSubscribers to fake a stream event.
  final Stream<AuthState>? authStateChanges;

  // Pure pass-through to the OnboardingGate this class renders once a
  // session exists — AuthGate itself has no opinion on welcome-flow state,
  // this only exists so a test can drive a signedIn session all the way to
  // `child` without OnboardingGate falling back to a real
  // ProfileRepository/Supabase.instance call.
  final Future<bool> Function(String userId)? hasSeenWelcome;
  final Future<void> Function(String userId)? markWelcomeSeen;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _subscription;

  // Mirrors StreamBuilder's own ConnectionState.waiting — true until the
  // stream's first event arrives (SupabaseAuth always emits one, either a
  // restored session or initialSession, very shortly after app start).
  bool _hasEvent = false;
  Session? _session;
  bool _passwordRecoveryPending = false;

  @override
  void initState() {
    super.initState();
    final stream =
        widget.authStateChanges ??
        Supabase.instance.client.auth.onAuthStateChange;
    _subscription = stream.listen((data) {
      setState(() {
        _hasEvent = true;
        _session = data.session;
        switch (data.event) {
          case AuthChangeEvent.passwordRecovery:
            _passwordRecoveryPending = true;
          case AuthChangeEvent.signedOut:
            _passwordRecoveryPending = false;
          default:
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasEvent) return const BrandedSplash();
    if (_passwordRecoveryPending && _session != null) {
      return const ResetPasswordScreen();
    }
    final session = _session;
    if (session == null) return const LoginScreen();
    // OnboardingGate owns "has THIS account completed the welcome flow" —
    // a separate concern from auth state, kept out of this class so it
    // doesn't grow a third sticky flag alongside password recovery.
    return OnboardingGate(
      userId: session.user.id,
      hasSeenWelcome: widget.hasSeenWelcome,
      markWelcomeSeen: widget.markWelcomeSeen,
      child: widget.child,
    );
  }
}
