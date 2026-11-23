import 'package:flutter_test/flutter_test.dart';
import 'package:onesource_connect/core/auth/models.dart';
import 'package:onesource_connect/features/modules/module_registry.dart';

void main() {
  test('staff modules come only from the server answer', () {
    final plain = Me({'type': 'staff', 'areas': <String>[], 'modules': ['crm'], 'attendance': false});
    final keys = modulesFor(plain).map((m) => m.key).toList();
    expect(keys, isNot(contains('renewals')));
    expect(keys, isNot(contains('attendance')));
    expect(keys, contains('web.crm'));

    final agent = Me({'type': 'staff', 'areas': ['renewals', 'support'], 'modules': ['hrm'], 'attendance': true, 'driver': false});
    final k2 = modulesFor(agent).map((m) => m.key).toList();
    expect(k2, containsAll(['attendance', 'renewals', 'support']));
    expect(k2, isNot(contains('driver')));
  });

  test('customers and workers get their own services only', () {
    final worker = Me({'type': 'worker', 'areas': ['renewals']});
    final keys = modulesFor(worker).map((m) => m.key).toSet();
    expect(keys, containsAll({'my_overview', 'support', 'learning', 'calendar'}));
    expect(keys.contains('renewals'), isFalse);
  });
}
