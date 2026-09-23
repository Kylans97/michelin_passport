import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';
import 'cs_image_placeholder.dart' show csMonogramAssetPath;

/// The deep-green canvas + monogram + spinner shown for a brief "waiting on
/// something before we know what to render" moment — originally
/// AuthGate's own private `_SplashScreen` (the gap before Supabase's auth
/// stream emits its first event), pulled out here once OnboardingGate
/// needed the exact same visual for its own gap (the moment between a
/// session appearing and its has_seen_welcome check resolving). Same
/// deep-green entrance canvas as LoginScreen/SignupScreen (Step 4A), so
/// there's no flash of a different theme before the branded screens appear.
class BrandedSplash extends StatelessWidget {
  const BrandedSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.deepGreen,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
