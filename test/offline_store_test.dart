import 'package:flutter_test/flutter_test.dart';
import 'package:onesource_connect/core/offline/offline_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('drafts and outbox survive a restart and are wiped on sign-out', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OfflineStore(await SharedPreferences.getInstance());

    await store.saveDraft('case.1', 'Hello');
    expect(store.draft('case.1'), 'Hello');
    await store.saveDraft('case.1', '   ');
    expect(store.draft('case.1'), isNull);

    await store.enqueue(OutboxItem(key: 'k1', path: 'trips/TR-1/status', body: {'status': 'arrived'}, label: 'TR-1 · Arrived'));
    await store.enqueue(OutboxItem(key: 'k1', path: 'trips/TR-1/status', body: {'status': 'arrived'}, label: 'TR-1 · Arrived'));
    expect(store.outbox.length, 1, reason: 'the same tap is queued once');
    expect(store.outbox.single.body['status'], 'arrived');

    await store.saveDraft('newcase.body', 'text');
    await store.wipe();
    expect(store.outbox, isEmpty);
    expect(store.draft('newcase.body'), isNull);
  });
}
