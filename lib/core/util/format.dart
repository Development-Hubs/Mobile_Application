import 'package:intl/intl.dart';

/// Dates and times in the reader's language. Values from the ERP are ISO 8601.
class Fmt {
  const Fmt._();

  static String date(DateTime? d, String lang) => d == null ? '—' : DateFormat.yMMMd(lang).format(d);
  static String dayMonth(DateTime? d, String lang) => d == null ? '—' : DateFormat.MMMd(lang).format(d);
  static String weekday(DateTime? d, String lang) => d == null ? '—' : DateFormat.EEEE(lang).format(d);
  static String time(DateTime? d, String lang) => d == null ? '—' : DateFormat.jm(lang).format(d);
  static String dateTime(DateTime? d, String lang) => d == null ? '—' : '${DateFormat.MMMd(lang).format(d)} · ${DateFormat.jm(lang).format(d)}';
  static String month(DateTime d, String lang) => DateFormat.yMMMM(lang).format(d);

  /// "3h 25m" style durations from seconds.
  static String hm(int seconds, {String h = 'h', String m = 'm'}) {
    final s = seconds < 0 ? 0 : seconds;
    final hours = s ~/ 3600, minutes = (s % 3600) ~/ 60;
    return hours > 0 ? '$hours$h ${minutes.toString().padLeft(2, '0')}$m' : '$minutes$m';
  }

  /// HH:MM:SS for the live attendance clock.
  static String clock(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
  }

  /// "5 min ago", "yesterday" style relative time.
  static String ago(DateTime? d, String lang) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    final ar = lang == 'ar';
    if (diff.inMinutes < 1) return ar ? 'الآن' : 'now';
    if (diff.inMinutes < 60) return ar ? 'منذ ${diff.inMinutes} د' : '${diff.inMinutes}m';
    if (diff.inHours < 24) return ar ? 'منذ ${diff.inHours} س' : '${diff.inHours}h';
    if (diff.inDays < 7) return ar ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d';
    return dayMonth(d, lang);
  }

  static String humanize(String? s) {
    if (s == null || s.isEmpty) return '—';
    final t = s.replaceAll('_', ' ').replaceAll('-', ' ');
    return t[0].toUpperCase() + t.substring(1);
  }
}
