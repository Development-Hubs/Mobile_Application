import '../util/json.dart';

/// `GET bootstrap` — app gate (versions, maintenance) and company branding.
class Bootstrap {
  Bootstrap(this.raw);
  final Map<String, dynamic> raw;

  String get minClientVersion => str(raw['min_client_version']) ?? '0.0.0';
  Map<String, dynamic>? get company => raw['company'] is Map ? Map<String, dynamic>.from(raw['company'] as Map) : null;
  bool get maintenance => company?['maintenance'] == true;
  String? get companyName => str(company?['name']);
  String? get supportPhone => str(company?['support_phone']);
  String? get logo => str(company?['logo']);
  bool feature(String key) => (company?['features'] is Map) ? (company!['features'] as Map)[key] != false : true;
}

class Workspace {
  Workspace(this.raw);
  final Map<String, dynamic> raw;
  int get id => (raw['id'] as num).toInt();
  String get kind => str(raw['kind']) ?? '';
  String get company => str(raw['company']) ?? '';
  String get companyCode => str(raw['company_code']) ?? '';
  String? get recordType => str(raw['record_type']);
}

/// `GET me` — who is signed in. Every menu is built from this server answer, never from a choice made on the device.
class Me {
  Me(this.raw);
  final Map<String, dynamic> raw;

  /// staff | customer | worker | pending
  String get type => str(raw['type']) ?? 'pending';
  bool get isStaff => type == 'staff';
  bool get isCustomer => type == 'customer';
  bool get isWorker => type == 'worker';
  bool get isPending => type == 'pending';

  String get name => str(raw['name']) ?? '';
  String? get email => str(raw['email']);
  String? get phone => str(raw['phone']);

  /// Customers / candidates who signed in with email + password must confirm their mobile number first.
  /// Staff, and servers that do not send the field, count as verified.
  bool get phoneVerified => isStaff || raw['phone_verified'] != false;
  String? get jobTitle => str(raw['job_title']);
  bool get owner => raw['owner'] == true;
  bool get driver => raw['driver'] == true;
  bool get mfa => raw['mfa'] == true;
  bool get attendance => raw['attendance'] == true;
  int get pendingRequests => (raw['requests'] as num?)?.toInt() ?? 0;
  String? get webUrl => str(raw['web_url']);
  String? get dataScope => str(raw['data_scope']);

  Map<String, dynamic> get company => raw['company'] is Map ? Map<String, dynamic>.from(raw['company'] as Map) : const {};
  String get companyName => str(company['name']) ?? '';
  String? get companyKind => str(company['kind']);
  String? get timezone => str(company['timezone']);

  Set<String> get permissions => strList(raw['permissions']).toSet();
  Set<String> get areas => strList(raw['areas']).toSet();
  Set<String> get modules => strList(raw['modules']).toSet();

  bool can(String permission) => owner || permissions.contains(permission);
  bool area(String key) => areas.contains(key);

  Map<String, dynamic>? get record => raw['record'] is Map ? Map<String, dynamic>.from(raw['record'] as Map) : null;
  List<Workspace> get workspaces => (raw['workspaces'] is List) ? (raw['workspaces'] as List).whereType<Map>().map((e) => Workspace(Map<String, dynamic>.from(e))).toList() : const [];

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '•';
    String first(String p) => String.fromCharCode(p.runes.first);
    return (first(parts.first) + (parts.length > 1 ? first(parts.last) : '')).toUpperCase();
  }
}
