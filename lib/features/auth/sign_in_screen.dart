import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/session_controller.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/ui.dart';
import 'auth_scaffold.dart';

/// Qatar mobile number in international form: "5512 3456" → "+97455123456".
String normalizePhone(String raw) {
  var p = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  if (p.isEmpty) return p;
  if (p.startsWith('00')) p = '+${p.substring(2)}';
  if (!p.startsWith('+')) p = '+974$p';
  return p;
}

/// Phone field with the Qatar prefix, used by sign-in and registration.
class PhoneField extends StatelessWidget {
  const PhoneField({super.key, required this.controller, this.error, this.onSubmitted, this.autofocus = false});
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmitted,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]'))],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: .5),
          decoration: InputDecoration(
            hintText: '5X XXX XXX',
            prefixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('🇶🇦', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Text('+974', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(width: 10),
                Container(width: 1, height: 22, color: Theme.of(context).dividerColor),
              ]),
            ),
            errorText: error,
          ),
        ),
      );
}

/// One sign-in for everybody with an ERP login: agency, agent and partner staff, candidates and customers sign in
/// with email + password. The ERP decides the company and the role from them; nothing is chosen on this screen.
/// New customers register with their mobile number; a code to the mobile number is kept as a second way in.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _byPhone = false;
  final _phone = TextEditingController();
  final _invite = TextEditingController();
  final _emailCtl = TextEditingController();
  final _password = TextEditingController();
  final _mfa = TextEditingController();
  bool _hasInvite = false;
  bool _showPassword = false;
  bool _needMfa = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notice = ref.read(sessionProvider).notice;
      if (notice != null && mounted) Toast.info(context, notice);
    });
  }

  @override
  void dispose() {
    for (final c in [_phone, _invite, _emailCtl, _password, _mfa]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() => _error = null);
    final phone = normalizePhone(_phone.text);
    try {
      final (delivery, ttl) = await ref.read(sessionProvider.notifier).requestOtp(phone);
      if (!mounted) return;
      context.push('/otp', extra: {'phone': phone, 'invite': _hasInvite ? _invite.text.trim() : '', 'delivery': delivery, 'ttl': ttl});
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _signIn() async {
    setState(() => _error = null);
    try {
      await ref.read(sessionProvider.notifier).login(email: _emailCtl.text, password: _password.text, mfaCode: _needMfa ? _mfa.text : null);
      _password.clear();
      _mfa.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'mfa_required' || e.code == 'mfa_invalid') {
          _needMfa = true;
          _error = e.code == 'mfa_invalid' ? e : null;
        } else {
          _error = e;
        }
      });
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final boot = ref.watch(sessionProvider.select((s) => s.boot));
    return AuthScaffold(
      title: context.tr(_byPhone ? 'auth.phone_title' : 'auth.title'),
      subtitle: _byPhone
          ? context.tr('auth.phone_hint')
          : (boot?.companyName != null ? context.tr('auth.welcome_to', {'company': boot!.companyName}) : context.tr('auth.subtitle')),
      child: AutofillGroup(
        child: AnimatedSwitcher(
          duration: MotionScope.duration(context, const Duration(milliseconds: 220)),
          child: _byPhone ? _phoneForm() : _emailForm(),
        ),
      ),
    );
  }

  Widget _errorBanner() {
    final e = _error;
    if (e == null || (e.fields.isNotEmpty && e.code == 'validation_failed')) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Palette.danger.withValues(alpha: .07), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(e.isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded, color: Palette.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(e.message, style: const TextStyle(color: Palette.danger, fontWeight: FontWeight.w500))),
        ]),
      ),
    );
  }

  Widget _label(String key) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2, right: 2),
        child: Text(context.tr(key), style: Theme.of(context).textTheme.labelLarge),
      );

  Widget _switchLink({required IconData icon, required String key, required VoidCallback onTap}) => Center(
        child: TextButton.icon(
          onPressed: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          icon: Icon(icon, size: 18),
          label: Text(context.tr(key)),
        ),
      );

  Widget _emailForm() => Column(key: const ValueKey('email'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _errorBanner(),
        _label('auth.email'),
        TextField(
          controller: _emailCtl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          textInputAction: TextInputAction.next,
          autocorrect: false,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(hintText: 'name@example.com', prefixIcon: const Icon(Icons.alternate_email_rounded), errorText: _error?.fieldError('email')),
        ),
        const SizedBox(height: 16),
        _label('auth.password'),
        TextField(
          controller: _password,
          obscureText: !_showPassword,
          autofillHints: const [AutofillHints.password],
          textInputAction: _needMfa ? TextInputAction.next : TextInputAction.done,
          onSubmitted: (_) => _needMfa ? null : _signIn(),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            errorText: _error?.fieldError('password'),
            suffixIcon: IconButton(
              tooltip: context.tr(_showPassword ? 'auth.hide_password' : 'auth.show_password'),
              icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        if (_needMfa) ...[
          const SizedBox(height: 18),
          Reveal(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Palette.maroon.withValues(alpha: .05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Palette.maroon.withValues(alpha: .15))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Icon(Icons.verified_user_outlined, color: Palette.maroon, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.tr('auth.mfa_title'), style: Theme.of(context).textTheme.titleSmall)),
                ]),
                const SizedBox(height: 4),
                Text(context.tr('auth.mfa_hint'), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _mfa,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, letterSpacing: 10, fontWeight: FontWeight.w700),
                    maxLength: 8,
                    decoration: InputDecoration(counterText: '', hintText: '000000', errorText: _error?.code == 'mfa_invalid' ? _error!.message : null),
                    onSubmitted: (_) => _signIn(),
                  ),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 22),
        BusyButton(label: context.tr('auth.sign_in'), onPressed: _signIn),
        const SizedBox(height: 6),
        _switchLink(
          icon: Icons.sms_outlined,
          key: 'auth.use_phone_code',
          onTap: () => setState(() {
            _byPhone = true;
            _error = null;
          }),
        ),
        const SizedBox(height: 14),
        const _RegisterCard(),
      ]);

  Widget _phoneForm() => Column(key: const ValueKey('phone'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _errorBanner(),
        _label('auth.phone'),
        PhoneField(controller: _phone, error: _error?.fieldError('phone'), onSubmitted: (_) => _sendCode()),
        const SizedBox(height: 6),
        Text(context.tr('auth.phone_helper'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
            onPressed: () => setState(() => _hasInvite = !_hasInvite),
            icon: Icon(_hasInvite ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded, size: 18),
            label: Text(context.tr('auth.have_invite')),
          ),
        ),
        if (_hasInvite) ...[
          const SizedBox(height: 4),
          Reveal(
            child: TextField(
              controller: _invite,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(hintText: context.tr('auth.invite_code'), prefixIcon: const Icon(Icons.confirmation_number_outlined)),
            ),
          ),
        ],
        const SizedBox(height: 20),
        BusyButton(label: context.tr('auth.send_code'), onPressed: _sendCode),
        const SizedBox(height: 6),
        _switchLink(
          icon: Icons.alternate_email_rounded,
          key: 'auth.use_email',
          onTap: () => setState(() {
            _byPhone = false;
            _error = null;
          }),
        ),
        const SizedBox(height: 14),
        const _RegisterCard(),
      ]);
}

/// "New customer? Create your account" — the entry to registration, shown under the phone form.
class _RegisterCard extends StatelessWidget {
  const _RegisterCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Palette.gold.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/register'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Palette.gold.withValues(alpha: .35))),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(gradient: Palette.goldGradient, shape: BoxShape.circle),
              child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('auth.new_customer'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(context.tr('auth.create_account_body'), style: theme.textTheme.bodySmall),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Palette.maroon, borderRadius: BorderRadius.circular(99)),
              child: Text(context.tr('auth.create_account'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ),
          ]),
        ),
      ),
    );
  }
}
