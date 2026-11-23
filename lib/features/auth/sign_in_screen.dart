import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/session_controller.dart';
import '../../core/config/env.dart';
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

/// One sign-in screen without role cards: customers and workers use their phone, staff their work email.
/// What the person can open afterwards is decided by the ERP, not by anything chosen here.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _email = false;
  final _phone = TextEditingController();
  final _invite = TextEditingController();
  final _emailCtl = TextEditingController();
  final _password = TextEditingController();
  final _mfa = TextEditingController();
  final _company = TextEditingController(text: Env.companyCode);
  bool _hasInvite = false;
  bool _showPassword = false;
  bool _needMfa = false;
  bool _needCompany = false; // only when the ERP cannot tell the company from the address or the email
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
    for (final c in [_phone, _invite, _emailCtl, _password, _mfa, _company]) {
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

  Future<void> _staff() async {
    setState(() => _error = null);
    try {
      await ref.read(sessionProvider.notifier).staffLogin(company: _company.text, email: _emailCtl.text, password: _password.text, mfaCode: _needMfa ? _mfa.text : null);
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
          if (e.fieldError('company') != null) _needCompany = true;
        }
      });
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final boot = ref.watch(sessionProvider.select((s) => s.boot));
    return AuthScaffold(
      title: context.tr('auth.title'),
      subtitle: boot?.companyName != null ? context.tr('auth.welcome_to', {'company': boot!.companyName}) : context.tr('auth.subtitle'),
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Tabs(email: _email, onChanged: (v) => setState(() {
                _email = v;
                _error = null;
              })),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: MotionScope.duration(context, const Duration(milliseconds: 220)),
            child: _email ? _emailForm() : _phoneForm(),
          ),
        ]),
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
        const SizedBox(height: 28),
        Row(children: [
          const Expanded(child: Divider()),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(context.tr('auth.new_customer'), style: Theme.of(context).textTheme.bodySmall)),
          const Expanded(child: Divider()),
        ]),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.push('/register'),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: Text(context.tr('auth.create_account')),
        ),
      ]);

  Widget _emailForm() => Column(key: const ValueKey('email'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _errorBanner(),
        if (_needCompany) ...[
          _label('auth.company_code'),
          TextField(
            controller: _company,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.apartment_outlined), errorText: _error?.fieldError('company')),
          ),
          const SizedBox(height: 16),
        ],
        _label('auth.email'),
        TextField(
          controller: _emailCtl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          textInputAction: TextInputAction.next,
          autocorrect: false,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(hintText: 'name@company.com', prefixIcon: const Icon(Icons.alternate_email_rounded), errorText: _error?.fieldError('email')),
        ),
        const SizedBox(height: 16),
        _label('auth.password'),
        TextField(
          controller: _password,
          obscureText: !_showPassword,
          autofillHints: const [AutofillHints.password],
          textInputAction: _needMfa ? TextInputAction.next : TextInputAction.done,
          onSubmitted: (_) => _needMfa ? null : _staff(),
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
                    onSubmitted: (_) => _staff(),
                  ),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 22),
        BusyButton(label: context.tr('auth.sign_in'), onPressed: _staff),
      ]);
}

/// Two-option switch: phone (customers, workers) or work email (staff).
class _Tabs extends StatelessWidget {
  const _Tabs({required this.email, required this.onChanged});
  final bool email;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget tab(bool value, IconData icon, String label) {
      final on = email == value;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(value);
            },
            child: AnimatedContainer(
              duration: MotionScope.duration(context, const Duration(milliseconds: 200)),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: on ? (dark ? Palette.nightCard : Colors.white) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: on ? [BoxShadow(color: Palette.ink.withValues(alpha: .08), blurRadius: 10, offset: const Offset(0, 2))] : const [],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 18, color: on ? Palette.maroon : Theme.of(context).hintColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? Theme.of(context).colorScheme.onSurface : Theme.of(context).hintColor)),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: dark ? Colors.white10 : const Color(0xFFECE8E3), borderRadius: BorderRadius.circular(15)),
      child: Row(children: [
        tab(false, Icons.smartphone_rounded, context.tr('auth.method_phone')),
        tab(true, Icons.badge_outlined, context.tr('auth.method_email')),
      ]),
    );
  }
}
