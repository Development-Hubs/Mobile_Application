import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/biometrics.dart';
import '../../core/auth/session_controller.dart';
import '../../core/config/env.dart';
import '../../core/i18n/i18n.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/palette.dart';
import '../../core/util/format.dart';
import '../../core/util/json.dart';
import '../../core/widgets/ui.dart';

final _versionProvider = FutureProvider<String>((ref) async {
  final p = await PackageInfo.fromPlatform();
  return '${p.version} (${p.buildNumber})';
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);
    final session = ref.watch(sessionProvider);
    return ModulePage(
      title: context.tr('settings.title'),
      subtitle: context.tr('settings.sub'),
      icon: Icons.settings_rounded,
      children: [
        _group(context, context.tr('settings.appearance'), [
          ListTile(
            leading: const IconBadge(Icons.translate_rounded, size: 38),
            title: Text(context.tr('settings.language')),
            trailing: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 'ar', label: Text('العربية')), ButtonSegment(value: 'en', label: Text('English'))],
              selected: {s.locale == 'en' ? 'en' : 'ar'},
              onSelectionChanged: (v) => ctl.setLocale(v.first),
            ),
          ),
          ListTile(
            leading: const IconBadge(Icons.dark_mode_rounded, size: 38, color: Palette.navySoft),
            title: Text(context.tr('settings.theme')),
            trailing: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded)),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded)),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => ctl.setTheme(v.first),
            ),
          ),
          ListTile(
            leading: const IconBadge(Icons.animation_rounded, size: 38, color: Palette.gold),
            title: Text(context.tr('settings.motion')),
            subtitle: Text(context.tr('settings.motion_body')),
            isThreeLine: true,
            trailing: DropdownButton<MotionPref>(
              value: s.motion,
              underline: const SizedBox(),
              items: [for (final m in MotionPref.values) DropdownMenuItem(value: m, child: Text(context.tr('settings.motion.${m.name}')))],
              onChanged: (v) => v == null ? null : ctl.setMotion(v),
            ),
          ),
        ]),
        _group(context, context.tr('settings.security'), [
          _BiometricTile(on: s.biometrics, onChanged: ctl.setBiometrics),
          ListTile(
            leading: const IconBadge(Icons.devices_rounded, size: 38, color: Palette.sea),
            title: Text(context.tr('settings.devices')),
            subtitle: Text(context.tr('settings.devices_body')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/devices'),
          ),
          ListTile(
            leading: const IconBadge(Icons.phonelink_erase_rounded, size: 38, color: Palette.danger),
            title: Text(context.tr('settings.sign_out_all')),
            subtitle: Text(context.tr('settings.sign_out_all_body')),
            onTap: () async {
              if (await confirmAction(context, title: context.tr('settings.sign_out_all'), message: context.tr('settings.sign_out_all_body'), danger: true, icon: Icons.phonelink_erase_rounded)) {
                await ref.read(sessionProvider.notifier).signOut(everywhere: true);
              }
            },
          ),
        ]),
        _group(context, context.tr('settings.about'), [
          ListTile(leading: const IconBadge(Icons.info_rounded, size: 38, color: Palette.navySoft), title: Text(context.tr('settings.version')), trailing: Text(ref.watch(_versionProvider).valueOrNull ?? '')),
          ListTile(leading: const IconBadge(Icons.dns_rounded, size: 38, color: Palette.navySoft), title: Text(context.tr('settings.server')), subtitle: Text(session.server)),
          if (Env.envName.isNotEmpty) ListTile(leading: const IconBadge(Icons.science_rounded, size: 38, color: Palette.warning), title: Text(context.tr('settings.environment')), trailing: const Text(Env.envName)),
          ListTile(leading: const IconBadge(Icons.privacy_tip_rounded, size: 38, color: Palette.success), title: Text(context.tr('settings.privacy')), subtitle: Text(context.tr('settings.privacy_body'))),
          ListTile(leading: const IconBadge(Icons.photo_outlined, size: 38, color: Palette.navySoft), title: Text(context.tr('about.photo'), style: Theme.of(context).textTheme.bodySmall)),
        ]),
      ],
    );
  }

  Widget _group(BuildContext context, String title, List<Widget> tiles) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 8), child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          Card(child: Column(children: tiles)),
        ]),
      );
}

class _BiometricTile extends StatefulWidget {
  const _BiometricTile({required this.on, required this.onChanged});
  final bool on;
  final Future<void> Function(bool) onChanged;

  @override
  State<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends State<_BiometricTile> {
  final _bio = Biometrics();
  bool? _available;

  @override
  void initState() {
    super.initState();
    _bio.available().then((v) {
      if (mounted) setState(() => _available = v);
    });
  }

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        secondary: const IconBadge(Icons.fingerprint_rounded, size: 38),
        title: Text(context.tr('settings.biometrics')),
        subtitle: Text(context.tr(_available == false ? 'settings.biometrics_none' : 'settings.biometrics_body')),
        value: widget.on && _available != false,
        onChanged: _available != true
            ? null
            : (v) async {
                // confirm with the OS before turning it on, so the person knows it works on this phone
                if (v && !await _bio.unlock(context.tr('lock.reason'))) return;
                await widget.onChanged(v);
              },
      );
}

/// Devices signed in to this account; any of them can be signed out from here.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  late Future<List<Map<String, dynamic>>> _f = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final r = await ref.read(apiProvider).get('auth/devices');
    return r.list;
  }

  @override
  Widget build(BuildContext context) {
    return ModulePage(
      title: context.tr('settings.devices'),
      subtitle: context.tr('settings.devices_body'),
      icon: Icons.devices_rounded,
      onRefresh: () async => setState(() => _f = _load()),
      children: [
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _f,
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => setState(() => _f = _load()));
            if (!snap.hasData) return const SkeletonList(count: 3);
            final current = ref.read(sessionProvider.notifier).tokenId;
            final list = [for (final d in snap.data!) {...d, 'current': '${d['id']}' == current}];
            if (list.isEmpty) return EmptyView(title: context.tr('empty'));
            return Column(children: [
              for (final d in list)
                ListRow(
                  icon: (str(d['name']) ?? '').contains('iPhone') ? Icons.phone_iphone_rounded : Icons.phone_android_rounded,
                  iconColor: d['current'] == true ? Palette.success : Palette.navySoft,
                  title: str(d['name']) ?? context.tr('settings.device'),
                  subtitle: [if (d['current'] == true) context.tr('settings.this_device'), if (d['last_used_at'] != null) '${context.tr('settings.last_used')} ${Fmt.dateTime(date(d['last_used_at']), context.lang)}'].join(' · '),
                  trailing: d['current'] == true
                      ? const StatusChip('active')
                      : IconButton(
                          tooltip: context.tr('settings.sign_out_device'),
                          icon: const Icon(Icons.logout_rounded, color: Palette.danger),
                          onPressed: () async {
                            if (!await confirmAction(context, title: context.tr('settings.sign_out_device'), message: str(d['name']), danger: true)) return;
                            try {
                              await ref.read(apiProvider).delete('auth/devices/${d['id']}');
                              setState(() => _f = _load());
                            } on ApiException catch (e) {
                              if (context.mounted) Toast.error(context, e);
                            }
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
