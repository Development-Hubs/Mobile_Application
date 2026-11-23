// Fails when English and Arabic strings differ in keys or {placeholders}. Run: dart run tool/check_strings.dart
import 'dart:io';

import 'package:onesource_connect/core/i18n/strings_ar.dart';
import 'package:onesource_connect/core/i18n/strings_en.dart';

void main() {
  final problems = <String>[];
  final ph = RegExp(r'\{(\w+)\}');
  Set<String> holders(String s) => ph.allMatches(s).map((m) => m.group(1)!).toSet();
  for (final k in stringsEn.keys) {
    final ar = stringsAr[k];
    if (ar == null) {
      problems.add('missing Arabic: $k');
    } else if (holders(ar).difference(holders(stringsEn[k]!)).isNotEmpty || holders(stringsEn[k]!).difference(holders(ar)).isNotEmpty) {
      problems.add('placeholders differ: $k');
    }
  }
  for (final k in stringsAr.keys) {
    if (!stringsEn.containsKey(k)) problems.add('missing English: $k');
  }
  if (problems.isNotEmpty) {
    stderr.writeln(problems.join('\n'));
    exit(1);
  }
  stdout.writeln('strings ok: ${stringsEn.length} keys in English and Arabic');
}
