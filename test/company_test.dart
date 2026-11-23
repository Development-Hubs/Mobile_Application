import 'package:flutter_test/flutter_test.dart';
import 'package:onesource_connect/core/auth/session_controller.dart';

void main() {
  test('company comes from the ERP subdomain, never from the person', () {
    expect(companyFromServer('https://demoagent.onesourceerp.com'), 'demoagent');
    expect(companyFromServer('demoagent.onesourceerp.com/'), 'demoagent');
    expect(companyFromServer('https://onesourceerp.com'), '');
    expect(companyFromServer('https://www.onesourceerp.com'), '');
    expect(companyFromServer('https://10.0.2.2:8000'), '');
  });
}
