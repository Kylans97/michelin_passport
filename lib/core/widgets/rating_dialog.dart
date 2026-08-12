import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../../data/repositories/friendship_repository.dart';

class VisitLogResult {
  final double? rating;
  final String? notes;
  const VisitLogResult({this.rating, this.notes});
}

/// Shows a bottom sheet for logging a visit: personal rating + optional notes.
/// Returns [VisitLogResult] or null if the user dismissed without saving.
Future<VisitLogResult?> showRatingDialog(
  BuildContext context,
  String restaurantName,
) {
  return showModalBottomSheet<VisitLogResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RatingSheet(restaurantName: restaurantName),
  );
}

class _RatingSheet extends StatefulWidget {
  final String restaurantName;
  const _RatingSheet({required this.restaurantName});

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  double _rating = 8.0;
  bool _skipRating = false;
  final _notesCtrl = TextEditingController();
  final _friendshipRepo = FriendshipRepository(Supabase.instance.client);
  List<Map<String, dynamic>> _friends = [];
  final Set<String> _taggedFriendNames = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      // FriendshipRepository.getFriends() reads auth.uid() server-side
      // (Social Foundation Step 1) — it no longer takes a userId param.
      final friendships = await _friendshipRepo.getFriends();
      if (mounted) {
        setState(() {
          _friends = friendships
              .map((f) => {'id': f.friendId, 'name': f.label})
              .toList();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    String notes = _notesCtrl.text.trim();
    if (_taggedFriendNames.isNotEmpty) {
      final friendStr = 'With: ${_taggedFriendNames.join(', ')}';
      notes = notes.isEmpty ? friendStr : '$notes\n$friendStr';
    }
    Navigator.pop(
      context,
      VisitLogResult(
        rating: _skipRating ? null : _rating,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Log your visit',
            style: GoogleFonts.playfairDisplay(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.restaurantName,
            style: GoogleFonts.inter(color: AppColors.gold, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Rating slider
          Row(
            children: [
              Text(
                'Personal rating',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (!_skipRating)
                Text(
                  _rating.toStringAsFixed(1),
                  style: GoogleFonts.playfairDisplay(
                    color: AppColors.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (!_skipRating) ...[
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.gold,
                inactiveTrackColor: AppColors.surface,
                thumbColor: AppColors.gold,
                overlayColor: AppColors.goldAlpha10,
                trackHeight: 3,
              ),
              child: Slider(
                value: _rating,
                min: 0,
                max: 10,
                divisions: 100,
                onChanged: (v) => setState(() => _rating = v),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '10',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _skipRating = !_skipRating),
            child: Text(
              _skipRating ? 'Add a rating' : 'Skip rating',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Friend tags
          if (_friends.isNotEmpty) ...[
            Text(
              'Who did you dine with?',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _friends.map((f) {
                final name = f['name'] as String;
                final selected = _taggedFriendNames.contains(name);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _taggedFriendNames.remove(name);
                    } else {
                      _taggedFriendNames.add(name);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.goldMuted : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.goldBorder60
                            : AppColors.cardBorder,
                        width: selected ? 1.0 : 0.5,
                      ),
                    ),
                    child: Text(
                      name,
                      style: GoogleFonts.inter(
                        color: selected
                            ? AppColors.gold
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Notes field
          TextField(
            controller: _notesCtrl,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Add a note (optional)…',
            ),
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Save visit',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
