import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onesource_connect/core/api/api_client.dart';
import 'package:onesource_connect/core/api/api_exception.dart';

/// Answers every request with a fixed status and JSON body, and remembers the request.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.status, this.body, {this.headers = const {}});
  final int status;
  final Object body;
  final Map<String, List<String>> headers;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...headers,
    });
  }

  @override
  void close({bool force = false}) {}
}

ApiClient client(FakeAdapter a) {
  final dio = Dio()..httpClientAdapter = a;
  return ApiClient(dio: dio)
    ..server = 'https://demoagent.onesourceerp.com'
    ..token = 'oc_test';
}

void main() {
  test('unwraps a successful envelope', () async {
    final a = FakeAdapter(200, {'ok': true, 'data': {'type': 'staff'}, 'meta': {'page': 1, 'last_page': 3}});
    final r = await client(a).get('me');
    expect(r.map['type'], 'staff');
    expect(r.hasMore, isTrue);
    expect(a.last!.uri.toString(), 'https://demoagent.onesourceerp.com/api/mobile/v1/me');
    expect(a.last!.headers['Authorization'], 'Bearer oc_test');
  });

  test('every change carries an Idempotency-Key, and the given key is reused', () async {
    final a = FakeAdapter(200, {'ok': true, 'data': {}, 'meta': {}}, headers: {'Idempotent-Replayed': ['true']});
    final c = client(a);
    final r = await c.post('attendance/punch', body: {'type': 'in'}, idempotencyKey: 'tap-1');
    expect(a.last!.headers['Idempotency-Key'], 'tap-1');
    expect(r.replayed, isTrue);
    await c.post('attendance/punch', body: {'type': 'in'});
    expect((a.last!.headers['Idempotency-Key'] as String).length, 36);
  });

  test('an error envelope becomes an ApiException with fields; never fake data', () async {
    final a = FakeAdapter(422, {
      'ok': false,
      'error': {'code': 'validation_failed', 'message': 'Check the form.', 'fields': {'subject': ['Required']}},
    });
    await expectLater(
      client(a).post('cases', body: {}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'validation_failed').having((e) => e.fieldError('subject'), 'field', 'Required')),
    );
  });

  test('a revoked token ends the session', () async {
    final a = FakeAdapter(401, {'ok': false, 'error': {'code': 'token_revoked', 'message': 'Signed out.'}});
    final c = client(a);
    ApiException? ended;
    c.onSessionEnded = (e) => ended = e;
    await expectLater(c.get('me'), throwsA(isA<ApiException>()));
    expect(ended?.code, 'token_revoked');
  });

  test('wrong MFA code does not end the session', () async {
    final a = FakeAdapter(401, {'ok': false, 'error': {'code': 'mfa_required', 'message': 'Enter the code.'}});
    final c = client(a);
    var ended = false;
    c.onSessionEnded = (_) => ended = true;
    await expectLater(c.post('auth/staff/login', body: {}), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'mfa_required')));
    expect(ended, isFalse);
  });
}
