import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:zurehbar_app/api/backend_client.dart';

const _extractQuerySystemPrompt = '''
You extract trip intent from a Zu Transport (Peshawar BRT) rider's
message. Reply with ONLY a JSON object: {"origin": string|null, "destination": string|null,
"intent": "route"|"fare"|"other"}. Use null for a side of the trip the rider didn't mention.
Do not invent a location the rider didn't say.''';

const _phraseAnswerSystemPrompt = '''
You are Rehbar, a friendly assistant for Zu Transport (Peshawar BRT)
riders. You are given a JSON journey plan already computed by deterministic code — never
recompute or contradict its route, fare, or timing numbers. If "found" is false, explain
the "message" field plainly. Keep the reply short and conversational. If "fare".note
mentions a caveat (e.g. an express flat-fare exception), mention it briefly rather than
asserting a fare with false certainty.''';

/// Calls Qwen directly from the app instead of through a backend proxy.
///
/// Interim Phase 1 deviation from the spec's "Qwen calls are backend-proxied
/// only" rule: Firebase Functions v2 needs a Blaze billing account just to
/// reach any external API (Spark blocks outbound calls to non-Google hosts
/// entirely), and that wasn't available. [apiKey] therefore ships inside the
/// built APK and is extractable by anyone with the file — acceptable only
/// for a private, non-distributed demo. `backend/` is left untouched and
/// dormant so this can be swapped back for [DioBackendClient] once Blaze (or
/// an alternative host) is sorted.
class QwenDirectClient implements BackendClient {
  final Dio dio;
  final String apiKey;
  final String baseUrl;
  final String model;

  QwenDirectClient(
    this.dio, {
    required this.apiKey,
    this.baseUrl = 'https://api-inference.modelscope.cn/v1',
    this.model = 'Qwen/Qwen2.5-72B-Instruct',
  });

  Future<String> _callQwen(String systemPrompt, String userMessage) async {
    final response = await dio.post(
      '$baseUrl/chat/completions',
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      data: {
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
      },
    );
    final data = response.data as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    final message = choices?.isNotEmpty == true
        ? (choices!.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?
        : null;
    final content = message?['content'];
    if (content is! String) {
      throw Exception('Qwen returned no completion content');
    }
    return content;
  }

  @override
  Future<ExtractedQuery> extractQuery(String text) async {
    final reply = await _callQwen(_extractQuerySystemPrompt, text);
    try {
      return ExtractedQuery.fromJson(jsonDecode(reply) as Map<String, dynamic>);
    } on FormatException {
      throw Exception('Qwen returned an unparseable extraction response');
    }
  }

  @override
  Future<String> phraseAnswer(Map<String, dynamic> planJson) {
    return _callQwen(_phraseAnswerSystemPrompt, jsonEncode(planJson));
  }
}
