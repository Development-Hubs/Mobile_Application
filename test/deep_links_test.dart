import 'package:flutter_test/flutter_test.dart';
import 'package:onesource_connect/core/links/deep_links.dart';

void main() {
  test('maps OneSource links to in-app routes', () {
    expect(routeForLink('onesource://cases/9f1c-uuid'), '/cases/9f1c-uuid');
    expect(routeForLink('onesource://trips/TR-0042'), '/trips');
    expect(routeForLink('onesource://attendance'), '/attendance');
    expect(routeForLink('https://demoagent.onesourceerp.com/app/connect/cases/abc'), '/cases/abc');
    expect(routeForLink('https://example.com/whatever'), isNull);
    expect(routeForLink('javascript:alert(1)'), isNull);
    expect(routeForLink(null), isNull);
  });
}
