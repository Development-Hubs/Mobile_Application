import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/session_controller.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/ui.dart';
import 'auth_scaffold.dart';

/// Enter the one-time code. The code is kept in memory only for this screen and never stored.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone, this.invite = '', this.delivery = 'sms', this.ttl = 300});
  final String phone;
  final String invite;
  final String delivery;
  final int ttl;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  late int _left = 45;
  ApiException? _error;
  bool _firstTime = false;
  int _shake = 0;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    _timer?.cancel();
    _left = 45;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left = (_left - 1).clamp(0, 999).toInt());
      if (_left == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length < 4) return;
    setState(() => _error = null);
    try {
      final claim = await ref.read(sessionProvider.notifier).verifyOtp(phone: widget.phone, code: _code.text, name: _name.text.trim(), invitation: widget.invite);
      _code.clear();
      if (mounted && claim == 'pending') Toast.info(context, context.tr('auth.claim_pending'));
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _error = e;
        _shake++;
        _code.clear();
      });
      _focus.requestFocus();
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(sessionProvider.notifier).requestOtp(widget.phone);
      if (!mounted) return;
      _tick();
      Toast.success(context, context.tr('auth.code_resent'));
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: context.tr('auth.enter_code'),
      subtitle: context.tr('auth.code_sent_to', {'phone': widget.phone, 'channel': context.tr('auth.channel.${widget.delivery}')}),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Shake(
          trigger: _shake,
          child: _CodeBoxes(controller: _code, focus: _focus, error: _error != null, onComplete: _verify),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!.message, textAlign: TextAlign.center, style: const TextStyle(color: Palette.danger, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 14),
        Center(
          child: _left > 0
              ? Text(context.tr('auth.resend_in', {'s': _left}), style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.w600))
              : TextButton.icon(onPressed: _resend, icon: const Icon(Icons.refresh_rounded), label: Text(context.tr('auth.resend'))),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => setState(() => _firstTime = !_firstTime),
          child: Text(context.tr('auth.first_time'), style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        if (_firstTime)
          Reveal(
            child: TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: InputDecoration(labelText: context.tr('auth.your_name'), prefixIcon: const Icon(Icons.person_rounded)),
            ),
          ),
        const SizedBox(height: 16),
        BusyButton(label: context.tr('auth.verify'), icon: Icons.verified_rounded, onPressed: _verify),
      ]),
    );
  }
}

class _CodeBoxes extends StatefulWidget {
  const _CodeBoxes({required this.controller, required this.focus, required this.error, required this.onComplete, this.length = 6});
  final TextEditingController controller;
  final FocusNode focus;
  final bool error;
  final VoidCallback onComplete;
  final int length;

  @override
  State<_CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<_CodeBoxes> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.focus.requestFocus());
  }

  void _changed() {
    setState(() {});
    if (widget.controller.text.length == widget.length) widget.onComplete();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [
        // the real field: invisible, receives keyboard input and SMS autofill
        Opacity(
          opacity: 0,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focus,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: widget.length,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(counterText: ''),
          ),
        ),
        GestureDetector(
          onTap: () => widget.focus.requestFocus(),
          child: Semantics(
            label: context.tr('auth.enter_code'),
            value: '${text.length} / ${widget.length}',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(widget.length, (i) {
                final filled = i < text.length;
                final active = i == text.length && widget.focus.hasFocus;
                final color = widget.error ? Palette.danger : (active ? Palette.maroon : (filled ? Palette.gold : (dark ? Colors.white24 : const Color(0x22000000))));
                return AnimatedContainer(
                  duration: MotionScope.duration(context, const Duration(milliseconds: 180)),
                  width: 46,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF142247) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color, width: active || filled ? 2 : 1),
                    boxShadow: active ? [BoxShadow(color: Palette.maroon.withValues(alpha: .2), blurRadius: 12)] : const [],
                  ),
                  child: Text(filled ? text[i] : '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                );
              }),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Shake extends StatelessWidget {
  const _Shake({required this.trigger, required this.child});
  final int trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MotionScope.reducedOf(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween<double>(begin: trigger == 0 ? 1.0 : 0.0, end: 1.0),
      duration: const Duration(milliseconds: 420),
      builder: (context, v, c) {
        final dx = (1 - v) * 12 * (((v * 10).floor()).isEven ? 1 : -1);
        return Transform.translate(offset: Offset(dx, 0), child: c);
      },
      child: child,
    );
  }
}
