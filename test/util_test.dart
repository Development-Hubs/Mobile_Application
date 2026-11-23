import 'package:flutter_test/flutter_test.dart';
import 'package:onesource_connect/core/util/format.dart';
import 'package:onesource_connect/core/util/json.dart';

void main() {
  test('versionBelow compares dotted versions', () {
    expect(versionBelow('1.0.0', '1.0.1'), isTrue);
    expect(versionBelow('1.2.0', '1.10.0'), isTrue);
    expect(versionBelow('2.0.0+5', '1.9.9'), isFalse);
    expect(versionBelow('1.0.0', '1.0.0'), isFalse);
    expect(versionBelow('1.0', '1.0.0'), isFalse);
  });

  test('durations', () {
    expect(Fmt.clock(3725), '01:02:05');
    expect(Fmt.hm(3 * 3600 + 25 * 60), '3h 25m');
    expect(Fmt.hm(59), '0m');
    expect(Fmt.hm(-10), '0m');
  });

  test('forgiving json readers', () {
    expect(str(''), isNull);
    expect(integer('12'), 12);
    expect(flag(1), isTrue);
    expect(maps([{'a': 1}, 'x']).length, 1);
  });
}
