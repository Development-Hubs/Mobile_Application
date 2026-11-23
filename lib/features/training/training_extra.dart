import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

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

// ---------------------------------------------------------------------------------------------------------------
// QR scanner for session check-in
// ---------------------------------------------------------------------------------------------------------------

/// Scans the trainer's check-in QR and returns its text. Camera frames stay on the phone.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _c = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        MobileScanner(
          controller: _c,
          onDetect: (capture) {
            if (_done) return;
            final v = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
            if (v == null || v.isEmpty) return;
            _done = true;
            Navigator.of(context).pop(v.trim());
          },
          errorBuilder: (context, error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(context.tr('qr.camera_error'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(border: Border.all(color: Palette.goldSoft, width: 3), borderRadius: BorderRadius.circular(28)),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              GlassIconButton(icon: Icons.close_rounded, tooltip: context.tr('cancel'), onTap: () => Navigator.of(context).pop()),
              const Spacer(),
              GlassIconButton(icon: Icons.flash_on_rounded, tooltip: context.tr('qr.torch'), onTap: () => _c.toggleTorch()),
            ]),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.tr('qr.hint'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Course materials and quizzes (learner)
// ---------------------------------------------------------------------------------------------------------------

final _materialsProvider = FutureProvider.autoDispose.family<ApiResult, String>((ref, code) async {
  ref.watch(epochProvider);
  return ref.read(apiProvider).get('training/courses/${Uri.encodeComponent(code)}/materials');
});

class MaterialsScreen extends ConsumerWidget {
  const MaterialsScreen({super.key, required this.code, required this.name});
  final String code;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_materialsProvider(code));
    return ModulePage(
      title: name,
      subtitle: context.tr('learning.materials'),
      icon: Icons.auto_stories_rounded,
      onRefresh: () async => ref.invalidate(_materialsProvider(code)),
      children: [
        AsyncBody(
          value: data,
          onRetry: () => ref.invalidate(_materialsProvider(code)),
          builder: (r) => r.list.isEmpty
              ? EmptyView(icon: Icons.menu_book_rounded, title: context.tr('learning.no_materials'))
              : Column(children: [for (final (i, m) in r.list.indexed) Reveal(index: i, child: _Material(m: m))]),
        ),
      ],
    );
  }
}

class _Material extends ConsumerStatefulWidget {
  const _Material({required this.m});
  final Map<String, dynamic> m;

  @override
  ConsumerState<_Material> createState() => _MaterialState();
}

class _MaterialState extends ConsumerState<_Material> {
  bool _busy = false;

  Future<void> _file() async {
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/material_${widget.m['id']}';
      await ref.read(apiProvider).download('training/materials/${widget.m['id']}/file', path);
      await OpenFilex.open(path);
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final kind = str(m['kind']) ?? 'text';
    final icon = switch (kind) { 'quiz' => Icons.quiz_rounded, 'video' => Icons.play_circle_rounded, 'audio' => Icons.headphones_rounded, 'file' || 'document' => Icons.description_rounded, _ => Icons.article_rounded };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconBadge(icon, color: kind == 'quiz' ? Palette.gold : Palette.sea),
              const SizedBox(width: 12),
              Expanded(child: Text(str(m['title']) ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            ]),
            if (str(m['body']) != null) ...[const SizedBox(height: 10), SelectableText(str(m['body'])!, style: const TextStyle(height: 1.5))],
            if (str(m['transcript']) != null)
              ExpansionTile(tilePadding: EdgeInsets.zero, title: Text(context.tr('learning.transcript')), children: [SelectableText(str(m['transcript'])!)]),
            const SizedBox(height: 10),
            if (m['file'] != null)
              OutlinedButton.icon(
                onPressed: _busy ? null : _file,
                icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded),
                label: Text(context.tr('learning.open_file')),
              ),
            if (kind == 'quiz' && m['quiz'] is List)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizScreen(material: m))),
                icon: const Icon(Icons.quiz_rounded),
                label: Text(context.tr('learning.start_quiz', {'n': (m['quiz'] as List).length})),
              ),
          ]),
        ),
      ),
    );
  }
}

/// A knowledge quiz. Answers are saved as a draft on the ERP while answering; the score comes only from the ERP.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.material});
  final Map<String, dynamic> material;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final _answers = <String, int>{};
  int _index = 0;
  bool _loading = true;
  Map<String, dynamic>? _result;
  final _key = ApiClient.newKey();

  List<Map<String, dynamic>> get _qs => maps(widget.material['quiz']);
  String get _id => '${widget.material['id']}';

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    try {
      final r = await ref.read(apiProvider).get('training/quizzes/$_id/draft');
      obj(r.map['answers']).forEach((k, v) {
        final i = integer(v);
        if (i != null) _answers[k] = i;
      });
    } catch (_) {
      // no draft: start empty
    }
    if (mounted) setState(() => _loading = false);
  }

  void _saveDraft() {
    ref.read(apiProvider).put('training/quizzes/$_id/draft', body: {'answers': _answers}).ignore();
  }

  Future<void> _submit() async {
    if (_answers.length < _qs.length && !await confirmAction(context, title: context.tr('quiz.unanswered', {'n': _qs.length - _answers.length}))) return;
    try {
      final r = await ref.read(apiProvider).post('training/quizzes/$_id', body: {'answers': _answers}, idempotencyKey: _key);
      ref.read(apiProvider).delete('training/quizzes/$_id/draft').ignore();
      setState(() => _result = r.map);
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qs = _qs;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_result != null) return _ResultView(result: _result!, onDone: () => Navigator.of(context).pop());
    final q = qs[_index];
    final qid = '${q['id']}';
    final options = strList(q['options']);
    return Scaffold(
      body: Column(children: [
        HeroHeader(
          title: str(widget.material['title']) ?? context.tr('learning.quiz'),
          subtitle: context.tr('quiz.progress', {'i': _index + 1, 'n': qs.length}),
          icon: Icons.quiz_rounded,
          bottom: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: (_index + 1) / qs.length, minHeight: 8, color: Palette.goldSoft, backgroundColor: Colors.white24),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: MotionScope.duration(context, const Duration(milliseconds: 250)),
            child: ListView(key: ValueKey(_index), padding: const EdgeInsets.all(20), children: [
              Text(str(q['q']) ?? '', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              for (final (i, o) in options.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: _answers[qid] == i ? Palette.maroon.withValues(alpha: .1) : Theme.of(context).cardTheme.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: _answers[qid] == i ? Palette.maroon : Theme.of(context).dividerColor, width: _answers[qid] == i ? 2 : 1),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() => _answers[qid] = i);
                        _saveDraft();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: _answers[qid] == i ? Palette.maroon : Palette.sand,
                            child: Text(String.fromCharCode(65 + i), style: TextStyle(color: _answers[qid] == i ? Colors.white : Palette.navy, fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(o, style: const TextStyle(fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(children: [
              if (_index > 0) Expanded(child: OutlinedButton(onPressed: () => setState(() => _index--), child: Text(context.tr('previous')))),
              if (_index > 0) const SizedBox(width: 10),
              Expanded(
                child: _index < qs.length - 1
                    ? FilledButton(onPressed: () => setState(() => _index++), child: Text(context.tr('next')))
                    : BusyButton(label: context.tr('quiz.submit'), icon: Icons.check_rounded, onPressed: _submit),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.onDone});
  final Map<String, dynamic> result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final pct = integer(result['percent']) ?? 0;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Palette.nightGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Icon(pct >= 70 ? Icons.emoji_events_rounded : Icons.school_rounded, color: Palette.goldSoft, size: 84),
              const SizedBox(height: 18),
              Text('$pct%', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white)),
              Text(context.tr('quiz.score', {'c': result['correct'] ?? 0, 'n': result['total'] ?? 0}), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 16),
              if (str(result['note']) != null) Text(str(result['note'])!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 28),
              BusyButton(label: context.tr('done'), icon: Icons.check_rounded, gradient: Palette.goldGradient, onPressed: () async => onDone()),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Assessor: rubric scoring with evidence photos
// ---------------------------------------------------------------------------------------------------------------

final _assessorProvider = FutureProvider.autoDispose<ApiResult>((ref) async {
  ref.watch(epochProvider);
  return ref.read(apiProvider).get('training/staff/assessor-tasks');
});

class AssessorScreen extends ConsumerWidget {
  const AssessorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_assessorProvider);
    return ModulePage(
      title: context.tr('module.assessor'),
      subtitle: context.tr('module.assessor.body'),
      icon: Icons.fact_check_rounded,
      onRefresh: () async => ref.invalidate(_assessorProvider),
      children: [
        AsyncBody(
          value: data,
          onRetry: () => ref.invalidate(_assessorProvider),
          builder: (r) => r.list.isEmpty
              ? EmptyView(icon: Icons.task_alt_rounded, title: context.tr('assessor.empty'))
              : Column(children: [
                  for (final t in r.list)
                    ListRow(
                      icon: Icons.person_search_rounded,
                      iconColor: Palette.gold,
                      title: str(t['name']) ?? '',
                      subtitle: str(t['course']),
                      meta: context.tr('assessor.attempt', {'n': t['attempt'] ?? 1}),
                      trailing: StatusChip(str(t['state'])),
                      onTap: () async {
                        final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _AssessForm(task: t, methods: obj(r.meta['methods']))));
                        if (ok == true) ref.invalidate(_assessorProvider);
                      },
                    ),
                ]),
        ),
      ],
    );
  }
}

class _AssessForm extends ConsumerStatefulWidget {
  const _AssessForm({required this.task, required this.methods});
  final Map<String, dynamic> task;
  final Map<String, dynamic> methods;

  @override
  ConsumerState<_AssessForm> createState() => _AssessFormState();
}

class _AssessFormState extends ConsumerState<_AssessForm> {
  String _method = 'demonstration';
  final _scores = <String, double>{};
  final _feedback = TextEditingController();
  final _note = TextEditingController();
  final _photos = <File>[];
  final _key = ApiClient.newKey();
  ApiException? _error;

  @override
  Widget build(BuildContext context) {
    final rubric = maps(widget.task['rubric']);
    final methods = widget.methods.isEmpty ? {'demonstration': 'Supervised demonstration', 'observed': 'Observed workplace task', 'roleplay': 'Role-play', 'quiz': 'Knowledge quiz', 'baseline': 'Baseline / test-out'} : widget.methods;
    final visible = rubric.where((c) => _method != 'quiz' || c['kind'] == 'knowledge').toList();
    return ModulePage(
      title: str(widget.task['name']) ?? '',
      subtitle: str(widget.task['course']),
      icon: Icons.fact_check_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              initialValue: methods.containsKey(_method) ? _method : methods.keys.first,
              decoration: InputDecoration(labelText: context.tr('assessor.method')),
              items: [for (final e in methods.entries) DropdownMenuItem(value: e.key, child: Text('${e.value}'))],
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            const SizedBox(height: 14),
            if (visible.isEmpty) Text(context.tr('assessor.no_rubric'), style: TextStyle(color: Theme.of(context).hintColor)),
            for (final c in visible)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Text(str(c['label']) ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                      if (c['critical'] == true) StatusChip('overdue', label: context.tr('assessor.critical')),
                      const SizedBox(width: 8),
                      Text(_scores[c['key']] == null ? '—' : '${_scores[c['key']]!.round()}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    ]),
                    Slider(
                      value: _scores[c['key']] ?? 0,
                      max: 100,
                      divisions: 20,
                      label: '${(_scores[c['key']] ?? 0).round()}',
                      activeColor: Palette.maroon,
                      onChanged: (v) => setState(() => _scores['${c['key']}'] = v),
                    ),
                    if (_error?.fieldError('scores.${c['key']}') != null) Text(_error!.fieldError('scores.${c['key']}')!, style: const TextStyle(color: Palette.danger)),
                  ]),
                ),
              ),
            TextField(controller: _feedback, maxLines: 3, decoration: InputDecoration(labelText: context.tr('assessor.feedback'))),
            const SizedBox(height: 10),
            TextField(controller: _note, maxLines: 2, decoration: InputDecoration(labelText: context.tr('assessor.note'))),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in _photos)
                Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(p, width: 72, height: 72, fit: BoxFit.cover)),
                  Positioned(right: 0, top: 0, child: InkWell(onTap: () => setState(() => _photos.remove(p)), child: const CircleAvatar(radius: 11, child: Icon(Icons.close, size: 14)))),
                ]),
              if (_photos.length < 5)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 2000);
                    if (x != null) setState(() => _photos.add(File(x.path)));
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Palette.maroon.withValues(alpha: .4))),
                    child: const Icon(Icons.add_a_photo_rounded, color: Palette.maroon),
                  ),
                ),
            ]),
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(context.tr('assessor.evidence_note'), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12))),
            if (_error != null && _error!.fields.isEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!.message, style: const TextStyle(color: Palette.danger, fontWeight: FontWeight.w600))),
            const SizedBox(height: 18),
            BusyButton(
              label: context.tr('assessor.submit'),
              icon: Icons.send_rounded,
              onPressed: _scores.isEmpty ? null : _submit,
            ),
          ]),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!await confirmAction(context, title: context.tr('assessor.confirm'), message: context.tr('assessor.confirm_body'))) return;
    setState(() => _error = null);
    final fields = <String, dynamic>{
      'method': _method,
      for (final e in _scores.entries) 'scores[${e.key}]': e.value.round(),
      if (_feedback.text.trim().isNotEmpty) 'feedback': _feedback.text.trim(),
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
    };
    try {
      final r = await ref.read(apiProvider).upload('training/staff/enrolments/${widget.task['enrolment_id']}/assessments', fields: fields, files: _photos, idempotencyKey: _key);
      if (!mounted) return;
      Toast.success(context, context.tr('assessor.saved', {'s': r.map['score'] ?? '—'}));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e);
    }
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Approver: nominations waiting
// ---------------------------------------------------------------------------------------------------------------

final _approvalsProvider = FutureProvider.autoDispose<ApiResult>((ref) async {
  ref.watch(epochProvider);
  return ref.read(apiProvider).get('training/staff/approvals');
});

class TrainingApprovalsScreen extends ConsumerWidget {
  const TrainingApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_approvalsProvider);
    return ModulePage(
      title: context.tr('module.training_approvals'),
      subtitle: context.tr('module.training_approvals.body'),
      icon: Icons.how_to_reg_rounded,
      onRefresh: () async => ref.invalidate(_approvalsProvider),
      children: [
        AsyncBody(
          value: data,
          onRetry: () => ref.invalidate(_approvalsProvider),
          builder: (r) => r.list.isEmpty
              ? EmptyView(icon: Icons.verified_user_rounded, title: context.tr('approvals.empty'))
              : Column(children: [
                  for (final e in r.list)
                    ListRow(
                      icon: Icons.school_rounded,
                      iconColor: Palette.warning,
                      title: str(e['name']) ?? '',
                      subtitle: str(e['course']),
                      meta: Fmt.dateTime(date(e['requested_at']), context.lang),
                      trailing: FilledButton.tonal(
                        onPressed: () async {
                          if (!await confirmAction(context, title: context.tr('approvals.approve'), message: '${e['name']} · ${e['course']}', icon: Icons.how_to_reg_rounded)) return;
                          try {
                            await ref.read(apiProvider).post('training/staff/enrolments/${e['enrolment_id']}/approve');
                            ref.invalidate(_approvalsProvider);
                            if (context.mounted) Toast.success(context, context.tr('saved'));
                          } on ApiException catch (err) {
                            if (context.mounted) Toast.error(context, err);
                          }
                        },
                        child: Text(context.tr('approvals.approve_short')),
                      ),
                    ),
                ]),
        ),
      ],
    );
  }
}
