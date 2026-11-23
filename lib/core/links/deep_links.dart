/// Turns a OneSource link into an in-app route. Used for notification taps, push taps and links opened
/// from outside the app (`onesource://…` or `https://<erp>/app/connect/…`).
///
/// Supported: `cases/{id}`, `trips/{reference}`, `attendance`, `notifications`, `learning`, `calendar`.
/// Anything else returns null and the app simply opens. The record itself is always loaded from the ERP,
/// so a link to something the person may no longer see shows "not available".
String? routeForLink(String? link) {
  if (link == null || link.isEmpty) return null;
  final uri = Uri.tryParse(link);
  if (uri == null) return null;
  List<String> seg;
  if (uri.scheme == 'onesource') {
    seg = [uri.host, ...uri.pathSegments].where((s) => s.isNotEmpty).toList();
  } else if (uri.scheme == 'https') {
    final p = uri.pathSegments;
    final i = p.indexOf('connect');
    if (i < 0) return null;
    seg = p.sublist(i + 1);
  } else {
    return null;
  }
  if (seg.isEmpty) return null;
  switch (seg.first) {
    case 'cases':
      return seg.length >= 2 ? '/cases/${Uri.encodeComponent(seg[1])}' : '/help';
    case 'trips':
      return '/trips';
    case 'attendance':
      return '/attendance';
    case 'notifications':
      return '/inbox';
    case 'learning':
      return '/learning';
    case 'calendar':
      return '/calendar';
  }
  return null;
}
