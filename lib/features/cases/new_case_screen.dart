import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/session_controller.dart';
import '../../core/offline/offline_store.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/palette.dart';
import '../../core/util/json.dart';
import '../../core/widgets/ui.dart';

final categoriesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(epochProvider);
  return (await ref.read(apiProvider).get('support/categories')).list;
});

class NewCaseScreen extends ConsumerStatefulWidget {
  const NewCaseScreen({super.key});

  @override
  ConsumerState<NewCaseScreen> createState() => _NewCaseScreenState();
}

class _NewCaseScreenState extends ConsumerState<NewCaseScreen> {
  String? _category;
  final _subject = TextEditingController();
  final _body = TextEditingController();
  final _files = <File>[];
  String _priority = 'normal';
  final _key = ApiClient.newKey(); // one key for this form; a retry after a lost answer cannot open a second case
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    final store = ref.read(offlineStoreProvider);
    _subject.text = store.draft('newcase.subject') ?? '';
    _body.text = store.draft('newcase.body') ?? '';
    _subject.addListener(() => store.saveDraft('newcase.subject', _subject.text));
    _body.addListener(() => store.saveDraft('newcase.body', _body.text));
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final api = ref.read(apiProvider);
    final fields = {
      'category': _category ?? '',
      'subject': _subject.text.trim(),
      'description': _body.text.trim(),
      'language': context.lang,
      if (ref.read(meProvider).isStaff) 'priority': _priority,
    };
    try {
      final r = _files.isEmpty ? await api.post('cases', body: fields, idempotencyKey: _key) : await api.upload('cases', fields: fields, files: _files, idempotencyKey: _key);
      final store = ref.read(offlineStoreProvider);
      await store.clearDraft('newcase.subject');
      await store.clearDraft('newcase.body');
      if (!mounted) return;
      final similar = maps(r.meta['similar_open_cases']);
      Toast.success(context, context.tr('cases.created', {'ref': r.map['reference'] ?? ''}));
      if (similar.isNotEmpty) Toast.info(context, context.tr('cases.similar', {'n': similar.length}));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e);
    }
  }

  Future<void> _addFiles() async {
    final r = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (r == null) return;
    setState(() => _files.addAll(r.files.where((f) => f.path != null && f.size <= 15 * 1024 * 1024).map((f) => File(f.path!)).take(5 - _files.length)));
  }

  Future<void> _photo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75, maxWidth: 2200);
    if (x != null && _files.length < 5) setState(() => _files.add(File(x.path)));
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider);
    final staff = ref.watch(meProvider).isStaff;
    return ModulePage(
      title: context.tr('cases.new'),
      subtitle: context.tr('cases.new_sub'),
      icon: Icons.add_comment_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(context.tr('cases.category'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            AsyncBody(
              value: cats,
              onRetry: () => ref.invalidate(categoriesProvider),
              skeleton: const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              builder: (list) => Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in list)
                  ChoiceChip(
                    label: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (c['private'] == true) const Padding(padding: EdgeInsetsDirectional.only(end: 4), child: Icon(Icons.lock_rounded, size: 14)),
                      Text(str(c['name']) ?? ''),
                    ]),
                    selected: _category == c['key'],
                    selectedColor: Palette.goldSoft,
                    onSelected: (_) => setState(() => _category = str(c['key'])),
                  ),
              ]),
            ),
            if (_error?.fieldError('category') != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!.fieldError('category')!, style: const TextStyle(color: Palette.danger))),
            const SizedBox(height: 18),
            TextField(controller: _subject, maxLength: 200, decoration: InputDecoration(labelText: context.tr('cases.subject'), errorText: _error?.fieldError('subject'))),
            const SizedBox(height: 8),
            TextField(controller: _body, minLines: 4, maxLines: 10, decoration: InputDecoration(labelText: context.tr('cases.details'), alignLabelWithHint: true, errorText: _error?.fieldError('description'))),
            if (staff) ...[
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: [for (final p in const ['low', 'normal', 'high', 'urgent']) ButtonSegment(value: p, label: Text(context.tr('priority.$p')))],
                selected: {_priority},
                onSelectionChanged: (s) => setState(() => _priority = s.first),
              ),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _files.length >= 5 ? null : _addFiles, icon: const Icon(Icons.attach_file_rounded), label: Text(context.tr('files.attach')))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: _files.length >= 5 ? null : _photo, icon: const Icon(Icons.photo_camera_rounded), label: Text(context.tr('files.photo')))),
            ]),
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final f in _files) InputChip(label: Text(f.uri.pathSegments.last), onDeleted: () => setState(() => _files.remove(f)))]),
            ],
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(context.tr('files.limits'), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12))),
            if (_error != null && _error!.fields.isEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!.message, style: const TextStyle(color: Palette.danger, fontWeight: FontWeight.w600))),
            const SizedBox(height: 20),
            BusyButton(label: context.tr('cases.send'), icon: Icons.send_rounded, onPressed: _category == null ? null : _submit),
          ]),
        ),
      ],
    );
  }
}
