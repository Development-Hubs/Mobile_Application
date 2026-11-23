import 'package:flutter/widgets.dart';

import 'strings_ar.dart';
import 'strings_en.dart';

const supportedLocales = [Locale('en'), Locale('ar')];

/// Looks up an interface string in the current language. `{name}` placeholders are filled from [args].
String translate(String languageCode, String key, [Map<String, Object?> args = const {}]) {
  final table = languageCode == 'ar' ? stringsAr : stringsEn;
  var s = table[key] ?? stringsEn[key] ?? key;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
  return s;
}

extension Tr on BuildContext {
  String tr(String key, [Map<String, Object?> args = const {}]) => translate(Localizations.localeOf(this).languageCode, key, args);
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
  String get lang => Localizations.localeOf(this).languageCode;
}
