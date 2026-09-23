import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/cs_image_placeholder.dart' show csMonogramAssetPath;
import 'login_screen.dart';
import 'reset_password_screen.dart';

// AuthGate listens to Supabase's auth state stream and shows the main app,
// the login screen, or — mid password recovery — ResetPasswordScreen.
// Swap the session-null branch to show an onboarding flow later.
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
  const AuthGate({super.key, required this.child, this.authStateChanges});

  // The main app scaffold — shown when a session is active and no password
  // recovery is in progress.
  final Widget child;

  // Defaults to the real Supabase.instance.client.auth.onAuthStateChange —
  // same constructor-injection convention as every other auth-adjacent
  // screen in this app. Overridden in tests with a plain StreamController
  // so the sticky passwordRecovery-vs-tokenRefreshed logic above can be
  // driven directly, without reaching into gotrue's own @internal
  // notifyAllSubscribers to fake a stream event.
  final Stream<AuthState>? authStateChanges;

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
    if (!_hasEvent) return const _SplashScreen();
    if (_passwordRecoveryPending && _session != null) {
      return const ResetPasswordScreen();
    }
    return _session != null ? widget.child : const LoginScreen();
  }
}

// Shown only for the brief moment before Supabase's auth stream emits its
// first event — the same deep-green entrance canvas as LoginScreen/
// SignupScreen (Step 4A), so there's no flash of the old ivory theme before
// the branded screens appear.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.deepGreen,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Same whitespace-in-the-asset correction as AuthBrandHeader
            // (auth_presentation.dart) — matched to its non-compact 80px
            // so the mark reads consistently across the splash-to-login
            // transition, not smaller on the splash that precedes it.
            SvgPicture.asset(csMonogramAssetPath, width: 80, height: 80),
            const SizedBox(height: 24),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: AppColors.textOnDark,
                strokeWidth: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
