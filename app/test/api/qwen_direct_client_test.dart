import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zurehbar_app/api/qwen_direct_client.dart';

Map<String, dynamic> _completionOf(String content) => {
      'choices': [
        {
          'message': {'content': content},
        },
      ],
    };

void main() {
  test('extractQuery sends a bearer token and parses the JSON completion', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter((options) {
      expect(options.path, 'https://example.test/chat/completions');
      expect(options.headers['Authorization'], 'Bearer test-key');
      final body = options.data as Map<String, dynamic>;
      expect(body['model'], 'qwen-test-model');
      final messages = body['messages'] as List;
      expect(messages[1]['content'], 'how do I get from uni town to saddar');
      return _completionOf(
        jsonEncode({'origin': 'University Town', 'destination': 'Saddar', 'intent': 'route'}),
      );
    });
    final client = QwenDirectClient(
      dio,
      apiKey: 'test-key',
      baseUrl: 'https://example.test',
      model: 'qwen-test-model',
    );

    final result = await client.extractQuery('how do I get from uni town to saddar');

    expect(result.origin, 'University Town');
    expect(result.destination, 'Saddar');
    expect(result.intent, 'route');
  });

  test('extractQuery unwraps a JSON object fenced in markdown', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter((options) => _completionOf(
          'Sure!\n```json\n{"origin": "Saddar", "destination": "Chamkani", '
          '"intent": "route"}\n```',
        ));
    final client = QwenDirectClient(
      dio,
      apiKey: 'test-key',
      baseUrl: 'https://example.test',
      model: 'qwen-test-model',
    );

    final result = await client.extractQuery('saddar to chamkani');

    expect(result.origin, 'Saddar');
    expect(result.destination, 'Chamkani');
  });

  test('extractQuery throws when Qwen replies with non-JSON content', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter((options) => _completionOf('not json'));
    final client = QwenDirectClient(dio, apiKey: 'test-key', baseUrl: 'https://example.test');

    expect(() => client.extractQuery('anything'), throwsA(isA<Exception>()));
  });

  test('phraseAnswer sends the plan JSON as the user message and returns the completion text', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter((options) {
      final body = options.data as Map<String, dynamic>;
      final messages = body['messages'] as List;
      expect(jsonDecode(messages[1]['content'] as String), {'found': true, 'legs': []});
      return _completionOf('Take the ER-01, about 26 minutes, Rs. 45.');
    });
    final client = QwenDirectClient(dio, apiKey: 'test-key', baseUrl: 'https://example.test');

    final reply = await client.phraseAnswer({'found': true, 'legs': []});

    expect(reply, 'Take the ER-01, about 26 minutes, Rs. 45.');
  });
}

/// Minimal fake HttpClientAdapter so these tests need no network access.
class _FakeAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions options) onRequest;
  _FakeAdapter(this.onRequest);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final responseJson = onRequest(options);
    final bytes = Uint8List.fromList(jsonEncode(responseJson).codeUnits);
    return ResponseBody.fromBytes(bytes, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
