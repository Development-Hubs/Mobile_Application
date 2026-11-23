import 'package:flutter/material.dart';

import '../../core/auth/models.dart';
import '../../core/theme/palette.dart';

/// A module the signed-in person may open. [route] = built in the app; null = opens the ERP website.
class AppModule {
  const AppModule(this.key, this.icon, this.color, {this.route, this.group = 'work'});
  final String key;
  final IconData icon;
  final Color color;
  final String? route;
  final String group;

  bool get native => route != null;
  String get titleKey => 'module.$key';
  String get bodyKey => 'module.$key.body';
}

/// Every entry is decided by `GET me` (permissions, areas, modules) — never by a role chosen on the device.
/// The server still checks each call; hiding a tile is only a convenience.
List<AppModule> modulesFor(Me me) {
  if (!me.isStaff) {
    return [
      const AppModule('my_overview', Icons.dashboard_customize_rounded, Palette.maroon, route: '/home', group: 'mine'),
      const AppModule('support', Icons.support_agent_rounded, Palette.sea, route: '/help', group: 'mine'),
      const AppModule('learning', Icons.school_rounded, Palette.gold, route: '/learning', group: 'mine'),
      const AppModule('calendar', Icons.event_rounded, Palette.info, route: '/calendar', group: 'mine'),
      const AppModule('notifications', Icons.notifications_rounded, Palette.navySoft, route: '/inbox', group: 'mine'),
    ];
  }

  final list = <AppModule>[
    if (me.attendance) const AppModule('attendance', Icons.fingerprint_rounded, Palette.maroon, route: '/attendance', group: 'me'),
    const AppModule('calendar', Icons.event_rounded, Palette.info, route: '/calendar', group: 'me'),
    const AppModule('notifications', Icons.notifications_rounded, Palette.navySoft, route: '/inbox', group: 'me'),
    if (me.area('support')) const AppModule('support', Icons.support_agent_rounded, Palette.sea, route: '/help'),
    if (me.area('renewals')) const AppModule('renewals', Icons.autorenew_rounded, Palette.warning, route: '/renewals'),
    if (me.area('care')) const AppModule('care', Icons.favorite_rounded, Palette.danger, route: '/care'),
    if (me.area('accommodation') && me.modules.contains('accommodation')) const AppModule('accommodation', Icons.bed_rounded, Palette.navySoft, route: '/beds'),
    if (me.driver && me.modules.contains('dispatch')) const AppModule('driver', Icons.local_shipping_rounded, Palette.success, route: '/trips'),
    if (me.area('training') && me.modules.contains('training')) const AppModule('trainer', Icons.co_present_rounded, Palette.gold, route: '/trainer'),
    if (me.attendance && (me.can('hrm.view') || me.can('hrm.edit'))) const AppModule('team_attendance', Icons.groups_rounded, Palette.maroonBright, route: '/team'),
    if (me.modules.contains('training') && me.can('training.assess')) const AppModule('assessor', Icons.fact_check_rounded, Palette.sea, route: '/assessor'),
    if (me.modules.contains('training') && me.can('training.approve')) const AppModule('training_approvals', Icons.how_to_reg_rounded, Palette.warning, route: '/training-approvals'),
  ];

  // Modules that exist in the ERP but have no mobile screens yet: opened in the browser, clearly labelled.
  const web = {
    'crm': Icons.handshake_rounded,
    'finance': Icons.account_balance_rounded,
    'hrm': Icons.groups_rounded,
    'outside': Icons.flight_land_rounded,
    'package1': Icons.home_work_rounded,
    'package2': Icons.calendar_month_rounded,
    'network': Icons.hub_rounded,
    'gm': Icons.insights_rounded,
    'chatbot': Icons.smart_toy_rounded,
    'dispatch': Icons.route_rounded,
    'accommodation': Icons.apartment_rounded,
    'training': Icons.menu_book_rounded,
    'events': Icons.celebration_rounded,
  };
  for (final m in me.modules) {
    final icon = web[m];
    if (icon != null) list.add(AppModule('web.$m', icon, Palette.navy, group: 'web'));
  }
  return list;
}
