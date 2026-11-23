import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/session_controller.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/ui.dart';
import 'auth_scaffold.dart';
import 'otp_screen.dart';
import 'sign_in_screen.dart';

/// Required after a customer / candidate signs in with email + password and the ERP has no verified mobile number
/// for them yet. Step 1: the number. Step 2: the one-time code. The ERP then links the customer records with that
/// number (contracts, selections, invoices) — the phone is the proof, not anything chosen on this screen.
class VerifyPhoneScreen extends ConsumerStatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  ConsumerState<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends ConsumerState<VerifyPhoneScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _focus = FocusNode();
  String? _sentTo;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    final known = ref.read(sessionProvider).me?.phone;
    if (known != null && known.startsWith('+974')) _phone.text = known.substring(4);
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _error = null);
    final phone = normalizePhone(_phone.text);
    try {
      await ref.read(sessionProvider.notifier).requestPhoneCode(phone);
      if (mounted) setState(() => _sentTo = phone);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _verify() async {
    if (_code.text.length < 6 || _sentTo == null) return;
    setState(() => _error = null);
    try {
      final linked = await ref.read(sessionProvider.notifier).verifyPhone(_sentTo!, _code.text);
      if (mounted) Toast.success(context, context.tr(linked > 0 ? 'verify.linked' : 'verify.done', {'n': linked}));
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _error = e;
          _code.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sent = _sentTo != null;
    return AuthScaffold(
      title: context.tr('verify.title'),
      subtitle: context.tr(sent ? 'verify.code_sent' : 'verify.body', {'phone': _sentTo ?? ''}),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Palette.maroon.withValues(alpha: .05), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(Icons.verified_user_outlined, color: Palette.maroon),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr('verify.why'), style: theme.textTheme.bodySmall?.copyWith(height: 1.5))),
          ]),
        ),
        const SizedBox(height: 20),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!.message, style: const TextStyle(color: Palette.danger, fontWeight: FontWeight.w600)),
          ),
        if (!sent) ...[
          Text(context.tr('auth.phone'), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          PhoneField(controller: _phone, autofocus: true, error: _error?.fieldError('phone'), onSubmitted: (_) => _send()),
          const SizedBox(height: 20),
          BusyButton(label: context.tr('auth.send_code'), onPressed: _send),
        ] else ...[
          CodeBoxes(controller: _code, focus: _focus, error: _error != null, onComplete: _verify),
          const SizedBox(height: 20),
          BusyButton(label: context.tr('auth.verify'), onPressed: _verify),
          const SizedBox(height: 8),
          TextButton(onPressed: () => setState(() => _sentTo = null), child: Text(context.tr('verify.change_number'))),
        ],
        const SizedBox(height: 12),
        TextButton(onPressed: () => ref.read(sessionProvider.notifier).signOut(), child: Text(context.tr('settings.sign_out'))),
      ]),
    );
  }
}
