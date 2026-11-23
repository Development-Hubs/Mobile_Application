/// Small, forgiving readers for JSON maps coming from the ERP.
String? str(dynamic v) => v == null ? null : (v is String ? (v.isEmpty ? null : v) : v.toString());

int? integer(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

double? dbl(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

bool flag(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

List<String> strList(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];

List<Map<String, dynamic>> maps(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

Map<String, dynamic> obj(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

DateTime? date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// Compares dotted versions: returns true when [current] is lower than [minimum].
bool versionBelow(String current, String minimum) {
  List<int> parts(String s) => s.split('+').first.split('.').map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
  final a = parts(current), b = parts(minimum);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x < y;
  }
  return false;
}
