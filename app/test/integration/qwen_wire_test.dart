import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zurehbar_app/api/qwen_direct_client.dart';
import 'package:zurehbar_app/models/fares.dart';
import 'package:zurehbar_app/models/station.dart';
import 'package:zurehbar_app/models/zu_route.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';
import 'package:zurehbar_app/routing/network_graph.dart';
import 'package:zurehbar_app/routing/station_resolver.dart';
import 'package:zurehbar_app/ui/chat_controller.dart';

/// Drives [QwenDirectClient] over a real socket against a stand-in for the
/// OpenAI-compatible endpoint ModelScope/DashScope expose, then runs the whole
/// query loop through it. The mocked-adapter tests check argument handling;
/// this checks that the client actually speaks HTTP correctly — headers, body
/// encoding, response decoding — without depending on a reachable provider.
class _FakeQwenServer {
  final HttpServer server;
  final List<Map<String, dynamic>> requests = [];

  _FakeQwenServer._(this.server);

  String get baseUrl => 'http://${server.address.address}:${server.port}/v1';

  static Future<_FakeQwenServer> start({
    required String extractionReply,
    required String phrasingReply,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeQwenServer._(server);
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
      fake.requests.add({
        'path': request.uri.path,
        'authorization': request.headers.value('authorization'),
        'body': body,
      });
      final messages = body['messages'] as List;
      final systemPrompt = (messages.first as Map)['content'] as String;
      final reply = systemPrompt.contains('You extract') ? extractionReply : phrasingReply;
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'choices': [
            {
              'message': {'role': 'assistant', 'content': reply},
            },
          ],
        }));
      await request.response.close();
    });
    return fake;
  }

  Future<void> stop() => server.close(force: true);
}

final _stations = [
  Station(
    stationId: 'university-town',
    name: 'University Town',
    aliases: ['Uni Town'],
    urdu: [],
    pashto: [],
    servedBy: ['SR-08'],
  ),
  Station(
    stationId: 'saddar-bazar',
    name: 'Saddar Bazar',
    aliases: ['Saddar'],
    urdu: [],
    pashto: [],
    servedBy: ['SR-08'],
  ),
];

final _routes = [
  ZuRoute(
    routeId: 'SR-08',
    serviceType: 'standard',
    headwayMinLow: 8,
    headwayMinHigh: 12,
    routable: true,
    endpoints: const ['university-town', 'saddar-bazar'],
    directions: [
      RouteDirection(
        label: 'University Town to Saddar',
        originId: 'university-town',
        destinationId: 'saddar-bazar',
        stops: [
          RouteStop(
            seq: 0,
            stationId: 'university-town',
            travelTimeToNextSec: 600,
            distanceToNextKm: 5.26,
            firstBusMonThu: '06:30',
            lastBusMonThu: '21:00',
          ),
          RouteStop(seq: 1, stationId: 'saddar-bazar'),
        ],
      ),
    ],
  ),
];

final _fares = Fares(
  currency: 'PKR',
  basis: 'distance_km',
  singleJourneyTicketPkr: 70,
  feederExpressFlatFarePkr: 55,
  bands: [
    FareBand(index: 1, minKm: 0.0, maxKm: 5.0, farePkr: 30),
    FareBand(index: 2, minKm: 5.1, maxKm: 10.0, farePkr: 35),
  ],
);

void main() {
  test('the full query loop runs over a real HTTP connection to Qwen', () async {
    final fake = await _FakeQwenServer.start(
      // Fenced, the way chat models actually reply despite the prompt.
      extractionReply: '```json\n'
          '{"origin": "uni town", "destination": "saddar", "intent": "route"}\n'
          '```',
      phrasingReply: 'Take SR-08 from University Town to Saddar Bazar — about 18 '
          'minutes, and the fare is around Rs. 35.',
    );
    addTearDown(fake.stop);

    final client = QwenDirectClient(
      Dio(),
      apiKey: 'ms-test-key',
      baseUrl: fake.baseUrl,
      model: 'Qwen/Qwen2.5-72B-Instruct',
    );
    final planner = JourneyPlanner(
      NetworkGraph.build(_routes, _stations),
      StationResolver(_stations),
      _fares,
    );
    final controller = ChatController(
      backend: client,
      planner: planner,
      clock: () => DateTime(2026, 9, 14, 12, 0),
    );

    await controller.submit('how do I get from uni town to saddar');

    // Both calls went out, correctly addressed and authenticated.
    expect(fake.requests, hasLength(2));
    for (final request in fake.requests) {
      expect(request['path'], '/v1/chat/completions');
      expect(request['authorization'], 'Bearer ms-test-key');
      expect((request['body'] as Map)['model'], 'Qwen/Qwen2.5-72B-Instruct');
    }

    // The second call is handed the already-computed plan, never the raw query.
    final phrasingMessages =
        ((fake.requests[1]['body'] as Map)['messages'] as List).cast<Map>();
    final planJson = jsonDecode(phrasingMessages[1]['content'] as String) as Map;
    expect(planJson['found'], isTrue);
    expect((planJson['fare'] as Map)['total_pkr'], 35);
    expect((planJson['legs'] as List).single['route_id'], 'SR-08');

    // And the rider sees Qwen's wording on top of the computed plan.
    final answer = controller.messages.last;
    expect(answer.isOffline, isFalse);
    expect(answer.text, startsWith('Take SR-08'));
    expect(answer.plan!.fare!.totalPkr, 35);
  });

  test('a provider that never answers falls back to the on-device wording', () async {
    // A socket that accepts and then says nothing — what an unreachable or
    // hung endpoint looks like to the app.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {/* deliberately never responds */});

    final client = QwenDirectClient(
      Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
      )),
      apiKey: 'ms-test-key',
      baseUrl: 'http://${server.address.address}:${server.port}/v1',
      model: 'Qwen/Qwen2.5-72B-Instruct',
    );
    final planner = JourneyPlanner(
      NetworkGraph.build(_routes, _stations),
      StationResolver(_stations),
      _fares,
    );
    final controller = ChatController(
      backend: client,
      planner: planner,
      clock: () => DateTime(2026, 9, 14, 12, 0),
    );

    await controller.submit('uni town to saddar');

    final answer = controller.messages.last;
    expect(answer.isOffline, isTrue);
    expect(answer.plan!.found, isTrue);
    expect(answer.text, contains('SR-08'));
    expect(answer.text, contains('Rs. 35'));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
