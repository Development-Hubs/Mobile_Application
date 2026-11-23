import 'package:flutter_test/flutter_test.dart';
import 'package:onesource_connect/core/i18n/i18n.dart';
import 'package:onesource_connect/core/i18n/strings_ar.dart';
import 'package:onesource_connect/core/i18n/strings_en.dart';

void main() {
  test('every English string has an Arabic translation with the same placeholders', () {
    final ph = RegExp(r'\{(\w+)\}');
    Set<String> holders(String s) => ph.allMatches(s).map((m) => m.group(1)!).toSet();
    expect(stringsAr.keys.toSet(), stringsEn.keys.toSet());
    for (final k in stringsEn.keys) {
      expect(holders(stringsAr[k]!), holders(stringsEn[k]!), reason: k);
    }
  });

  test('translate fills placeholders and falls back to the key', () {
    expect(translate('en', 'auth.welcome_to', {'company': 'Rozana'}), 'Welcome to Rozana');
    expect(translate('ar', 'auth.welcome_to', {'company': 'روزانا'}), 'أهلاً بك في روزانا');
    expect(translate('en', 'no.such.key'), 'no.such.key');
  });
}
