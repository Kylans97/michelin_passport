import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
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

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(
          color: AppColors.gold,
          strokeWidth: 1.5,
        ),
      ),
    );
  }
}
