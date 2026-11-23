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

/// One sign-in screen. There is no role picker: staff use their work email, customers and workers their phone.
/// What the person can open afterwards is decided by the ERP, not by anything chosen here.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _phone = false;
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _mfa = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _invite = TextEditingController();
  bool _showPassword = false;
  bool _needMfa = false;
  bool _hasInvite = false;
  bool _editCompany = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    final s = ref.read(sessionProvider);
    _company.text = s.company.isNotEmpty ? s.company : Env.companyCode;
    _editCompany = _company.text.isEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notice = ref.read(sessionProvider).notice;
      if (notice != null && mounted) Toast.info(context, notice);
    });
  }

  @override
  void dispose() {
    for (final c in [_company, _email, _password, _mfa, _phoneCtl, _invite]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _staff() async {
    setState(() => _error = null);
    try {
      await ref.read(sessionProvider.notifier).staffLogin(company: _company.text, email: _email.text, password: _password.text, mfaCode: _needMfa ? _mfa.text : null);
      _password.clear();
      _mfa.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'mfa_required' || e.code == 'mfa_invalid') {
        setState(() {
          _needMfa = true;
          _error = e.code == 'mfa_invalid' ? e : null;
        });
        HapticFeedback.mediumImpact();
        return;
      }
      setState(() => _error = e);
      HapticFeedback.heavyImpact();
    }
  }

  String get _normalizedPhone {
    var p = _phoneCtl.text.replaceAll(RegExp(r'[\s\-()]'), '');
    if (p.isEmpty) return p;
    if (p.startsWith('00')) p = '+${p.substring(2)}';
    if (!p.startsWith('+')) p = '+974$p';
    return p;
  }

  Future<void> _sendCode() async {
    setState(() => _error = null);
    final phone = _normalizedPhone;
    try {
      final (delivery, ttl) = await ref.read(sessionProvider.notifier).requestOtp(phone);
      if (!mounted) return;
      context.push('/otp', extra: {'phone': phone, 'invite': _hasInvite ? _invite.text.trim() : '', 'delivery': delivery, 'ttl': ttl});
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boot = ref.watch(sessionProvider.select((s) => s.boot));
    return AuthScaffold(
      title: context.tr(boot?.companyName != null ? 'auth.welcome_to' : 'auth.welcome', {'company': boot?.companyName}),
      subtitle: context.tr(_phone ? 'auth.phone_hint' : 'auth.email_hint'),
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _MethodSwitch(phone: _phone, onChanged: (v) => setState(() {
                _phone = v;
                _error = null;
              })),
          const SizedBox(height: 18),
          AnimatedSize(
            duration: MotionScope.duration(context, const Duration(milliseconds: 260)),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _phone ? _phoneForm() : _emailForm(),
          ),
        ]),
      ),
    );
  }

  Widget _errorBanner() {
    if (_error == null || (_error!.fields.isNotEmpty && _error!.code == 'validation_failed')) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Palette.danger.withValues(alpha: .08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Palette.danger.withValues(alpha: .25))),
        child: Row(children: [
          Icon(_error!.isOffline ? Icons.wifi_off_rounded : Icons.error_rounded, color: Palette.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(_error!.message, style: const TextStyle(color: Palette.danger, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }

  Widget _emailForm() => Column(key: const ValueKey('email'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _errorBanner(),
        if (_editCompany)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _company,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: context.tr('auth.company_code'), prefixIcon: const Icon(Icons.apartment_rounded), errorText: _error?.fieldError('company')),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              const Icon(Icons.apartment_rounded, size: 18, color: Palette.maroon),
              const SizedBox(width: 8),
              Expanded(child: Text(context.tr('auth.company_is', {'code': _company.text}), style: const TextStyle(fontWeight: FontWeight.w600))),
              TextButton(onPressed: () => setState(() => _editCompany = true), child: Text(context.tr('change'))),
            ]),
          ),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          textInputAction: TextInputAction.next,
          autocorrect: false,
          decoration: InputDecoration(labelText: context.tr('auth.email'), prefixIcon: const Icon(Icons.alternate_email_rounded), errorText: _error?.fieldError('email')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: !_showPassword,
          autofillHints: const [AutofillHints.password],
          textInputAction: _needMfa ? TextInputAction.next : TextInputAction.done,
          onSubmitted: (_) => _needMfa ? null : _staff(),
          decoration: InputDecoration(
            labelText: context.tr('auth.password'),
            prefixIcon: const Icon(Icons.lock_rounded),
            errorText: _error?.fieldError('password'),
            suffixIcon: IconButton(
              tooltip: context.tr(_showPassword ? 'auth.hide_password' : 'auth.show_password'),
              icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        if (_needMfa) ...[
          const SizedBox(height: 16),
          Reveal(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Palette.gold.withValues(alpha: .12), borderRadius: BorderRadius.circular(16), border: Border.all(color: Palette.gold.withValues(alpha: .4))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Icon(Icons.shield_rounded, color: Palette.maroon),
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.tr('auth.mfa_title'), style: const TextStyle(fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 4),
                Text(context.tr('auth.mfa_hint'), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                const SizedBox(height: 10),
                TextField(
                  controller: _mfa,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w800),
                  maxLength: 8,
                  decoration: InputDecoration(counterText: '', hintText: '••••••', errorText: _error?.code == 'mfa_invalid' ? _error!.message : null),
                  onSubmitted: (_) => _staff(),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 20),
        BusyButton(label: context.tr('auth.sign_in'), icon: Icons.login_rounded, onPressed: _staff),
      ]);

  Widget _phoneForm() => Column(key: const ValueKey('phone'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _errorBanner(),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(
            controller: _phoneCtl,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]'))],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
            decoration: InputDecoration(
              labelText: context.tr('auth.phone'),
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [Text('🇶🇦', style: TextStyle(fontSize: 18)), SizedBox(width: 6), Text('+974', style: TextStyle(fontWeight: FontWeight.w700))]),
              ),
              helperText: context.tr('auth.phone_helper'),
              errorText: _error?.fieldError('phone'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _hasInvite,
          onChanged: (v) => setState(() => _hasInvite = v),
          title: Text(context.tr('auth.have_invite'), style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(context.tr('auth.invite_hint'), style: const TextStyle(fontSize: 12.5)),
        ),
        if (_hasInvite)
          Reveal(
            child: TextField(
              controller: _invite,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: context.tr('auth.invite_code'), prefixIcon: const Icon(Icons.confirmation_number_rounded)),
            ),
          ),
        const SizedBox(height: 20),
        BusyButton(label: context.tr('auth.send_code'), icon: Icons.sms_rounded, onPressed: _sendCode),
      ]);
}

class _MethodSwitch extends StatelessWidget {
  const _MethodSwitch({required this.phone, required this.onChanged});
  final bool phone;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget seg(bool value, IconData icon, String label) {
      final on = phone == value;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(value);
            },
            child: AnimatedContainer(
              duration: MotionScope.duration(context, const Duration(milliseconds: 220)),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: on ? Palette.heroGradient : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: on ? [BoxShadow(color: Palette.maroon.withValues(alpha: .3), blurRadius: 12, offset: const Offset(0, 4))] : const [],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 18, color: on ? Colors.white : Theme.of(context).hintColor),
                const SizedBox(width: 8),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: on ? Colors.white : Theme.of(context).hintColor))),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: dark ? Colors.white10 : const Color(0xFFF1ECE2), borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        seg(false, Icons.badge_rounded, context.tr('auth.method_email')),
        seg(true, Icons.phone_iphone_rounded, context.tr('auth.method_phone')),
      ]),
    );
  }
}
