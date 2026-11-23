import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/api_result.dart';
import '../../core/auth/session_controller.dart';
import '../../core/util/json.dart';

/// Today's attendance as answered by the ERP, plus the company rules in `meta`.
class AttendanceDay {
  AttendanceDay(this.data, this.rules, {DateTime? fetchedAt}) : fetchedAt = fetchedAt ?? DateTime.now();
  final Map<String, dynamic> data;
  final Map<String, dynamic> rules;
  final DateTime fetchedAt;

  bool get linked => data['linked'] != false;
  String get state => str(data['state']) ?? 'off'; // off | in | break | out
  List<String> get actions => strList(data['actions']);
  int get workedSeconds => integer(data['worked_seconds']) ?? 0;
  int get breakSeconds => integer(data['break_seconds']) ?? 0;
  int get breakAllowance => integer(data['break_allowance_seconds']) ?? 0;
  int get targetSeconds => integer(data['target_seconds']) ?? 8 * 3600;
  int get lateMinutes => integer(data['late_minutes']) ?? 0;
  int get earlyMinutes => integer(data['early_minutes']) ?? 0;
  int get breaks => integer(data['breaks']) ?? 0;
  String? get firstIn => str(data['first_in']);
  String? get lastOut => str(data['last_out']);
  String? get shiftStart => str(data['shift_start']);
  String? get shiftEnd => str(data['shift_end']);
  bool get dayOff => flag(data['day_off']);
  bool get onLeave => flag(data['on_leave']);
  bool get missingOut => flag(data['missing_out']);
  bool get away => flag(data['away']);
  List<Map<String, dynamic>> get timeline => maps(data['timeline']);

  bool get needsLocation => flag(rules['needs_location']);
  String? get where => str(rules['where']);
  int get maxBreaks => integer(rules['max_breaks']) ?? 0;

  /// Seconds worked now, counting time since the answer while checked in.
  int liveWorked(DateTime now) => state == 'in' ? workedSeconds + now.difference(fetchedAt).inSeconds : workedSeconds;
  int liveBreak(DateTime now) => state == 'break' ? breakSeconds + now.difference(fetchedAt).inSeconds : breakSeconds;
}

class AttendanceController extends AutoDisposeAsyncNotifier<AttendanceDay> {
  ApiClient get _api => ref.read(apiProvider);

  @override
  Future<AttendanceDay> build() async {
    ref.watch(epochProvider);
    final r = await _api.get('attendance/today');
    return AttendanceDay(r.map, obj(r.meta['rules'] ?? r.meta));
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(build);
  }

  /// Sends one punch. The UI shows success only after the ERP answers with the new day.
  Future<AttendanceDay> punch(String type, {String? note, required String idempotencyKey}) async {
    final rules = state.valueOrNull?.rules ?? const {};
    Position? pos;
    if (flag(rules['needs_location'])) pos = await currentPosition();
    final r = await _api.post('attendance/punch', idempotencyKey: idempotencyKey, body: {
      'type': type,
      if (pos != null) ...{'lat': pos.latitude, 'lng': pos.longitude, 'accuracy': pos.accuracy},
      if (note != null && note.isNotEmpty) 'note': note,
    });
    final day = AttendanceDay(r.map, rules);
    state = AsyncData(day);
    return day;
  }
}

final attendanceProvider = AutoDisposeAsyncNotifierProvider<AttendanceController, AttendanceDay>(AttendanceController.new);

final attendanceMonthProvider = FutureProvider.autoDispose.family<ApiResult, String>((ref, month) async {
  ref.watch(epochProvider);
  return ref.read(apiProvider).get('attendance/month', query: {'month': month});
});

final correctionsProvider = FutureProvider.autoDispose<ApiResult>((ref) async {
  ref.watch(epochProvider);
  return ref.read(apiProvider).get('attendance/corrections');
});

/// Asks for location permission only when the company requires location for attendance.
Future<Position> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw ApiException(code: 'location_off', message: 'Turn on location to record attendance.');
  }
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
  if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
    throw ApiException(code: 'location_denied', message: 'Your company records where attendance is marked. Allow location for OneSource Connect in Settings.');
  }
  return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
}
