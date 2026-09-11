import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zurehbar_app/api/backend_client.dart';

void main() {
  test('extractQuery posts text and parses origin/destination/intent', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter((path, body) {
      expect(path, '/extractQuery');
      return {'origin': 'University Town', 'destination': 'Saddar', 'intent': 'route'};
    });
    final client = DioBackendClient(dio, baseUrl: 'https://example.test');

    final result = await client.extractQuery('how do I get from uni town to saddar');

    expect(result.origin, 'University Town');
    expect(result.destination, 'Saddar');
    expect(result.intent, 'route');
  });

  test('phraseAnswer posts the plan JSON and returns the reply string', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter((path, body) {
      expect(path, '/phraseAnswer');
      expect(body['found'], true);
      return {'reply': 'Take the ER-01, about 26 minutes, Rs. 45.'};
    });
    final client = DioBackendClient(dio, baseUrl: 'https://example.test');

    final reply = await client.phraseAnswer({'found': true, 'legs': []});

    expect(reply, 'Take the ER-01, about 26 minutes, Rs. 45.');
  });
}

/// Minimal fake HttpClientAdapter so these tests need no network access.
class _FakeAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(String path, Map<String, dynamic> body) onRequest;
  _FakeAdapter(this.onRequest);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bodyMap = options.data is Map<String, dynamic>
        ? options.data as Map<String, dynamic>
        : <String, dynamic>{};
    final responseJson = onRequest(options.path, bodyMap);
    final bytes = Uint8List.fromList(jsonEncode(responseJson).codeUnits);
    return ResponseBody.fromBytes(bytes, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
