import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/api_result.dart';
import '../../core/auth/session_controller.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/util/format.dart';
import '../../core/util/json.dart';
import '../../core/widgets/ui.dart';
import '../cases/new_case_screen.dart';

String money(BuildContext context, Object? v, String currency) {
  final n = dbl(v) ?? 0;
  return '${NumberFormat.decimalPatternDigits(locale: context.lang, decimalDigits: n == n.roundToDouble() ? 0 : 2).format(n)} $currency';
}

// ---------------------------------------------------------------------------------------------------------------
// Customer: invoices, receipts and payment proof
// ---------------------------------------------------------------------------------------------------------------

final invoicesProvider = FutureProvider.autoDispose<ApiResult>((ref) async {
  ref.watch(epochProvider);
  return ref.read(apiProvider).get('my/invoices');
});

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String _tab = 'invoices';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(invoicesProvider);
    final r = data.valueOrNull;
    final cur = str(r?.meta['currency']) ?? 'QAR';
    final totals = obj(r?.map['totals']);
    return ModulePage(
      title: context.tr('module.invoices'),
      subtitle: context.tr('module.invoices.body'),
      icon: Icons.receipt_long_rounded,
      onRefresh: () async => ref.invalidate(invoicesProvider),
      headerBottom: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (r != null)
          Row(children: [
            Expanded(child: _HeaderFigure(label: context.tr('invoices.balance'), value: money(context, totals['balance'], cur), strong: true)),
            Expanded(child: _HeaderFigure(label: context.tr('invoices.paid'), value: money(context, totals['paid'], cur))),
          ]),
        const SizedBox(height: 12),
        FilterChips(
          options: {'invoices': context.tr('invoices.tab_invoices'), 'receipts': context.tr('invoices.tab_receipts')},
          value: _tab,
          onChanged: (t) => setState(() => _tab = t),
        ),
      ]),
      children: [
        AsyncBody(
          value: data,
          onRetry: () => ref.invalidate(invoicesProvider),
          builder: (r) {
            final rows = maps(r.map[_tab]);
            if (rows.isEmpty) return EmptyView(icon: Icons.receipt_long_rounded, title: context.tr(_tab == 'invoices' ? 'invoices.none' : 'invoices.no_receipts'));
            return Column(children: [
              for (final (i, x) in rows.indexed)
                Reveal(index: i, child: _tab == 'invoices' ? _InvoiceCard(x: x, currency: cur) : _ReceiptRow(x: x, currency: cur)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Text(context.tr('invoices.pay_note'), textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
              ),
            ]);
          },
        ),
      ],
    );
  }
}

class _HeaderFigure extends StatelessWidget {
  const _HeaderFigure({required this.label, required this.value, this.strong = false});
  final String label, value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12.5)),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(color: strong ? Palette.goldSoft : Colors.white, fontWeight: FontWeight.w800, fontSize: 22))),
      ]);
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.x, required this.currency});
  final Map<String, dynamic> x;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final total = dbl(x['total']) ?? 0, paid = dbl(x['paid']) ?? 0, balance = dbl(x['balance']) ?? 0;
    final settled = balance <= 0.009;
    final progress = total <= 0 ? 1.0 : (paid / total).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconBadge(settled ? Icons.task_alt_rounded : Icons.receipt_long_rounded, color: settled ? Palette.success : Palette.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(str(x['reference']) ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text([str(x['description']), Fmt.date(date(x['date']), context.lang)].whereType<String>().join(' · '), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
                ]),
              ),
              StatusChip(settled ? 'completed' : 'due', label: context.tr(settled ? 'invoices.settled' : 'invoices.open')),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _Figure(context.tr('invoices.total'), money(context, total, currency))),
              Expanded(child: _Figure(context.tr('invoices.paid'), money(context, paid, currency))),
              Expanded(child: _Figure(context.tr('invoices.balance'), money(context, balance, currency), color: settled ? Palette.success : Palette.danger)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress, minHeight: 7, color: Palette.success, backgroundColor: Palette.success.withValues(alpha: .12))),
            if (x['due_date'] != null && !settled) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${context.tr('invoices.due')} ${Fmt.date(date(x['due_date']), context.lang)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
            if (!settled) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  final linkType = switch (x['kind']) { 'rental_invoice' => 'rental_contract', final String k => k, _ => 'rental_contract' };
                  context.push('/cases/new',
                      extra: CasePrefill(
                        category: 'payments',
                        subject: context.tr('invoices.proof_subject', {'ref': x['reference']}),
                        body: context.tr('invoices.proof_body', {'ref': x['reference'], 'amount': money(context, balance, currency)}),
                        links: [if (x['contract_id'] != null) {'type': linkType, 'id': x['contract_id']}],
                      ));
                },
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(context.tr('invoices.send_proof')),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, {this.color});
  final String label, value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11.5, fontWeight: FontWeight.w600)),
        FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color))),
      ]);
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.x, required this.currency});
  final Map<String, dynamic> x;
  final String currency;

  @override
  Widget build(BuildContext context) => ListRow(
        icon: Icons.payments_rounded,
        iconColor: Palette.success,
        title: money(context, x['amount'], currency),
        subtitle: [str(x['reference']), if (x['for'] != null) '→ ${x['for']}', Fmt.humanize(str(x['method']))].whereType<String>().join(' · '),
        meta: Fmt.date(date(x['date']), context.lang),
      );
}

// ---------------------------------------------------------------------------------------------------------------
// Worker: salary statements
// ---------------------------------------------------------------------------------------------------------------

final salariesProvider = FutureProvider.autoDispose<ApiResult>((ref) async {
  ref.watch(epochProvider);
  return ref.read(apiProvider).get('my/salaries');
});

class SalariesScreen extends ConsumerWidget {
  const SalariesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(salariesProvider);
    return ModulePage(
      title: context.tr('module.salaries'),
      subtitle: context.tr('module.salaries.body'),
      icon: Icons.account_balance_wallet_rounded,
      onRefresh: () async => ref.invalidate(salariesProvider),
      children: [
        AsyncBody(
          value: data,
          onRetry: () => ref.invalidate(salariesProvider),
          builder: (r) {
            final cur = str(r.meta['currency']) ?? 'QAR';
            if (r.meta['available'] == false) return EmptyView(icon: Icons.info_outline_rounded, title: context.tr('salaries.not_available'));
            if (r.list.isEmpty) return EmptyView(icon: Icons.account_balance_wallet_rounded, title: context.tr('salaries.none'));
            return Column(children: [for (final (i, s) in r.list.indexed) Reveal(index: i, child: _SalaryCard(s: s, currency: cur))]);
          },
        ),
      ],
    );
  }
}

class _SalaryCard extends StatelessWidget {
  const _SalaryCard({required this.s, required this.currency});
  final Map<String, dynamic> s;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final month = DateTime.tryParse('${s['month'] ?? ''}-01');
    final balance = dbl(s['balance']) ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Palette.navy, Palette.navySoft])),
            child: Row(children: [
              Expanded(child: Text(month == null ? (str(s['reference']) ?? '') : Fmt.month(month, context.lang), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),
              StatusChip(str(s['status'])),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _line(context, 'salaries.gross', money(context, s['gross'], currency)),
              _line(context, 'salaries.deductions', '− ${money(context, s['deductions'], currency)}', color: Palette.danger),
              const Divider(),
              _line(context, 'salaries.net', money(context, s['net'], currency), bold: true),
              _line(context, 'salaries.paid', money(context, s['paid'], currency), color: Palette.success),
              if (balance > 0.009) _line(context, 'salaries.balance', money(context, balance, currency), color: Palette.warning, bold: true),
              if (s['days'] != null) _line(context, 'salaries.days', '${s['days']}'),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => context.push('/cases/new',
                      extra: CasePrefill(
                        category: 'salary',
                        subject: context.tr('salaries.question_subject', {'ref': s['reference']}),
                        links: [if (s['id'] != null) {'type': s['kind'], 'id': s['id']}],
                      )),
                  icon: const Icon(Icons.help_outline_rounded),
                  label: Text(context.tr('salaries.ask')),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _line(BuildContext context, String key, String value, {Color? color, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(context.tr(key), style: TextStyle(color: Theme.of(context).hintColor))),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color)),
        ]),
      );
}

// ---------------------------------------------------------------------------------------------------------------
// Customer: agreements and online signing
// ---------------------------------------------------------------------------------------------------------------

final agreementsProvider = FutureProvider.autoDispose<ApiResult>((ref) async {
  ref.watch(epochProvider);
  return ref.read(apiProvider).get('my/agreements');
});

class AgreementsScreen extends ConsumerWidget {
  const AgreementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(agreementsProvider);
    return ModulePage(
      title: context.tr('module.agreements'),
      subtitle: context.tr('module.agreements.body'),
      icon: Icons.history_edu_rounded,
      onRefresh: () async => ref.invalidate(agreementsProvider),
      children: [
        AsyncBody(
          value: data,
          onRetry: () => ref.invalidate(agreementsProvider),
          builder: (r) => r.list.isEmpty
              ? EmptyView(icon: Icons.history_edu_rounded, title: context.tr('agreements.none'))
              : Column(children: [
                  for (final (i, a) in r.list.indexed)
                    Reveal(
                      index: i,
                      child: ListRow(
                        icon: a['can_sign'] == true ? Icons.draw_rounded : (a['signed_at'] != null ? Icons.verified_rounded : Icons.description_rounded),
                        iconColor: a['can_sign'] == true ? Palette.warning : (a['signed_at'] != null ? Palette.success : Palette.navySoft),
                        title: '${a['title'] ?? ''} · ${a['reference'] ?? ''}',
                        subtitle: [Fmt.date(date(a['date']), context.lang), if (a['ends_on'] != null) '→ ${Fmt.date(date(a['ends_on']), context.lang)}'].join(' '),
                        meta: a['can_sign'] == true
                            ? context.tr('agreements.waiting')
                            : (a['signed_at'] != null ? context.tr('agreements.signed_on', {'d': Fmt.dateTime(date(a['signed_at']), context.lang)}) : null),
                        trailing: a['can_sign'] == true ? StatusChip('pending', label: context.tr('agreements.sign_now')) : StatusChip(str(a['status'])),
                        onTap: a['readable'] == true
                            ? () async {
                                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgreementScreen(kind: '${a['kind']}', reference: '${a['reference']}')));
                                ref.invalidate(agreementsProvider);
                              }
                            : null,
                      ),
                    ),
                ]),
        ),
      ],
    );
  }
}

final _agreementProvider = FutureProvider.autoDispose.family<ApiResult, String>((ref, path) => ref.read(apiProvider).get(path));

class AgreementScreen extends ConsumerWidget {
  const AgreementScreen({super.key, required this.kind, required this.reference});
  final String kind;
  final String reference;

  String get _path => 'my/agreements/$kind/${Uri.encodeComponent(reference)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_agreementProvider(_path));
    final a = data.valueOrNull?.map ?? const {};
    return ModulePage(
      title: '${a['title'] ?? context.tr('module.agreements')}',
      subtitle: reference,
      icon: Icons.history_edu_rounded,
      onRefresh: () async => ref.invalidate(_agreementProvider(_path)),
      children: [
        AsyncBody(
          value: data,
          onRetry: () => ref.invalidate(_agreementProvider(_path)),
          builder: (r) {
            final sections = maps(r.map['sections']);
            final preferred = sections.where((s) => s['lang'] == context.lang).toList();
            final ordered = [...preferred, ...sections.where((s) => !preferred.contains(s))];
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (r.map['signed_at'] != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _SignedBanner(name: str(r.map['signed_name']) ?? '', at: date(r.map['signed_at'])),
                ),
              for (final s in ordered)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                  child: Card(
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: s == ordered.first,
                        title: Text(str(s['title']) ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          Directionality(
                            textDirection: s['lang'] == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                            child: HtmlWidget(str(s['html']) ?? '', textStyle: const TextStyle(height: 1.5)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (r.map['can_sign'] == true)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: BusyButton(
                    label: context.tr('agreements.sign_now'),
                    icon: Icons.draw_rounded,
                    onPressed: () async {
                      final done = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        enableDrag: false,
                        builder: (_) => _SignSheet(path: _path, consent: str(r.map['consent']) ?? context.tr('agreements.consent')),
                      );
                      if (done == true) ref.invalidate(_agreementProvider(_path));
                    },
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }
}

class _SignedBanner extends StatelessWidget {
  const _SignedBanner({required this.name, required this.at});
  final String name;
  final DateTime? at;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Palette.success.withValues(alpha: .1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Palette.success.withValues(alpha: .35))),
        child: Row(children: [
          const Icon(Icons.verified_rounded, color: Palette.success),
          const SizedBox(width: 10),
          Expanded(child: Text(context.tr('agreements.signed_by', {'name': name, 'd': Fmt.dateTime(at, context.lang)}), style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}

/// Name, consent and a drawn signature. The signature is sent as a PNG, exactly like the web signing page.
class _SignSheet extends ConsumerStatefulWidget {
  const _SignSheet({required this.path, required this.consent});
  final String path;
  final String consent;

  @override
  ConsumerState<_SignSheet> createState() => _SignSheetState();
}

class _SignSheetState extends ConsumerState<_SignSheet> {
  final _name = TextEditingController();
  final _pad = GlobalKey<SignaturePadState>();
  bool _agree = false;
  bool _drawn = false;
  final _key = ApiClient.newKey();
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _name.text = ref.read(meProvider).name;
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final png = await _pad.currentState?.toPng();
    if (png == null) return;
    try {
      await ref.read(apiProvider).post('${widget.path}/sign',
          idempotencyKey: _key, body: {'name': _name.text.trim(), 'signature': 'data:image/png;base64,${base64Encode(png)}', 'agree': true});
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Toast.success(context, context.tr('agreements.signed'));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(context.tr('agreements.sign_title'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          TextField(controller: _name, onChanged: (_) => setState(() {}), textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: context.tr('agreements.full_name'), errorText: _error?.fieldError('name'))),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Text(context.tr('agreements.draw'), style: const TextStyle(fontWeight: FontWeight.w700))),
            TextButton.icon(
              onPressed: () {
                _pad.currentState?.clear();
                setState(() => _drawn = false);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('agreements.clear')),
            ),
          ]),
          SignaturePad(key: _pad, onDrawn: () => setState(() => _drawn = true)),
          if (_error?.fieldError('signature') != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!.fieldError('signature')!, style: const TextStyle(color: Palette.danger))),
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _agree,
            onChanged: (v) => setState(() => _agree = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(widget.consent, style: const TextStyle(fontSize: 13.5)),
          ),
          if (_error != null && _error!.fields.isEmpty) Text(_error!.message, style: const TextStyle(color: Palette.danger, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          BusyButton(
            label: context.tr('agreements.sign_confirm'),
            icon: Icons.verified_rounded,
            onPressed: _agree && _drawn && _name.text.trim().length >= 3 ? _submit : null,
          ),
        ]),
      ),
    );
  }
}

/// A drawing surface that exports the strokes as a transparent PNG.
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, this.onDrawn, this.height = 200});
  final VoidCallback? onDrawn;
  final double height;

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;

  void clear() => setState(_strokes.clear);

  Future<Uint8List?> toPng() async {
    if (_strokes.isEmpty || _size.isEmpty) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(2);
    _SignaturePainter(_strokes, Palette.navy).paint(canvas, _size);
    final image = await recorder.endRecording().toImage(_size.width.ceil() * 2, _size.height.ceil() * 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        _size = Size(c.maxWidth, widget.height);
        return Semantics(
          label: context.tr('agreements.draw'),
          child: GestureDetector(
            onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
            onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
            onPanEnd: (_) => widget.onDrawn?.call(),
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Palette.gold.withValues(alpha: .6), width: 1.5)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CustomPaint(
                  painter: _SignaturePainter(_strokes, Palette.navy),
                  child: _strokes.isEmpty ? Center(child: Text(context.tr('agreements.sign_here'), style: const TextStyle(color: Colors.black26, fontSize: 18, fontWeight: FontWeight.w600))) : null,
                ),
              ),
            ),
          ),
        );
      });
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes, this.color);
  final List<List<Offset>> strokes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawCircle(s.first, 1.6, p..style = PaintingStyle.fill);
        p.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (var i = 1; i < s.length - 1; i++) {
        final mid = Offset((s[i].dx + s[i + 1].dx) / 2, (s[i].dy + s[i + 1].dy) / 2);
        path.quadraticBezierTo(s[i].dx, s[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(s.last.dx, s.last.dy);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}

// ---------------------------------------------------------------------------------------------------------------
// Customer: shortlists — choose a candidate or book a video interview
// ---------------------------------------------------------------------------------------------------------------

final shortlistsProvider = FutureProvider.autoDispose<ApiResult>((ref) async {
  ref.watch(epochProvider);
  return ref.read(apiProvider).get('my/shortlists');
});

class ShortlistsScreen extends ConsumerWidget {
  const ShortlistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(shortlistsProvider);
    return ModulePage(
      title: context.tr('module.shortlists'),
      subtitle: context.tr('module.shortlists.body'),
      icon: Icons.people_alt_rounded,
      onRefresh: () async => ref.invalidate(shortlistsProvider),
      children: [
        AsyncBody(
          value: data,
          onRetry: () => ref.invalidate(shortlistsProvider),
          builder: (r) => r.list.isEmpty
              ? EmptyView(
                  icon: Icons.people_alt_rounded,
                  title: context.tr('shortlists.none'),
                  message: context.tr('shortlists.none_body'),
                  action: FilledButton.icon(
                    onPressed: () => context.push('/cases/new', extra: CasePrefill(category: 'recruitment', subject: context.tr('shortlists.request_subject'))),
                    icon: const Icon(Icons.person_search_rounded),
                    label: Text(context.tr('shortlists.request')),
                  ),
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final s in r.list) ...[
                    if (str(s['note']) != null) Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 4), child: Text(str(s['note'])!, style: const TextStyle(fontStyle: FontStyle.italic))),
                    if (s['expires_at'] != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                        child: Text(context.tr('shortlists.until', {'d': Fmt.dateTime(date(s['expires_at']), context.lang)}), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                      ),
                    for (final (i, c) in maps(s['candidates']).indexed) Reveal(index: i, child: _CandidateCard(list: s, c: c)),
                  ],
                ]),
        ),
      ],
    );
  }
}

class _CandidateCard extends ConsumerWidget {
  const _CandidateCard({required this.list, required this.c});
  final Map<String, dynamic> list;
  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = str(c['photo']);
    final taken = c['taken'] == true, chosen = c['chosen'] == true;
    final someoneChosen = list['chosen_candidate_id'] != null;
    final facts = [
      str(c['nationality']),
      if (c['age'] != null) context.tr('shortlists.age', {'n': c['age']}),
      if (c['experience_years'] != null) context.tr('shortlists.experience', {'n': c['experience_years']}),
      if ((integer(c['gulf_years']) ?? 0) > 0) context.tr('shortlists.gulf', {'n': c['gulf_years']}),
      if (strList(c['languages']).isNotEmpty) strList(c['languages']).join(', '),
    ].whereType<String>().toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Opacity(
        opacity: taken ? .55 : 1,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(fit: StackFit.expand, children: [
                if (photo != null)
                  Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _Initials(text: str(c['initials']) ?? '•'))
                else
                  _Initials(text: str(c['initials']) ?? '•'),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xAA070F22)]))),
                if (c['score'] != null)
                  PositionedDirectional(
                    top: 12,
                    end: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(gradient: Palette.goldGradient, borderRadius: BorderRadius.circular(99)),
                      child: Text(context.tr('shortlists.match', {'n': c['score']}), style: const TextStyle(color: Palette.navy, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ),
                PositionedDirectional(
                  start: 16,
                  bottom: 12,
                  end: 16,
                  child: Text(str(c['name']) ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
                ),
                if (str(c['video']) != null)
                  PositionedDirectional(top: 12, start: 12, child: Chip(avatar: const Icon(Icons.videocam_rounded, size: 16), label: Text(context.tr('shortlists.video')))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 6, runSpacing: 6, children: [for (final f in facts) Chip(label: Text(f), visualDensity: VisualDensity.compact)]),
                for (final p in strList(c['points']))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: Palette.success),
                      const SizedBox(width: 6),
                      Expanded(child: Text(p)),
                    ]),
                  ),
                if (str(c['highlight']) != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(str(c['highlight'])!, style: TextStyle(color: Theme.of(context).hintColor))),
                const SizedBox(height: 14),
                if (taken)
                  Text(context.tr('shortlists.taken'), style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.w700))
                else if (chosen)
                  StatusChip('approved', label: context.tr('shortlists.you_chose'))
                else if (!someoneChosen)
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => _interview(context, ref), icon: const Icon(Icons.video_call_rounded), label: Text(context.tr('shortlists.interview')))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Palette.maroon, minimumSize: const Size.fromHeight(50)),
                        onPressed: () => _choose(context, ref),
                        icon: const Icon(Icons.favorite_rounded),
                        label: Text(context.tr('shortlists.choose')),
                      ),
                    ),
                  ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    if (!await confirmAction(context, title: context.tr('shortlists.choose_q', {'name': c['name']}), message: context.tr('shortlists.choose_body'), icon: Icons.favorite_rounded)) return;
    await _send(context, ref, 'choose', {'candidate': c['id']}, context.tr('shortlists.chosen', {'name': c['name']}));
  }

  Future<void> _interview(BuildContext context, WidgetRef ref) async {
    final slots = maps(list['slots']);
    if (slots.isEmpty) {
      Toast.info(context, context.tr('shortlists.no_slots'));
      return;
    }
    final slot = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(context.tr('shortlists.pick_time'), style: Theme.of(context).textTheme.titleLarge)),
          for (final s in slots) ListTile(leading: const Icon(Icons.schedule_rounded), title: Text(str(s['label']) ?? Fmt.dateTime(date(s['at']), context.lang)), onTap: () => Navigator.pop(context, s)),
        ]),
      ),
    );
    if (slot == null || !context.mounted) return;
    await _send(context, ref, 'interview', {'candidate': c['id'], 'slot': slot['index']}, context.tr('shortlists.booked', {'name': c['name'], 'at': slot['label'] ?? ''}));
  }

  Future<void> _send(BuildContext context, WidgetRef ref, String action, Map<String, dynamic> body, String success) async {
    try {
      await ref.read(apiProvider).post('my/shortlists/${list['id']}/$action', body: body, idempotencyKey: ApiClient.newKey());
      ref.invalidate(shortlistsProvider);
      if (context.mounted) Toast.success(context, success);
    } on ApiException catch (e) {
      ref.invalidate(shortlistsProvider);
      if (context.mounted) Toast.error(context, e);
    }
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: Palette.heroGradient),
        alignment: Alignment.center,
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w800)),
      );
}
