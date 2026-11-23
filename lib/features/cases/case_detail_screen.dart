import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/api_result.dart';
import '../../core/auth/session_controller.dart';
import '../../core/offline/offline_store.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/palette.dart';
import '../../core/util/format.dart';
import '../../core/util/json.dart';
import '../../core/widgets/ui.dart';

final caseProvider = FutureProvider.autoDispose.family<(ApiResult, ApiResult), String>((ref, id) async {
  ref.watch(epochProvider);
  final api = ref.read(apiProvider);
  final detail = await api.get('cases/$id');
  final messages = await api.get('cases/$id/messages');
  // marking read is a side effect the server records; a failure here does not hide the case
  api.post('cases/$id/read').ignore();
  return (detail, messages);
});

class CaseDetailScreen extends ConsumerWidget {
  const CaseDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(caseProvider(id));
    final me = ref.watch(meProvider);
    return Scaffold(
      body: AsyncBody(
        value: data,
        onRetry: () => ref.invalidate(caseProvider(id)),
        builder: (pair) {
          final c = pair.$1.map;
          final msgs = pair.$2.list;
          final actions = strList(c['available_actions']).where((a) => a != 'reply' && a != 'note').toList();
          return Column(children: [
            HeroHeader(
              title: str(c['subject']) ?? '',
              subtitle: '${c['reference'] ?? ''} · ${statusLabel(context, str(c['status']))}',
              icon: Icons.forum_rounded,
              trailing: actions.isEmpty
                  ? null
                  : PopupMenuButton<String>(
                      tooltip: context.tr('actions'),
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (a) => _action(context, ref, a),
                      itemBuilder: (_) => [for (final a in actions) PopupMenuItem(value: a, child: Text(context.tr('cases.action.$a')))],
                    ),
              bottom: Wrap(spacing: 8, runSpacing: 8, children: [
                StatusChip(str(c['status']), label: str(c['status_label'])),
                if (c['priority'] != null) _pill(context.tr('priority.${c['priority']}')),
                if (c['assigned_to'] != null) _pill('→ ${c['assigned_to']}'),
                if (c['restricted'] == true) _pill(context.tr('cases.restricted')),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(caseProvider(id)),
                child: ListView(
                  reverse: false,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    if (str(c['description']) != null) _Bubble(author: context.tr('cases.description'), body: str(c['description'])!, mine: false, kind: 'description', at: date(c['created_at'])),
                    for (final m in msgs) _Bubble(author: str(m['author']) ?? '', body: str(m['body']) ?? '', mine: m['mine'] == true, kind: str(m['kind']) ?? 'reply', at: date(m['created_at']), attachments: maps(m['attachments'])),
                    if (str(c['outcome']) != null) _Bubble(author: context.tr('cases.outcome'), body: str(c['outcome'])!, mine: false, kind: 'outcome', at: null),
                  ],
                ),
              ),
            ),
            if (!const {'closed', 'cancelled', 'merged'}.contains(c['status'])) _Composer(caseId: id, staff: me.isStaff),
          ]);
        },
      ),
    );
  }

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Palette.ink.withValues(alpha: .06), borderRadius: BorderRadius.circular(99)),
        child: Text(t, style: const TextStyle(color: Palette.ink2, fontWeight: FontWeight.w600, fontSize: 12)),
      );

  Future<void> _action(BuildContext context, WidgetRef ref, String action) async {
    final needsText = const {'resolve', 'cancel', 'wait_requester', 'wait_internal'}.contains(action);
    String? text;
    if (needsText) {
      text = await askText(context, title: context.tr('cases.action.$action'), hint: context.tr(action == 'resolve' ? 'cases.outcome_hint' : 'cases.reason_hint'), required: action == 'resolve');
      if (text == null) return;
    } else {
      if (!context.mounted) return;
      final ok = await confirmAction(context, title: context.tr('cases.action.$action'), message: context.tr('cases.confirm_action'), danger: action == 'cancel');
      if (!ok) return;
    }
    try {
      await ref.read(apiProvider).post('cases/$id/actions/$action', body: {if (text != null) (action == 'resolve' ? 'outcome' : 'reason'): text});
      ref.invalidate(caseProvider(id));
      if (context.mounted) Toast.success(context, context.tr('saved'));
    } on ApiException catch (e) {
      if (context.mounted) Toast.error(context, e);
    }
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.author, required this.body, required this.mine, required this.kind, required this.at, this.attachments = const []});
  final String author, body, kind;
  final bool mine;
  final DateTime? at;
  final List<Map<String, dynamic>> attachments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = kind == 'note';
    final system = kind == 'description' || kind == 'outcome' || kind == 'system';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = mine
        ? null
        : note
            ? Palette.gold.withValues(alpha: .16)
            : (dark ? const Color(0xFF16223F) : Colors.white);
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (system ? .95 : .8)),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: mine ? Palette.heroGradient : null,
            color: bg,
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(18),
              topEnd: const Radius.circular(18),
              bottomStart: Radius.circular(mine ? 18 : 4),
              bottomEnd: Radius.circular(mine ? 4 : 18),
            ),
            border: note ? Border.all(color: Palette.gold.withValues(alpha: .5)) : null,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (note) const Padding(padding: EdgeInsetsDirectional.only(end: 6), child: Icon(Icons.lock_rounded, size: 14, color: Palette.maroon)),
              Flexible(child: Text(note ? '${context.tr('cases.internal_note')} · $author' : author, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: mine ? Palette.goldSoft : Palette.maroon))),
            ]),
            const SizedBox(height: 4),
            SelectableText(body, style: TextStyle(color: mine ? Colors.white : null, height: 1.4)),
            for (final a in attachments)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _AttachmentChip(a: a, onDark: mine),
              ),
            if (at != null) ...[
              const SizedBox(height: 6),
              Text(Fmt.dateTime(at, context.lang), style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : Theme.of(context).hintColor)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _AttachmentChip extends ConsumerStatefulWidget {
  const _AttachmentChip({required this.a, required this.onDark});
  final Map<String, dynamic> a;
  final bool onDark;

  @override
  ConsumerState<_AttachmentChip> createState() => _AttachmentChipState();
}

class _AttachmentChipState extends ConsumerState<_AttachmentChip> {
  bool _busy = false;

  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      // private files are kept inside the app sandbox (temporary directory), never in shared storage
      final dir = await getTemporaryDirectory();
      final name = (str(widget.a['name']) ?? 'file').replaceAll(RegExp(r'[^\w.\-]'), '_');
      final path = '${dir.path}/att_${widget.a['id']}_$name';
      await ref.read(apiProvider).download('attachments/${widget.a['id']}', path);
      await OpenFilex.open(path);
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = str(widget.a['kind']);
    final icon = kind == 'image' ? Icons.image_rounded : (kind == 'voice' ? Icons.mic_rounded : Icons.description_rounded);
    final size = integer(widget.a['size']) ?? 0;
    return InkWell(
      onTap: _busy ? null : _open,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: (widget.onDark ? Colors.white : Palette.navy).withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon, size: 18, color: widget.onDark ? Colors.white : Palette.maroon),
          const SizedBox(width: 8),
          Flexible(child: Text(str(widget.a['name']) ?? '', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: widget.onDark ? Colors.white : null))),
          const SizedBox(width: 6),
          Text('${(size / 1024).ceil()} KB', style: TextStyle(fontSize: 11, color: widget.onDark ? Colors.white70 : Theme.of(context).hintColor)),
        ]),
      ),
    );
  }
}

class _Composer extends ConsumerStatefulWidget {
  const _Composer({required this.caseId, required this.staff});
  final String caseId;
  final bool staff;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _text = TextEditingController();
  final _files = <File>[];
  bool _note = false;
  bool _sending = false;
  String? _key;

  String get _draftKey => 'case.${widget.caseId}';

  @override
  void initState() {
    super.initState();
    // unsent text survives closing the screen or losing signal (kept on this phone only)
    _text.text = ref.read(offlineStoreProvider).draft(_draftKey) ?? '';
    _text.addListener(() => ref.read(offlineStoreProvider).saveDraft(_draftKey, _text.text));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: const [
      'jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'm4a', 'mp3', 'aac', 'ogg', 'opus', 'wav',
    ]);
    if (r == null) return;
    final picked = r.files.where((f) => f.path != null && f.size <= 15 * 1024 * 1024).map((f) => File(f.path!)).toList();
    if (picked.length < r.files.length && mounted) Toast.info(context, context.tr('files.too_big'));
    setState(() {
      _files.addAll(picked);
      if (_files.length > 5) _files.removeRange(5, _files.length);
      _key = null;
    });
  }

  Future<void> _send() async {
    if (_sending || (_text.text.trim().isEmpty && _files.isEmpty)) return;
    setState(() => _sending = true);
    _key ??= ApiClient.newKey(); // kept for a retry of the same message
    try {
      final api = ref.read(apiProvider);
      final fields = {'body': _text.text.trim(), 'kind': _note ? 'note' : 'reply'};
      if (_files.isEmpty) {
        await api.post('cases/${widget.caseId}/messages', body: fields, idempotencyKey: _key);
      } else {
        await api.upload('cases/${widget.caseId}/messages', fields: fields, files: _files, idempotencyKey: _key);
      }
      _text.clear();
      await ref.read(offlineStoreProvider).clearDraft(_draftKey);
      _files.clear();
      _key = null;
      ref.invalidate(caseProvider(widget.caseId));
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e); // the text stays in the box: nothing is lost and nothing is pretended
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      color: Theme.of(context).cardTheme.color,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.staff)
              Row(children: [
                ChoiceChip(label: Text(context.tr('cases.reply')), selected: !_note, onSelected: (_) => setState(() => _note = false)),
                const SizedBox(width: 8),
                ChoiceChip(avatar: const Icon(Icons.lock_rounded, size: 14), label: Text(context.tr('cases.internal_note')), selected: _note, onSelected: (_) => setState(() => _note = true)),
              ]),
            if (_files.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final f in _files)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6, top: 6),
                      child: InputChip(label: Text(f.uri.pathSegments.last, overflow: TextOverflow.ellipsis), onDeleted: () => setState(() => _files.remove(f))),
                    ),
                ]),
              ),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              IconButton(tooltip: context.tr('files.attach'), onPressed: _files.length >= 5 ? null : _pick, icon: const Icon(Icons.attach_file_rounded)),
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(helperText: _text.text.isNotEmpty ? context.tr('drafts.saved') : null, hintText: context.tr(_note ? 'cases.note_hint' : 'cases.reply_hint'), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: context.tr('send'),
                style: IconButton.styleFrom(backgroundColor: _note ? Palette.gold : Palette.maroon, minimumSize: const Size(48, 48)),
                onPressed: _sending ? null : _send,
                icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
