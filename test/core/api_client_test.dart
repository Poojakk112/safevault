import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safevault/core/errors/failures.dart';
import 'package:safevault/core/network/api_client.dart';

/// Fake HTTP layer that records the request instead of calling the network.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter({this.statusCode = 200});

  final int statusCode;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString('{}', statusCode, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  ApiClient buildClient(FakeAdapter adapter, {String? token = 'jwt-123'}) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    return ApiClient(
      baseUrl: 'http://test',
      tokenProvider: () async => token,
      dio: dio,
    );
  }

  test('adds the Bearer token to requests', () async {
    final adapter = FakeAdapter();
    await buildClient(adapter)
        .registerDevice(fcmToken: 'fcm-token-123', platform: 'android');

    expect(adapter.lastRequest!.path, '/devices');
    expect(adapter.lastRequest!.headers['Authorization'], 'Bearer jwt-123');
    expect(adapter.lastRequest!.data,
        {'token': 'fcm-token-123', 'platform': 'android'});
  });

  test('does not add a header when signed out', () async {
    final adapter = FakeAdapter();
    await buildClient(adapter, token: null)
        .registerDevice(fcmToken: 'fcm-token-123', platform: 'android');

    expect(adapter.lastRequest!.headers.containsKey('Authorization'), isFalse);
  });

  test('sends reminder time in UTC ISO format', () async {
    final adapter = FakeAdapter();
    final when = DateTime.utc(2027, 4, 24, 10);
    await buildClient(adapter).scheduleReminder(title: 'Review', remindAt: when);

    expect(adapter.lastRequest!.data,
        {'title': 'Review', 'remind_at': '2027-04-24T10:00:00.000Z'});
  });

  test('turns 401 into a friendly Failure', () async {
    final adapter = FakeAdapter(statusCode: 401);
    await expectLater(
      () => buildClient(adapter)
          .registerDevice(fcmToken: 'fcm-token-123', platform: 'android'),
      throwsA(isA<Failure>().having(
          (f) => f.message, 'message', contains('Session expired'))),
    );
  });
}
