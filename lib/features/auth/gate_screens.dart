import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/biometrics.dart';
import '../../core/auth/session_controller.dart';
import '../../core/config/env.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/doha_skyline.dart';
import '../../core/widgets/ui.dart';
import 'auth_scaffold.dart';

/// First frame while the bootstrap call runs.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Palette.midnight,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: Palette.nightGradient),
          child: Stack(children: [
            const Align(alignment: Alignment.bottomCenter, child: DohaSkyline(height: 360)),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const BrandMark(size: 84),
                const SizedBox(height: 18),
                Text.rich(
                  const TextSpan(children: [
                    TextSpan(text: 'OneSource ', style: TextStyle(color: Colors.white)),
                    TextSpan(text: 'Connect', style: TextStyle(color: Palette.gold)),
                  ]),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 28),
                const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.6, color: Palette.goldSoft)),
              ]),
            ),
          ]),
        ),
      );
}

/// Update required, maintenance or no connection: a full-screen message with one clear action.
class GateScreen extends ConsumerWidget {
  const GateScreen({super.key, required this.phase});
  final Phase phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final (icon, title, body) = switch (phase) {
      Phase.update => (Icons.system_update_rounded, context.tr('gate.update_title'), context.tr('gate.update_body')),
      Phase.maintenance => (Icons.construction_rounded, context.tr('gate.maintenance_title'), context.tr('gate.maintenance_body')),
      _ => (
          (s.error?.isOffline ?? true) ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
          context.tr((s.error?.isOffline ?? true) ? 'error.offline' : 'error.title'),
          s.error?.message ?? context.tr('error.generic')
        ),
    };
    return AuthScaffold(
      title: title,
      subtitle: body,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: IconBadge(icon, size: 72)),
        const SizedBox(height: 20),
        if (phase == Phase.update)
          BusyButton(
            label: context.tr('gate.open_store'),
            icon: Icons.open_in_new_rounded,
            onPressed: () async {
              final ios = Theme.of(context).platform == TargetPlatform.iOS;
              final uri = Uri.parse(ios
                  ? (Env.iosAppId.isNotEmpty ? 'https://apps.apple.com/app/id${Env.iosAppId}' : 'https://apps.apple.com/search?term=OneSource%20Connect')
                  : 'https://play.google.com/store/apps/details?id=${Env.androidPackage}');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          )
        else
          BusyButton(label: context.tr('retry'), icon: Icons.refresh_rounded, onPressed: () => ref.read(sessionProvider.notifier).start()),
        if (s.boot?.supportPhone != null) ...[
          const SizedBox(height: 10),
          BusyButton(
            outlined: true,
            label: context.tr('gate.call_office'),
            icon: Icons.call_rounded,
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: s.boot!.supportPhone)),
          ),
        ],
      ]),
    );
  }
}

/// Only shown when the build has no ERP address, or custom servers are allowed (demo builds).
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final _server = TextEditingController(text: Env.baseUrl);
  final _company = TextEditingController(text: Env.companyCode);

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: context.tr('connect.title'),
        subtitle: context.tr('connect.body'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _server,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(labelText: context.tr('connect.server'), hintText: 'https://demoagent.onesourceerp.com', prefixIcon: const Icon(Icons.dns_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _company,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: context.tr('auth.company_code'), prefixIcon: const Icon(Icons.apartment_rounded)),
          ),
          const SizedBox(height: 20),
          BusyButton(
            label: context.tr('continue'),
            icon: Icons.arrow_forward_rounded,
            onPressed: _server.text.trim().isEmpty && Env.baseUrl.isEmpty ? null : () => ref.read(sessionProvider.notifier).connect(_server.text, _company.text),
          ),
        ]),
      );
}

/// Several companies/records are linked to this phone: pick one. Shown only when there is more than one.
class WorkspaceChooser extends ConsumerWidget {
  const WorkspaceChooser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).me;
    final list = me?.workspaces ?? const [];
    return AuthScaffold(
      title: context.tr('workspace.title'),
      subtitle: context.tr('workspace.body'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, w) in list.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _WorkspaceTile(
              index: i,
              title: w.company,
              subtitle: '${context.tr('workspace.kind.${w.kind}')} · ${w.companyCode}',
              icon: w.kind == 'customer' ? Icons.family_restroom_rounded : Icons.engineering_rounded,
              onTap: () async {
                try {
                  await ref.read(sessionProvider.notifier).switchWorkspace(w.id);
                } on ApiException catch (e) {
                  if (context.mounted) Toast.error(context, e);
                }
              },
            ),
          ),
        TextButton(onPressed: () => ref.read(sessionProvider.notifier).signOut(), child: Text(context.tr('settings.sign_out'))),
      ]),
    );
  }
}

class _WorkspaceTile extends StatefulWidget {
  const _WorkspaceTile({required this.index, required this.title, required this.subtitle, required this.icon, required this.onTap});
  final int index;
  final String title, subtitle;
  final IconData icon;
  final Future<void> Function() onTap;

  @override
  State<_WorkspaceTile> createState() => _WorkspaceTileState();
}

class _WorkspaceTileState extends State<_WorkspaceTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  await widget.onTap();
                  if (mounted) setState(() => _busy = false);
                },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              IconBadge(widget.icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(widget.subtitle, style: TextStyle(color: Theme.of(context).hintColor)),
                ]),
              ),
              _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        ),
      );
}

/// Biometric unlock of an existing session. The fallback is a normal sign-out and sign-in.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _bio = Biometrics();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final ok = await _bio.unlock(translate(Localizations.localeOf(context).languageCode, 'lock.reason'));
    if (ok && mounted) ref.read(sessionProvider.notifier).unlocked();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider).me;
    return AuthScaffold(
      title: context.tr('lock.title', {'name': me?.name.split(' ').first ?? ''}),
      subtitle: context.tr('lock.body'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _unlock,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: Palette.heroGradient, boxShadow: [BoxShadow(color: Palette.maroon.withValues(alpha: .4), blurRadius: 24)]),
              child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 52),
            ),
          ),
        ),
        const SizedBox(height: 20),
        BusyButton(label: context.tr('lock.unlock'), icon: Icons.lock_open_rounded, onPressed: _unlock),
        const SizedBox(height: 8),
        TextButton(onPressed: () => ref.read(sessionProvider.notifier).signOut(), child: Text(context.tr('lock.use_password'))),
      ]),
    );
  }
}

/// Signed in with a phone but no record is linked yet: enter the invitation code from the office.
class PendingScreen extends ConsumerStatefulWidget {
  const PendingScreen({super.key});

  @override
  ConsumerState<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends ConsumerState<PendingScreen> {
  final _code = TextEditingController();
  String? _status;

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: context.tr('pending.title'),
        subtitle: context.tr(_status == 'pending' ? 'auth.claim_pending' : 'pending.body'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: context.tr('auth.invite_code'), prefixIcon: const Icon(Icons.confirmation_number_rounded)),
          ),
          const SizedBox(height: 16),
          BusyButton(
            label: context.tr('pending.link'),
            icon: Icons.link_rounded,
            onPressed: () async {
              try {
                final st = await ref.read(sessionProvider.notifier).claim(_code.text.trim());
                if (mounted) setState(() => _status = st);
              } on ApiException catch (e) {
                if (context.mounted) Toast.error(context, e);
              }
            },
          ),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: () => ref.read(sessionProvider.notifier).refreshMe(), icon: const Icon(Icons.refresh_rounded), label: Text(context.tr('pending.check'))),
          TextButton(onPressed: () => ref.read(sessionProvider.notifier).signOut(), child: Text(context.tr('settings.sign_out'))),
        ]),
      );
}
