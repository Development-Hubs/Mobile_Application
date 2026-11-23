import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/session_controller.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/ui.dart';
import 'auth_scaffold.dart';
import 'sign_in_screen.dart';

/// New customer registration: name, mobile and an optional email, then the phone is confirmed with a
/// one-time code. No password is created and nothing is stored on the device except the session token.
/// The ERP creates the customer record (or links an existing one with the same phone) only after the
/// code is verified.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _agree = false;
  ApiException? _error;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _valid() {
    final email = _email.text.trim();
    setState(() {
      _nameError = _name.text.trim().length < 2 ? context.tr('auth.name_required') : null;
      _emailError = !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? context.tr('auth.email_invalid') : null;
      _passwordError = _password.text.length < 8 ? context.tr('auth.password_rule') : null;
    });
    return _nameError == null && _emailError == null && _passwordError == null;
  }

  Future<void> _continue() async {
    if (!_valid()) return;
    if (!_agree) {
      Toast.info(context, context.tr('auth.accept_terms'));
      return;
    }
    setState(() => _error = null);
    final phone = normalizePhone(_phone.text);
    try {
      final (delivery, ttl) = await ref.read(sessionProvider.notifier).requestOtp(phone);
      if (!mounted) return;
      context.push('/otp', extra: {'phone': phone, 'delivery': delivery, 'ttl': ttl, 'registerName': _name.text.trim(), 'registerEmail': _email.text.trim(), 'registerPassword': _password.text});
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Widget _label(String key, {bool optional = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2, right: 2),
        child: Row(children: [
          Text(context.tr(key), style: Theme.of(context).textTheme.labelLarge),
          if (optional) ...[
            const SizedBox(width: 6),
            Text('(${context.tr('common.optional')})', style: Theme.of(context).textTheme.bodySmall),
          ],
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final boot = ref.watch(sessionProvider.select((s) => s.boot));
    final e = _error;
    return AuthScaffold(
      showBack: true,
      title: context.tr('auth.register_title'),
      subtitle: boot?.companyName != null ? context.tr('auth.register_with', {'company': boot!.companyName}) : context.tr('auth.register_subtitle'),
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _Steps(),
          const SizedBox(height: 22),
          if (e != null && e.fields.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: Palette.danger.withValues(alpha: .07), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: Palette.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.message, style: const TextStyle(color: Palette.danger, fontWeight: FontWeight.w500))),
                ]),
              ),
            ),
          _label('auth.full_name'),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.person_outline_rounded), errorText: _nameError ?? e?.fieldError('name')),
          ),
          const SizedBox(height: 16),
          _label('auth.phone'),
          PhoneField(controller: _phone, error: e?.fieldError('phone')),
          const SizedBox(height: 16),
          _label('auth.email'),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(hintText: 'name@example.com', prefixIcon: const Icon(Icons.alternate_email_rounded), errorText: _emailError ?? e?.fieldError('email')),
          ),
          const SizedBox(height: 16),
          _label('auth.new_password'),
          TextField(
            controller: _password,
            obscureText: !_showPassword,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              helperText: context.tr('auth.password_rule'),
              errorText: _passwordError ?? e?.fieldError('password'),
              suffixIcon: IconButton(
                tooltip: context.tr(_showPassword ? 'auth.hide_password' : 'auth.show_password'),
                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _agree = !_agree),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 28, height: 24, child: Checkbox(value: _agree, onChanged: (v) => setState(() => _agree = v ?? false))),
                const SizedBox(width: 8),
                Expanded(child: Text(context.tr('auth.register_consent'), style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5))),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          BusyButton(label: context.tr('auth.register_continue'), onPressed: _continue),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(context.tr('auth.have_account'), style: Theme.of(context).textTheme.bodyMedium),
            TextButton(onPressed: () => context.pop(), child: Text(context.tr('auth.sign_in'))),
          ]),
        ]),
      ),
    );
  }
}

/// "1 Your details — 2 Confirm phone"
class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    Widget step(int n, String key, bool on) => Expanded(
          child: Row(children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: on ? Palette.maroon : Palette.maroon.withValues(alpha: .08)),
              child: Text('$n', style: TextStyle(color: on ? Colors.white : Palette.maroon, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(context.tr(key), overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? null : Theme.of(context).hintColor))),
          ]),
        );
    return Row(children: [
      step(1, 'auth.step_details', true),
      Container(width: 24, height: 1, color: Theme.of(context).dividerColor, margin: const EdgeInsets.symmetric(horizontal: 8)),
      step(2, 'auth.step_confirm', false),
    ]);
  }
}
