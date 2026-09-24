import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_masthead_logo.dart';
import '../passport_booklet_data.dart';

// Cormorant Garamond falls back to oldstyle figures (varying
// height/baseline, designed to blend into lowercase text) unless this
// feature is explicitly enabled — confirmed in this round's own preview
// harness screenshot, where MEMBER NO. and the ENTRIES/COUNTRIES/STARS
// numerals rendered with visibly uneven digit heights. Same fix
// CsTypography's own `_liningFigures` already applies to every one of its
// Cormorant roles; this page hardcodes its own literal spec sizes rather
// than reusing those roles (see PassportStampStatsRow's own precedent for
// why), so the font feature has to be repeated here, top-level so every
// private widget class below can use it.
const _liningFigures = [FontFeature.enable('lnum')];

/// The Passport booklet's first page — a bound passenger-data spread, not
/// a stamp page: photo, holder fields, the ENTRIES/COUNTRIES/STARS trio,
/// country chips, and a machine-readable-zone-style footer. Same physical
/// page chrome (paper, corner radii, spine shadow) [PassportPage] (the
/// stamp page, Round 2) uses, but its OWN guilloché motif — fine diagonal
/// lines rather than concentric rings, matching the design spec's explicit
/// "diagonale guilloche-lijnen" for this one page only.
class PassportDataPage extends StatelessWidget {
  final PassportVolume volume;
  final String holderName;
  final String? avatarUrl;
  final String memberNumber;

  const PassportDataPage({
    super.key,
    required this.volume,
    required this.holderName,
    required this.avatarUrl,
    required this.memberNumber,
  });

  static const double width = 320;
  static const double height = 480;

  static const _cornerLeft = 4.0;
  static const _cornerRight = 14.0;

  String get _validLine {
    final first = volume.collectionFirstYear;
    if (volume.year != null) return '${volume.year}';
    if (first == null) return 'present';
    return '$first – present';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(_cornerLeft),
          bottomLeft: Radius.circular(_cornerLeft),
          topRight: Radius.circular(_cornerRight),
          bottomRight: Radius.circular(_cornerRight),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(_cornerLeft),
          bottomLeft: Radius.circular(_cornerLeft),
          topRight: Radius.circular(_cornerRight),
          bottomRight: Radius.circular(_cornerRight),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _DiagonalGuillochePainter()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PASSEPORT GASTRONOMIQUE',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 9 * 0.12,
                          ),
                        ),
                        CsMastheadLogo(size: 18, tint: AppColors.forestGreen),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PassportIdPhoto(
                          avatarUrl: avatarUrl,
                          displayName: holderName,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Field(
                                label: 'HOLDER · TITULAIRE',
                                value: holderName,
                                valueSize: 22,
                              ),
                              const SizedBox(height: 10),
                              _Field(label: 'MEMBER NO.', value: memberNumber),
                              const SizedBox(height: 10),
                              _Field(label: 'VALID', value: _validLine),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(height: 1, color: AppColors.hairlineOnPaper),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatColumn(
                              value: volume.entries,
                              label: 'ENTRIES',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppColors.hairlineOnPaper,
                          ),
                          Expanded(
                            child: _StatColumn(
                              value: volume.countries,
                              label: 'COUNTRIES',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppColors.hairlineOnPaper,
                          ),
                          Expanded(
                            child: _StatColumn(
                              value: volume.stars,
                              label: 'STARS',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: AppColors.hairlineOnPaper),
                    const SizedBox(height: 18),
                    Text(
                      'COUNTRIES VISITED',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 9 * 0.12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (volume.countryCodes.isEmpty)
                      Text(
                        '—',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final code in volume.countryCodes)
                            _CountryChip(code: code),
                        ],
                      ),
                    const SizedBox(height: 20),
                    _DottedLine(),
                    const SizedBox(height: 12),
                    _MrzLine(_mrzLine1(holderName)),
                    const SizedBox(height: 4),
                    _MrzLine(_mrzLine2()),
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 14,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0x33000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mrzLine1(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final surname = parts.isEmpty ? '' : parts.last;
    final given = parts.length > 1 ? parts.sublist(0, parts.length - 1).join('<') : '';
    return 'P<MNT<${surname.toUpperCase()}<<${given.toUpperCase()}'
        .replaceAll(' ', '<');
  }

  String _mrzLine2() {
    final e = volume.entries.toString().padLeft(2, '0');
    final c = volume.countries.toString().padLeft(2, '0');
    final s = volume.stars.toString().padLeft(2, '0');
    return '$memberNumber<${e}E<${c}C<${s}S<<<<<<<<';
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final double valueSize;
  const _Field({required this.label, required this.value, this.valueSize = 17});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 8.5 * 0.1,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.cormorantGaramond(
          color: AppColors.textPrimary,
          fontSize: valueSize,
          fontWeight: FontWeight.w600,
          fontFeatures: _liningFigures,
        ),
      ),
    ],
  );
}

class _StatColumn extends StatelessWidget {
  final int value;
  final String label;
  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value.toString().padLeft(2, '0'),
        style: GoogleFonts.cormorantGaramond(
          color: AppColors.forestGreen,
          fontSize: 44,
          fontWeight: FontWeight.w600,
          height: 1,
          fontFeatures: _liningFigures,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 9 * 0.1,
        ),
      ),
    ],
  );
}

class _CountryChip extends StatelessWidget {
  final String code;
  const _CountryChip({required this.code});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.forestGreen, width: 1),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      code.toUpperCase(),
      style: GoogleFonts.inter(
        color: AppColors.forestGreen,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 12 * 0.12,
      ),
    ),
  );
}

class _PassportIdPhoto extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  const _PassportIdPhoto({required this.avatarUrl, required this.displayName});

  static const _width = 92.0;
  static const _height = 118.0;

  String get _initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(s[0]))
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(
        color: AppColors.forestGreen,
        border: Border.all(color: AppColors.forestGreen, width: 1),
        borderRadius: BorderRadius.circular(3),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? Center(
              child: Text(
                _initials,
                style: GoogleFonts.cormorantGaramond(
                  color: AppColors.textOnDark,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Text(
                  _initials,
                  style: GoogleFonts.cormorantGaramond(
                    color: AppColors.textOnDark,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
    );
  }
}

class _DottedLine extends StatelessWidget {
  const _DottedLine();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(double.infinity, 1),
    painter: _DottedLinePainter(),
  );
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    const dash = 3.0;
    const gap = 3.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) => false;
}

class _MrzLine extends StatelessWidget {
  final String text;
  const _MrzLine(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: GoogleFonts.robotoMono(
      color: AppColors.textSecondary,
      fontSize: 11,
      letterSpacing: 11 * 0.18,
    ),
  );
}

/// Fine diagonal hairlines at gold ~7% — the data page's own guilloché
/// motif, distinct from the stamp pages' concentric rings (see
/// PassportPage's own [_GuillochePainter]) per the design spec's explicit
/// "diagonale guilloche-lijnen" wording for this one page.
class _DiagonalGuillochePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    const spacing = 10.0;
    final diagonal = size.width + size.height;
    for (var offset = -size.height; offset < diagonal; offset += spacing) {
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiagonalGuillochePainter oldDelegate) => false;
}
