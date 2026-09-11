import 'package:dio/dio.dart';

class ExtractedQuery {
  final String? origin;
  final String? destination;
  final String intent;

  ExtractedQuery({this.origin, this.destination, required this.intent});

  factory ExtractedQuery.fromJson(Map<String, dynamic> json) => ExtractedQuery(
        origin: json['origin'] as String?,
        destination: json['destination'] as String?,
        intent: json['intent'] as String? ?? 'other',
      );
}

/// Abstract so tests (and Task 7's controller test) can fake it without
/// needing a real Dio instance or base URL.
abstract class BackendClient {
  Future<ExtractedQuery> extractQuery(String text);
  Future<String> phraseAnswer(Map<String, dynamic> planJson);
}

class DioBackendClient implements BackendClient {
  final Dio dio;
  final String baseUrl;

  DioBackendClient(this.dio, {required this.baseUrl}) {
    dio.options.baseUrl = baseUrl;
  }

  @override
  Future<ExtractedQuery> extractQuery(String text) async {
    final response = await dio.post('/extractQuery', data: {'text': text});
    return ExtractedQuery.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<String> phraseAnswer(Map<String, dynamic> planJson) async {
    final response = await dio.post('/phraseAnswer', data: {'plan': planJson});
    return (response.data as Map<String, dynamic>)['reply'] as String;
  }
}
