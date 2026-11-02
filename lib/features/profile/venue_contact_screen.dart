import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_surface_context.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../data/repositories/venue_contact_repository.dart';
import '../../models/managed_venue.dart';

/// Website and phone, reached from a venue's landing page
/// (VenueManagementScreen). Saving puts them on the page at once, with no
/// review: they change during the year, and the venue knows them best
/// (decided 2026-11-02). Admins see each change in the review queue.
/// A private chef has a website only.
class VenueContactScreen extends StatefulWidget {
  final ManagedVenue venue;
  final VenueContactRepository? repository;

  const VenueContactScreen({super.key, required this.venue, this.repository});

  /// The landing page's one-line summary.
  static String summary(VenueContact contact, {required bool hasPhone}) {
    final parts = [
      if ((contact.website ?? '').isNotEmpty) 'Website',
      if (hasPhone && (contact.phone ?? '').isNotEmpty) 'phone',
    ];
    if (parts.isEmpty) return 'Not on your page yet';
    final text = '${parts.join(' and ')} on your page';
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  State<VenueContactScreen> createState() => _VenueContactScreenState();
}

class _VenueContactScreenState extends State<VenueContactScreen> {
  late final _repo =
      widget.repository ?? VenueContactRepository(Supabase.instance.client);
  final _websiteCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  String? _websiteError;
  String? _phoneError;
  String? _error;

  String get _type => widget.venue.venueTypeWireValue;
  bool get _hasPhone => _type != 'private_chef';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _websiteCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final contact = await _repo.load(
        venueType: _type,
        venueId: widget.venue.id,
      );
      if (!mounted) return;
      _websiteCtrl.text = contact.website ?? '';
      _phoneCtrl.text = contact.phone ?? '';
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final websiteProblem = venueWebsiteProblem(_websiteCtrl.text);
    final phoneProblem = _hasPhone ? venuePhoneProblem(_phoneCtrl.text) : null;
    setState(() {
      _websiteError = websiteProblem;
      _phoneError = phoneProblem;
      _error = null;
    });
    if (websiteProblem != null || phoneProblem != null) return;
    setState(() => _saving = true);
    try {
      await _repo.save(
        venueType: _type,
        venueId: widget.venue.id,
        website: _websiteCtrl.text,
        phone: _phoneCtrl.text,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved. Your page shows it now.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          _hasPhone ? 'Website and phone' : 'Website',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.forestGreen,
                strokeWidth: 1.5,
              ),
            )
          : _loadFailed
          ? Center(
              child: TextButton(
                onPressed: _load,
                child: Text(
                  'Could not load your details. Tap to try again.',
                  textAlign: TextAlign.center,
                  style: CsTypography.body.copyWith(color: AppColors.taupe),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: CsSpacing.pageHorizontal,
                vertical: CsSpacing.md,
              ),
              children: [
                Text(
                  'Keep these up to date yourself. Changes show on your page '
                  'as soon as you save. Leave a field empty to take it off.',
                  style: CsTypography.body.copyWith(
                    color: AppColors.forestGreen,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: CsSpacing.lg),
                _label('WEBSITE'),
                TextField(
                  controller: _websiteCtrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  style: CsTypography.body.copyWith(
                    color: AppColors.forestGreen,
                  ),
                  decoration: _decoration(
                    'https://www.yourvenue.com',
                    _websiteError,
                  ),
                ),
                if (_hasPhone) ...[
                  const SizedBox(height: CsSpacing.lg),
                  _label('PHONE'),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: CsTypography.body.copyWith(
                      color: AppColors.forestGreen,
                    ),
                    decoration: _decoration('+31 20 123 4567', _phoneError),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: CsSpacing.sm),
                  Text(
                    _error!,
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: CsSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: CsPrimaryButton(
                    label: 'Save',
                    surface: CsSurface.light,
                    loading: _saving,
                    onTap: _save,
                  ),
                ),
                const SizedBox(height: CsSpacing.xxl),
              ],
            ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: CsSpacing.sm),
    child: Text(
      text,
      style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
    ),
  );

  InputDecoration _decoration(String hint, String? error) => InputDecoration(
    hintText: hint,
    hintStyle: CsTypography.body.copyWith(color: AppColors.taupe),
    errorText: error,
    errorMaxLines: 2,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.subtleBorderLight),
    ),
  );
}
