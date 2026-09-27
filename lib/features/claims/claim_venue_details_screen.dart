import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../data/repositories/venue_claim_repository.dart';
import '../../models/venue_claim.dart';

/// Step 2 of the claim flow — the claimant's own role/contact details,
/// plus a permanently-visible explanation of what happens next (shown
/// BEFORE they submit, not only after — "zet op dat scherm duidelijk uit
/// wat er daarna gebeurt" reads as setting the expectation going in, not
/// a surprise confirmation screen afterward). No promise about how long
/// review takes, per explicit instruction.
class ClaimVenueDetailsScreen extends StatefulWidget {
  final VenueClaimVenueType venueType;
  final String venueId;
  final String venueName;
  final String? venueCity;

  // Optional DI seam — see ClaimVenueScreen's own identical convention.
  final VenueClaimRepository? claimRepo;

  const ClaimVenueDetailsScreen({
    super.key,
    required this.venueType,
    required this.venueId,
    required this.venueName,
    this.venueCity,
    this.claimRepo,
  });

  @override
  State<ClaimVenueDetailsScreen> createState() => _ClaimVenueDetailsScreenState();
}

class _ClaimVenueDetailsScreenState extends State<ClaimVenueDetailsScreen> {
  late final _claimRepo = widget.claimRepo ?? VenueClaimRepository(Supabase.instance.client);

  VenueClaimRole? _role;
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_role == null) {
      setState(() => _error = 'Choose your role');
      return;
    }
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter a business email address');
      return;
    }
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter a phone number');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _claimRepo.submitClaim(
        venueType: widget.venueType,
        venueId: widget.venueId,
        role: _role!,
        businessEmail: email,
        phone: phone,
        notes: _notesCtrl.text,
      );
      if (!mounted) return;
      // Shown in place, on this same screen (see [_submitted]'s own
      // build-time branch) rather than popping back through the search
      // screen to show a snackbar there — avoids needing a second
      // screen's context to survive this one's disposal, and reads as a
      // calmer confirmation than a fleeting snackbar after being carried
      // two screens back.
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is StateError ? e.message : 'Could not send this request. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Claim your venue',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
        automaticallyImplyLeading: !_submitted,
      ),
      body: _submitted ? _confirmation(context) : _form(context),
    );
  }

  Widget _confirmation(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CsSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_read_outlined, color: AppColors.forestGreen, size: 40),
            const SizedBox(height: CsSpacing.md),
            Text(
              'Request sent',
              style: CsTypography.placeTitle.copyWith(color: AppColors.forestGreen, fontSize: 20),
            ),
            const SizedBox(height: CsSpacing.sm),
            Text(
              "We'll review your claim for ${widget.venueName} and let you know here "
              "once we've made a decision.",
              textAlign: TextAlign.center,
              style: CsTypography.body.copyWith(color: AppColors.taupe),
            ),
            const SizedBox(height: CsSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: CsPrimaryButton(
                label: 'Done',
                surface: CsSurface.light,
                onTap: () => Navigator.of(context)
                  ..pop()
                  ..pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: CsSpacing.pageHorizontal,
        vertical: CsSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.venueName,
            style: CsTypography.placeTitle.copyWith(
              color: AppColors.forestGreen,
              fontSize: 22,
            ),
          ),
          if (widget.venueCity != null) ...[
            const SizedBox(height: 2),
            Text(
              widget.venueCity!,
              style: CsTypography.body.copyWith(color: AppColors.taupe),
            ),
          ],
          const SizedBox(height: CsSpacing.lg),
          Text(
            'Your role',
            style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final role in VenueClaimRole.values)
                _RoleChip(
                  label: role.label,
                  selected: _role == role,
                  onTap: () => setState(() => _role = role),
                ),
            ],
          ),
          const SizedBox(height: CsSpacing.md),
          CsTextField(
            label: 'Business email',
            controller: _emailCtrl,
            surface: CsSurface.light,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: CsSpacing.xs),
          Text(
            "Preferably on the venue's own domain — it helps us verify faster.",
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.md),
          CsTextField(
            label: 'Phone number',
            controller: _phoneCtrl,
            surface: CsSurface.light,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: CsSpacing.md),
          Text(
            'Anything else? (optional)',
            style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
          ),
          const SizedBox(height: CsSpacing.sm),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            minLines: 2,
            style: CsTypography.body.copyWith(color: AppColors.forestGreen),
            decoration: InputDecoration(
              hintText: 'Anything that helps us verify your connection to this venue.',
              hintStyle: CsTypography.body.copyWith(color: AppColors.taupe),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.subtleBorderLight),
              ),
            ),
          ),
          const SizedBox(height: CsSpacing.lg),
          Container(
            padding: const EdgeInsets.all(CsSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHAT HAPPENS NEXT',
                  style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
                ),
                const SizedBox(height: CsSpacing.sm),
                Text(
                  "We review every request by hand — we may reach out to verify your "
                  "connection to this venue before deciding. You'll be notified here "
                  "either way. We can't promise a specific timeline.",
                  style: CsTypography.body.copyWith(color: AppColors.forestGreen, height: 1.5),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: CsSpacing.md),
            Text(
              _error!,
              style: CsTypography.metadata.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: CsSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: CsPrimaryButton(
              label: 'Submit request',
              surface: CsSurface.light,
              loading: _submitting,
              onTap: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.forestGreen : Colors.transparent,
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.forestGreen, width: selected ? 0 : 1),
        ),
        child: Text(
          label,
          style: CsTypography.body.copyWith(
            color: selected ? AppColors.textOnDark : AppColors.forestGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
