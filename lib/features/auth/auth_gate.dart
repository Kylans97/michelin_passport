import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/cs_image_placeholder.dart' show csMonogramAssetPath;
import 'login_screen.dart';

// AuthGate listens to Supabase's auth state stream and shows either the
// main app (child) or the login screen.  Swap the session-null branch to
// show an onboarding flow later.

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});

  // The main app scaffold — shown when a session is active.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // While waiting for the first event, show a branded splash.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final session = snapshot.data?.session;
        return session != null ? child : const LoginScreen();
      },
    );
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
            Image.asset(csMonogramAssetPath, width: 56, height: 56),
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
