import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accommodation/beds_screen.dart';
import '../../features/attendance/attendance_month_screen.dart';
import '../../features/attendance/attendance_screen.dart';
import '../../features/attendance/team_screen.dart';
import '../../features/auth/gate_screens.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/care/care_screen.dart';
import '../../features/cases/case_detail_screen.dart';
import '../../features/cases/cases_screen.dart';
import '../../features/cases/new_case_screen.dart';
import '../../features/driver/driver_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/modules/more_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/portal/portal_screens.dart';
import '../../features/renewals/renewals_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/training/learning_screen.dart';
import '../../features/training/training_extra.dart';
import '../auth/session_controller.dart';
import '../theme/motion.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Where each session phase lives. Signed-in routes are reachable only in [Phase.signedIn].
String? _gate(SessionState s, String loc) {
  String only(String path) => loc == path ? '' : path;
  switch (s.phase) {
    case Phase.loading:
      return only('/splash');
    case Phase.connect:
      return only('/connect');
    case Phase.update:
    case Phase.maintenance:
    case Phase.offline:
      return only('/gate');
    case Phase.locked:
      return only('/lock');
    case Phase.chooseWorkspace:
      return only('/workspaces');
    case Phase.signedOut:
      return const {'/sign-in', '/otp', '/register'}.contains(loc) ? '' : '/sign-in';
    case Phase.signedIn:
      if (s.me?.isPending ?? false) return only('/pending');
      const outside = {'/splash', '/connect', '/gate', '/lock', '/workspaces', '/sign-in', '/otp', '/register', '/pending'};
      return outside.contains(loc) ? '/home' : '';
  }
}

/// Signed-in pages that require a server-granted capability; anything else answers with the home screen.
bool _allowed(SessionState s, String loc) {
  final me = s.me;
  if (me == null) return false;
  bool starts(String p) => loc == p || loc.startsWith('$p/');
  if (starts('/attendance')) return me.attendance;
  if (starts('/renewals')) return me.area('renewals');
  if (starts('/care')) return me.area('care');
  if (starts('/beds')) return me.area('accommodation');
  if (starts('/trips')) return me.driver;
  if (starts('/trainer')) return me.area('training');
  if (starts('/learning')) return !me.isStaff;
  if (starts('/invoices') || starts('/agreements') || starts('/shortlists')) return me.isCustomer;
  if (starts('/salaries')) return me.isWorker;
  if (starts('/team')) return me.attendance && (me.can('hrm.view') || me.can('hrm.edit'));
  if (starts('/assessor')) return me.modules.contains('training') && me.can('training.assess');
  if (starts('/training-approvals')) return me.modules.contains('training') && me.can('training.approve');
  return true;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  Page<void> fade(BuildContext context, GoRouterState state, Widget child) => CustomTransitionPage(
        key: state.pageKey,
        child: child,
        transitionDuration: MotionScope.duration(context, const Duration(milliseconds: 380)),
        transitionsBuilder: (context, a, __, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
      );

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      final target = _gate(s, loc);
      if (target != null && target.isNotEmpty) return target;
      if (s.phase == Phase.signedIn && !_allowed(s, loc)) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', pageBuilder: (c, s) => fade(c, s, const SplashScreen())),
      GoRoute(path: '/connect', pageBuilder: (c, s) => fade(c, s, const ConnectScreen())),
      GoRoute(path: '/gate', pageBuilder: (c, s) => fade(c, s, Consumer(builder: (_, ref, __) => GateScreen(phase: ref.watch(sessionProvider).phase)))),
      GoRoute(path: '/sign-in', pageBuilder: (c, s) => fade(c, s, const SignInScreen())),
      GoRoute(
        path: '/otp',
        builder: (c, s) {
          final x = (s.extra as Map?) ?? const {};
          return OtpScreen(
            phone: '${x['phone'] ?? ''}',
            invite: '${x['invite'] ?? ''}',
            delivery: '${x['delivery'] ?? 'sms'}',
            ttl: (x['ttl'] as int?) ?? 300,
            registerName: x['registerName'] as String?,
            registerEmail: (x['registerEmail'] as String?) ?? '',
          );
        },
      ),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/lock', pageBuilder: (c, s) => fade(c, s, const LockScreen())),
      GoRoute(path: '/workspaces', pageBuilder: (c, s) => fade(c, s, const WorkspaceChooser())),
      GoRoute(path: '/pending', pageBuilder: (c, s) => fade(c, s, const PendingScreen())),
      StatefulShellRoute.indexedStack(
        builder: (c, s, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/help', builder: (_, __) => const CasesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/inbox', builder: (_, __) => const NotificationsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/more', builder: (_, __) => const MoreScreen())]),
        ],
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/attendance', builder: (_, __) => const AttendanceScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/attendance/month', builder: (_, __) => const AttendanceMonthScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/attendance/corrections', builder: (_, s) => CorrectionsScreen(forDate: s.extra as String?)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/cases/new', builder: (_, s) => NewCaseScreen(prefill: s.extra is CasePrefill ? s.extra as CasePrefill : null)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/cases/:id', builder: (_, s) => CaseDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/renewals', builder: (_, __) => const RenewalsScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/care', builder: (_, __) => const CareScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/beds', builder: (_, __) => const BedsScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/trips', builder: (_, __) => const DriverScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/learning', builder: (_, __) => const LearningScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/trainer', builder: (_, __) => const TrainerScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/team', builder: (_, s) => TeamAttendanceScreen(approvals: s.uri.queryParameters['tab'] == 'approvals')),
      GoRoute(parentNavigatorKey: _rootKey, path: '/assessor', builder: (_, __) => const AssessorScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/training-approvals', builder: (_, __) => const TrainingApprovalsScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/invoices', builder: (_, __) => const InvoicesScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/salaries', builder: (_, __) => const SalariesScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/agreements', builder: (_, __) => const AgreementsScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/shortlists', builder: (_, __) => const ShortlistsScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/calendar', builder: (_, __) => const CalendarScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/devices', builder: (_, __) => const DevicesScreen()),
    ],
  );
});
