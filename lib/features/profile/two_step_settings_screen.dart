import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/cs_spacing.dart';
import '../../core/theme/cs_typography.dart';
import '../../core/widgets/cs_primary_button.dart';
import '../../core/widgets/cs_text_field.dart';
import '../../core/widgets/editorial_back_button.dart';
import '../../data/repositories/two_step_repository.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _addedOn(DateTime d) {
  final local = d.toLocal();
  return 'Added ${local.day} ${_months[local.month - 1]} ${local.year}';
}

/// Profile → Privacy → Two-step sign-in. Off: what it is and a button to
/// turn it on. On: each linked authenticator app, a way to add a backup,
/// and Remove, which asks for a code first — removing the last one turns
/// two-step sign-in off.
class TwoStepSettingsScreen extends StatefulWidget {
  final TwoStepRepository? repository;

  /// Opens the otpauth:// link. Overridable for tests.
  final Future<bool> Function(Uri uri)? openLink;

  const TwoStepSettingsScreen({super.key, this.repository, this.openLink});

  @override
  State<TwoStepSettingsScreen> createState() => _TwoStepSettingsScreenState();
}

class _TwoStepSettingsScreenState extends State<TwoStepSettingsScreen> {
  late final _repo =
      widget.repository ?? TwoStepRepository(Supabase.instance.client.auth);
  List<TwoStepFactor>? _factors;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _factors = null;
      _loadError = false;
    });
    try {
      final factors = await _repo.factors();
      if (!mounted) return;
      setState(() => _factors = factors);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = true);
    }
  }

  Future<void> _add() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TwoStepSetupScreen(
          repository: _repo,
          openLink: widget.openLink,
          isBackup: (_factors ?? []).isNotEmpty,
        ),
      ),
    );
    if (added != true || !mounted) return;
    final wasOff = (_factors ?? []).isEmpty;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasOff ? 'Two-step sign-in is on.' : 'Backup authenticator added.',
        ),
      ),
    );
  }

  Future<void> _remove(TwoStepFactor factor) async {
    final isLast = (_factors ?? []).length == 1;
    final removed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _RemoveDialog(repository: _repo, factor: factor, isLast: isLast),
    );
    if (removed != true || !mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isLast ? 'Two-step sign-in is off.' : 'Authenticator removed.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          CsSpacing.pageHorizontal,
          CsSpacing.sm,
          CsSpacing.pageHorizontal,
          CsSpacing.section,
        ),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: EditorialBackButton(),
          ),
          const SizedBox(height: CsSpacing.lg),
          Text(
            'Two-step sign-in',
            style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
          ),
          const SizedBox(height: CsSpacing.xl),
          if (_factors == null && !_loadError)
            const Padding(
              padding: EdgeInsets.only(top: CsSpacing.section),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.textOnDark,
                  strokeWidth: 1.5,
                ),
              ),
            )
          else if (_loadError)
            _LoadError(onRetry: _load)
          else if (_factors!.isEmpty)
            ..._off()
          else
            ..._on(_factors!),
        ],
      ),
    ),
  );

  List<Widget> _off() => [
    _status(on: false),
    const SizedBox(height: CsSpacing.lg),
    _body(
      'After your password, Mantelier also asks for a six-digit code from '
      'an authenticator app on your phone. Someone who learns your '
      'password still can\'t sign in.',
    ),
    const SizedBox(height: CsSpacing.base),
    _body(
      'On iPhone, the Passwords app works as your authenticator and fills '
      'the code in for you. Google Authenticator and 1Password work too.',
    ),
    const SizedBox(height: CsSpacing.xl),
    CsPrimaryButton(label: 'Turn on', onTap: _add),
  ];

  List<Widget> _on(List<TwoStepFactor> factors) => [
    _status(on: true),
    const SizedBox(height: CsSpacing.lg),
    _body(
      'When you sign in, Mantelier asks for a code from one of these '
      'authenticator apps.',
    ),
    const SizedBox(height: CsSpacing.xl),
    Text(
      'AUTHENTICATORS',
      style: CsTypography.eyebrow.copyWith(color: AppColors.secondaryOnDark),
    ),
    const SizedBox(height: CsSpacing.sm),
    for (final f in factors)
      Container(
        padding: const EdgeInsets.symmetric(vertical: CsSpacing.md),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.subtleBorderDark)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.phonelink_lock_outlined,
              color: AppColors.secondaryOnDark,
              size: 20,
            ),
            const SizedBox(width: CsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.name ?? 'Authenticator',
                    style: CsTypography.bodyMedium.copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                  Text(
                    _addedOn(f.addedAt),
                    style: CsTypography.metadata.copyWith(
                      color: AppColors.secondaryOnDark,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _remove(f),
              child: Text(
                'Remove',
                style: CsTypography.metadata.copyWith(color: AppColors.ivory),
              ),
            ),
          ],
        ),
      ),
    const SizedBox(height: CsSpacing.xl),
    if (factors.length == 1) ...[
      _body(
        'Add a second authenticator as a backup — on another device or in '
        'another app — so losing your phone doesn\'t lock you out.',
      ),
      const SizedBox(height: CsSpacing.base),
    ],
    CsPrimaryButton(label: 'Add a backup authenticator', onTap: _add),
  ];

  Widget _status({required bool on}) => Row(
    children: [
      Icon(
        on ? Icons.verified_user_outlined : Icons.shield_outlined,
        color: on ? AppColors.ivory : AppColors.secondaryOnDark,
        size: 20,
      ),
      const SizedBox(width: CsSpacing.sm),
      Text(
        on ? 'On' : 'Off',
        style: CsTypography.bodyMedium.copyWith(
          color: on ? AppColors.ivory : AppColors.secondaryOnDark,
        ),
      ),
    ],
  );

  Widget _body(String text) => Text(
    text,
    style: CsTypography.body.copyWith(
      color: AppColors.secondaryOnDark,
      height: 1.5,
    ),
  );
}

/// Links one authenticator: open it in the authenticator app (or type the
/// key), then confirm with its first code. Pops true when confirmed.
class TwoStepSetupScreen extends StatefulWidget {
  final TwoStepRepository repository;
  final Future<bool> Function(Uri uri)? openLink;
  final bool isBackup;

  const TwoStepSetupScreen({
    super.key,
    required this.repository,
    this.openLink,
    this.isBackup = false,
  });

  @override
  State<TwoStepSetupScreen> createState() => _TwoStepSetupScreenState();
}

class _TwoStepSetupScreenState extends State<TwoStepSetupScreen> {
  final _codeCtrl = TextEditingController();
  TwoStepEnrollment? _enrollment;
  bool _startError = false;
  bool _confirming = false;
  String? _error;
  String? _linkNote;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _enrollment = null;
      _startError = false;
    });
    try {
      final enrollment = await widget.repository.start();
      if (!mounted) return;
      setState(() => _enrollment = enrollment);
    } catch (_) {
      if (!mounted) return;
      setState(() => _startError = true);
    }
  }

  Future<void> _openInAuthenticator() async {
    final uri = Uri.parse(_enrollment!.uri);
    bool opened;
    try {
      opened =
          await (widget.openLink ??
              (u) => launchUrl(u, mode: LaunchMode.externalApplication))(uri);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(
      () => _linkNote = opened
          ? null
          : 'No authenticator app opened. Copy the key below into one instead.',
    );
  }

  Future<void> _copyKey() async {
    await Clipboard.setData(ClipboardData(text: _enrollment!.secret));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Key copied.')));
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    if (twoStepDigits(_codeCtrl.text).length != 6) {
      setState(() => _error = 'Enter the six-digit code.');
      return;
    }
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      await widget.repository.confirm(_enrollment!.factorId, _codeCtrl.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _confirming = false;
        _error = "That code didn't match. Try the newest one.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrollment = _enrollment;
    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            CsSpacing.pageHorizontal,
            CsSpacing.sm,
            CsSpacing.pageHorizontal,
            CsSpacing.section,
          ),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: EditorialBackButton(),
            ),
            const SizedBox(height: CsSpacing.lg),
            Text(
              widget.isBackup ? 'Add a backup' : 'Turn on two-step sign-in',
              style: CsTypography.screenTitle.copyWith(color: AppColors.ivory),
            ),
            const SizedBox(height: CsSpacing.xl),
            if (_startError)
              _LoadError(onRetry: _start)
            else if (enrollment == null)
              const Padding(
                padding: EdgeInsets.only(top: CsSpacing.section),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.textOnDark,
                    strokeWidth: 1.5,
                  ),
                ),
              )
            else ...[
              _step('1', 'Add Mantelier to your authenticator app'),
              const SizedBox(height: CsSpacing.md),
              CsPrimaryButton(
                label: 'Open in authenticator app',
                icon: Icons.open_in_new_rounded,
                onTap: _openInAuthenticator,
              ),
              if (_linkNote != null) ...[
                const SizedBox(height: CsSpacing.sm),
                Text(
                  _linkNote!,
                  style: CsTypography.metadata.copyWith(
                    color: AppColors.secondaryOnDark,
                  ),
                ),
              ],
              const SizedBox(height: CsSpacing.lg),
              Text(
                'Or enter this key by hand:',
                style: CsTypography.metadata.copyWith(
                  color: AppColors.secondaryOnDark,
                ),
              ),
              const SizedBox(height: CsSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      twoStepGroupedSecret(enrollment.secret),
                      style: CsTypography.bodyMedium.copyWith(
                        color: AppColors.textOnDark,
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _copyKey,
                    child: Text(
                      'Copy',
                      style: CsTypography.metadata.copyWith(
                        color: AppColors.ivory,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CsSpacing.xl),
              _step('2', 'Enter the code it shows'),
              const SizedBox(height: CsSpacing.md),
              CsTextField(
                label: 'Code',
                controller: _codeCtrl,
                hintText: '123 456',
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _confirm(),
                inputFormatters: twoStepCodeFormatters,
                onChanged: (v) {
                  if (v.length == 6) _confirm();
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: CsSpacing.sm),
                Text(
                  _error!,
                  style: CsTypography.metadata.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: CsSpacing.xl),
              CsPrimaryButton(
                label: 'Confirm',
                onTap: _confirm,
                loading: _confirming,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _step(String number, String text) => Row(
    children: [
      Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.secondaryOnDark),
        ),
        child: Text(
          number,
          style: CsTypography.metadata.copyWith(color: AppColors.textOnDark),
        ),
      ),
      const SizedBox(width: CsSpacing.md),
      Expanded(
        child: Text(
          text,
          style: CsTypography.bodyMedium.copyWith(color: AppColors.textOnDark),
        ),
      ),
    ],
  );
}

/// Asks for a code from any linked authenticator, then removes [factor].
/// Pops true once it's gone.
class _RemoveDialog extends StatefulWidget {
  final TwoStepRepository repository;
  final TwoStepFactor factor;
  final bool isLast;

  const _RemoveDialog({
    required this.repository,
    required this.factor,
    required this.isLast,
  });

  @override
  State<_RemoveDialog> createState() => _RemoveDialogState();
}

class _RemoveDialogState extends State<_RemoveDialog> {
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (twoStepDigits(_codeCtrl.text).length != 6) {
      setState(() => _error = 'Enter the six-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.remove(widget.factor.id, _codeCtrl.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "That code didn't match. Try the newest one.";
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.brandGreenLight,
    title: Text(
      widget.isLast
          ? 'Turn off two-step sign-in?'
          : 'Remove this authenticator?',
      style: CsTypography.placeTitle.copyWith(color: AppColors.textOnDark),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isLast
              ? 'Your password alone will sign you in again. Enter a code '
                    'from your authenticator app to confirm.'
              : 'Enter a code from any of your authenticator apps to confirm.',
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
        const SizedBox(height: CsSpacing.base),
        CsTextField(
          label: 'Code',
          controller: _codeCtrl,
          hintText: '123 456',
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          inputFormatters: twoStepCodeFormatters,
          onChanged: (v) {
            if (v.length == 6) _submit();
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: CsSpacing.sm),
          Text(
            _error!,
            style: CsTypography.metadata.copyWith(color: AppColors.error),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context, false),
        child: Text(
          'Cancel',
          style: CsTypography.bodyMedium.copyWith(
            color: AppColors.secondaryOnDark,
          ),
        ),
      ),
      TextButton(
        onPressed: _busy ? null : _submit,
        child: Text(
          widget.isLast ? 'Turn off' : 'Remove',
          style: CsTypography.bodyMedium.copyWith(color: AppColors.error),
        ),
      ),
    ],
  );
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;
  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: CsSpacing.xl),
    child: Column(
      children: [
        Text(
          'Could not load two-step sign-in',
          style: CsTypography.body.copyWith(color: AppColors.secondaryOnDark),
        ),
        const SizedBox(height: CsSpacing.md),
        TextButton(
          onPressed: onRetry,
          child: Text(
            'Retry',
            style: CsTypography.bodyMedium.copyWith(color: AppColors.ivory),
          ),
        ),
      ],
    ),
  );
}
