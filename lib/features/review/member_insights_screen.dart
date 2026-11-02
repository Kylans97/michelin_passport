import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../../models/venue_country.dart';

/// One group in the member insights: a dimension ('total', 'country',
/// 'age'), its bucket, and the counts — null when fewer than 5, so no
/// member can be picked out (admin_get_member_insights, 20261101210000).
class MemberInsight {
  final String dimension;
  final String bucket;
  final int? members;
  final int? newLast30Days;

  const MemberInsight({
    required this.dimension,
    required this.bucket,
    this.members,
    this.newLast30Days,
  });

  factory MemberInsight.fromJson(Map<String, dynamic> json) => MemberInsight(
    dimension: json['dimension'] as String,
    bucket: json['bucket'] as String,
    members: json['members'] as int?,
    newLast30Days: json['new_last_30_days'] as int?,
  );
}

const _ageOrder = ['16-24', '25-34', '35-44', '45-54', '55-64', '65+', 'none'];

/// Members by country and by age group, for admins: counts only, never a
/// person, and any group under 5 shows "fewer than 5" instead of a number.
/// Reached from Profile's Insights row, which only admins see. Shows where
/// Mantelier is growing and which groups it reaches.
class MemberInsightsScreen extends StatefulWidget {
  final ReviewRepository? repository;
  final Future<List<VenueCountry>> Function()? loadCountries;

  const MemberInsightsScreen({super.key, this.repository, this.loadCountries});

  @override
  State<MemberInsightsScreen> createState() => _MemberInsightsScreenState();
}

class _MemberInsightsScreenState extends State<MemberInsightsScreen> {
  late final _repo =
      widget.repository ?? ReviewRepository(Supabase.instance.client);
  late Future<(List<MemberInsight>, Map<String, VenueCountry>)> _future =
      _load();

  Future<(List<MemberInsight>, Map<String, VenueCountry>)> _load() async {
    final insights = await _repo.loadMemberInsights();
    Map<String, VenueCountry> countries = {};
    try {
      final all =
          await (widget.loadCountries ??
              () => ProfileRepository(
                Supabase.instance.client,
              ).getAllCountries())();
      countries = {for (final c in all) c.code: c};
    } catch (_) {
      // Codes stand in for names.
    }
    return (insights, countries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Insights',
          style: CsTypography.placeTitle.copyWith(
            color: AppColors.forestGreen,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.warmWhite,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
      ),
      body: RefreshIndicator(
        color: AppColors.forestGreen,
        onRefresh: () async {
          final next = _load();
          setState(() => _future = next);
          await next;
        },
        child: FutureBuilder<(List<MemberInsight>, Map<String, VenueCountry>)>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.forestGreen,
                  strokeWidth: 1.5,
                ),
              );
            }
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(CsSpacing.xl),
                children: [
                  Text(
                    'Could not load the insights. Pull down to try again.',
                    style: CsTypography.body.copyWith(color: AppColors.taupe),
                  ),
                ],
              );
            }
            final (rows, countries) = snap.data!;
            final total = rows.where((r) => r.dimension == 'total').firstOrNull;
            final byCountry =
                rows.where((r) => r.dimension == 'country').toList()
                  ..sort((a, b) {
                    final byCount = (b.members ?? 0).compareTo(a.members ?? 0);
                    if (byCount != 0) return byCount;
                    if (a.bucket == 'none') return 1;
                    if (b.bucket == 'none') return -1;
                    return _countryName(
                      a.bucket,
                      countries,
                    ).compareTo(_countryName(b.bucket, countries));
                  });
            final byAge = rows.where((r) => r.dimension == 'age').toList()
              ..sort(
                (a, b) => _ageOrder
                    .indexOf(a.bucket)
                    .compareTo(_ageOrder.indexOf(b.bucket)),
              );
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                CsSpacing.pageHorizontal,
                CsSpacing.md,
                CsSpacing.pageHorizontal,
                CsSpacing.section,
              ),
              children: [
                Text(
                  'Counts only, never a person. A group of fewer than 5 shows '
                  'no number, so no one can be picked out.',
                  style: CsTypography.metadata.copyWith(color: AppColors.taupe),
                ),
                const SizedBox(height: CsSpacing.lg),
                _Headline(
                  members: total?.members ?? 0,
                  newLast30Days: total?.newLast30Days ?? 0,
                ),
                _section('BY COUNTRY'),
                for (final r in byCountry)
                  _Row(label: _countryLabel(r.bucket, countries), insight: r),
                _section('BY AGE'),
                for (final r in byAge)
                  _Row(
                    label: r.bucket == 'none' ? 'Not given' : r.bucket,
                    insight: r,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _countryName(
    String code,
    Map<String, VenueCountry> countries,
  ) => countries[code]?.name ?? code;

  static String _countryLabel(
    String code,
    Map<String, VenueCountry> countries,
  ) {
    if (code == 'none') return 'Not given';
    final c = countries[code];
    if (c == null) return code;
    return c.flag.isEmpty ? c.name : '${c.flag}  ${c.name}';
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: CsSpacing.xl, bottom: CsSpacing.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: CsTypography.eyebrow.copyWith(color: AppColors.taupe),
          ),
        ),
        Text(
          'NEW IN 30 DAYS',
          style: CsTypography.eyebrow.copyWith(
            color: AppColors.taupe,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );
}

class _Headline extends StatelessWidget {
  final int members;
  final int newLast30Days;

  const _Headline({required this.members, required this.newLast30Days});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        '$members',
        style: CsTypography.largeMetric.copyWith(color: AppColors.forestGreen),
      ),
      const SizedBox(width: CsSpacing.sm),
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          '${members == 1 ? 'member' : 'members'} · $newLast30Days new in 30 days',
          style: CsTypography.body.copyWith(color: AppColors.taupe),
        ),
      ),
    ],
  );
}

class _Row extends StatelessWidget {
  final String label;
  final MemberInsight insight;

  const _Row({required this.label, required this.insight});

  static String _count(int? n) => n == null ? 'fewer than 5' : '$n';

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: CsSpacing.sm),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: CsTypography.body.copyWith(color: AppColors.forestGreen),
          ),
        ),
        Text(
          _count(insight.members),
          style: CsTypography.body.copyWith(
            color: insight.members == null
                ? AppColors.taupe
                : AppColors.forestGreen,
          ),
        ),
        SizedBox(
          width: 104,
          child: Text(
            _count(insight.newLast30Days),
            textAlign: TextAlign.right,
            style: CsTypography.metadata.copyWith(color: AppColors.taupe),
          ),
        ),
      ],
    ),
  );
}
