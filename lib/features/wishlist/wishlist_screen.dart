import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../models/restaurant.dart';
import 'widgets/wishlist_card.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  late final WishlistRepository _repo = WishlistRepository(
    Supabase.instance.client,
  );

  late Future<List<Restaurant>> _future;

  @override
  void initState() {
    super.initState();
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    _future = _repo.getWishlist(uid);
  }

  void _load() {
    if (!mounted) return;
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    setState(() {
      _future = _repo.getWishlist(uid);
    });
  }

  Future<void> _remove(Restaurant r) async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    await _repo.remove(userId: uid, restaurantId: r.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Restaurant>>(
      future: _future,
      builder: (context, snap) {
        final items = snap.data ?? [];

        return RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.card,
          onRefresh: () async => _load(),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('Wishlist'),
                pinned: true,
                backgroundColor: AppColors.background,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Row(
                    children: [
                      Text(
                        'Dream Destinations',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(width: 10),
                      if (snap.connectionState == ConnectionState.waiting)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: AppColors.gold,
                            strokeWidth: 1.5,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.goldMuted,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.goldBorder40,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '${items.length}',
                            style: GoogleFonts.inter(
                              color: AppColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (snap.hasError)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Could not load wishlist',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else if (snap.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 1.5,
                    ),
                  ),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite_border_rounded,
                          color: AppColors.textSecondary,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your wishlist is empty',
                          style: GoogleFonts.playfairDisplay(
                            color: AppColors.textSecondary,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap ♥ on any restaurant to save it here',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        i == items.length - 1 ? 100 : 12,
                      ),
                      child: WishlistCard(
                        restaurant: items[i],
                        rank: i + 1,
                        onRemove: () => _remove(items[i]),
                      ),
                    ),
                    childCount: items.length,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
