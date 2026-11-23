import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../config/env.dart';
import 'api_exception.dart';
import 'api_result.dart';

/// Talks to `/api/mobile/v1` and unwraps the `{ok, data, meta}` envelope.
///
/// * Every change (POST/PUT/DELETE) carries an `Idempotency-Key`. Callers create the key once per user
///   tap ([newKey]) and reuse it for every retry of that tap, so a lost answer never repeats an action.
/// * A token that expires within three days is renewed before the next call.
/// * Answers that end the session are reported through [onSessionEnded]; the client never falls back to
///   sample data.
class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30)
      ..sendTimeout = const Duration(seconds: 60)
      ..validateStatus = ((_) => true)
      ..responseType = ResponseType.json;
  }

  final Dio _dio;
  static const _uuid = Uuid();

  String server = Env.baseUrl;
  String? token;
  String locale = 'en';
  String appVersion = '1.0.0';

  /// Called when the ERP says the token is gone (signed out elsewhere, blocked, company unavailable…).
  void Function(ApiException error)? onSessionEnded;

  /// Called before a request when the token should be renewed; returns the new token or null.
  Future<String?> Function()? renewer;
  bool Function()? needsRenewal;
  Future<String?>? _renewing;

  static String newKey() => _uuid.v4();

  String get _base => '${server.replaceAll(RegExp(r'/+$'), '')}${Env.apiPrefix}';

  String url(String path) => path.startsWith('http') ? path : '$_base/${path.replaceFirst(RegExp(r'^/'), '')}';

  Map<String, String> get authHeaders => {
        if (token != null) 'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Accept-Language': locale,
        'X-Client-Version': appVersion,
        'X-Client-Platform': Platform.isIOS ? 'ios' : 'android',
      };

  Future<ApiResult> get(String path, {Map<String, dynamic>? query}) => _send('GET', path, query: query);

  Future<ApiResult> post(String path, {Object? body, String? idempotencyKey}) =>
      _send('POST', path, body: body, idempotencyKey: idempotencyKey ?? newKey());

  Future<ApiResult> put(String path, {Object? body, String? idempotencyKey}) =>
      _send('PUT', path, body: body, idempotencyKey: idempotencyKey ?? newKey());

  Future<ApiResult> delete(String path, {Object? body, String? idempotencyKey}) =>
      _send('DELETE', path, body: body, idempotencyKey: idempotencyKey ?? newKey());

  /// `multipart/form-data` upload. [files] are sent as `files[]` unless [fileField] is given.
  Future<ApiResult> upload(String path,
      {Map<String, dynamic> fields = const {}, List<File> files = const [], String fileField = 'files[]', String? idempotencyKey}) async {
    final form = FormData();
    fields.forEach((k, v) {
      if (v != null) form.fields.add(MapEntry(k, v.toString()));
    });
    for (final f in files) {
      form.files.add(MapEntry(fileField, await MultipartFile.fromFile(f.path, filename: f.uri.pathSegments.last)));
    }
    return _send('POST', path, body: form, idempotencyKey: idempotencyKey ?? newKey());
  }

  /// Downloads a private file (attachments, course materials) into [savePath] with the token.
  Future<void> download(String path, String savePath) async {
    await _maybeRenew();
    try {
      final r = await _dio.download(url(path), savePath, options: Options(headers: authHeaders, validateStatus: (s) => s != null && s < 400));
      if ((r.statusCode ?? 500) >= 400) throw ApiException(code: 'download_failed', message: 'The file could not be downloaded.', status: r.statusCode);
    } on DioException catch (e) {
      throw _transport(e);
    }
  }

  Future<ApiResult> _send(String method, String path, {Map<String, dynamic>? query, Object? body, String? idempotencyKey}) async {
    if (!path.startsWith('auth/token/renew')) await _maybeRenew();
    final headers = {...authHeaders, if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey};
    Response<dynamic> r;
    try {
      r = await _dio.request(url(path),
          data: body, queryParameters: query, options: Options(method: method, headers: headers, contentType: body is FormData ? null : Headers.jsonContentType));
    } on DioException catch (e) {
      throw _transport(e);
    }
    return _unwrap(r);
  }

  ApiResult _unwrap(Response<dynamic> r) {
    final status = r.statusCode ?? 0;
    final body = r.data;
    if (body is Map && body['ok'] == true) {
      return ApiResult(body['data'], body['meta'] is Map ? Map<String, dynamic>.from(body['meta'] as Map) : <String, dynamic>{},
          replayed: r.headers.value('Idempotent-Replayed') == 'true');
    }
    ApiException err;
    if (body is Map && body['error'] is Map) {
      final e = body['error'] as Map;
      err = ApiException(
        code: (e['code'] ?? 'error').toString(),
        message: (e['message'] ?? 'Something went wrong.').toString(),
        status: status,
        fields: ApiException.parseFields(e['fields']),
      );
    } else if (body is Map && body['errors'] is Map) {
      // plain Laravel validation answer
      err = ApiException(code: 'validation_failed', message: (body['message'] ?? 'Check the form.').toString(), status: status, fields: ApiException.parseFields(body['errors']));
    } else {
      err = ApiException(
        code: status == 401 ? 'unauthenticated' : (status == 404 ? 'not_found' : (status >= 500 ? 'server_error' : 'unexpected_response')),
        message: status >= 500 ? 'The server could not complete the request. Try again shortly.' : 'Unexpected answer from the server ($status).',
        status: status,
      );
    }
    if (err.endsSession && (status == 401 || status == 403)) onSessionEnded?.call(err);
    throw err;
  }

  ApiException _transport(DioException e) {
    final timeout = e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.sendTimeout;
    return ApiException(
      code: timeout ? 'timeout' : 'offline',
      message: timeout ? 'The server took too long to answer.' : 'No connection to the server.',
    );
  }

  Future<void> _maybeRenew() async {
    if (token == null || renewer == null || needsRenewal == null || !needsRenewal!()) return;
    _renewing ??= renewer!().whenComplete(() => _renewing = null);
    try {
      await _renewing;
    } catch (_) {
      // a failed renewal is not fatal: the current token is still valid for a while
    }
  }
}
