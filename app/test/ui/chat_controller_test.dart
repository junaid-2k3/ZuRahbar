import 'package:flutter_test/flutter_test.dart';
import 'package:zurehbar_app/api/backend_client.dart';
import 'package:zurehbar_app/models/station.dart';
import 'package:zurehbar_app/models/zu_route.dart';
import 'package:zurehbar_app/models/fares.dart';
import 'package:zurehbar_app/routing/network_graph.dart';
import 'package:zurehbar_app/routing/station_resolver.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';
import 'package:zurehbar_app/ui/chat_controller.dart';

class _FakeBackend implements BackendClient {
  @override
  Future<ExtractedQuery> extractQuery(String text) async =>
      ExtractedQuery(origin: 'A', destination: 'B', intent: 'route');

  @override
  Future<String> phraseAnswer(Map<String, dynamic> planJson) async =>
      'Take ER-01 from A to B.';
}

class _FailingBackend implements BackendClient {
  @override
  Future<ExtractedQuery> extractQuery(String text) async =>
      throw Exception('network unreachable');

  @override
  Future<String> phraseAnswer(Map<String, dynamic> planJson) async =>
      throw Exception('network unreachable');
}

void main() {
  test('submitting a query appends a user message then an assistant answer', () async {
    final stations = [
      Station(stationId: 'a', name: 'A', aliases: [], urdu: [], pashto: [], servedBy: []),
      Station(stationId: 'b', name: 'B', aliases: [], urdu: [], pashto: [], servedBy: []),
    ];
    final routes = [
      ZuRoute(
        routeId: 'ER-01',
        serviceType: 'express',
        routable: true,
        endpoints: const ['a', 'b'],
        directions: [
          RouteDirection(label: 'a to b', originId: 'a', destinationId: 'b', stops: [
            RouteStop(seq: 0, stationId: 'a', travelTimeToNextSec: 60, distanceToNextKm: 1.0),
            RouteStop(seq: 1, stationId: 'b'),
          ]),
        ],
      ),
    ];
    final fares = Fares(
      currency: 'PKR',
      basis: 'distance_km',
      singleJourneyTicketPkr: 70,
      feederExpressFlatFarePkr: 55,
      bands: [FareBand(index: 1, minKm: 0.0, maxKm: 5.0, farePkr: 30)],
    );
    final planner = JourneyPlanner(NetworkGraph.build(routes, stations), StationResolver(stations), fares);
    final controller = ChatController(backend: _FakeBackend(), planner: planner);

    await controller.submit('how do I get from A to B');

    expect(controller.messages, hasLength(2));
    expect(controller.messages[0].isUser, isTrue);
    expect(controller.messages[0].text, 'how do I get from A to B');
    expect(controller.messages[1].isUser, isFalse);
    expect(controller.messages[1].text, 'Take ER-01 from A to B.');
  });

  test('a backend failure appends a friendly error message and clears isLoading', () async {
    final stations = [
      Station(stationId: 'a', name: 'A', aliases: [], urdu: [], pashto: [], servedBy: []),
      Station(stationId: 'b', name: 'B', aliases: [], urdu: [], pashto: [], servedBy: []),
    ];
    final fares = Fares(
      currency: 'PKR',
      basis: 'distance_km',
      singleJourneyTicketPkr: 70,
      feederExpressFlatFarePkr: 55,
      bands: [FareBand(index: 1, minKm: 0.0, maxKm: 5.0, farePkr: 30)],
    );
    final planner =
        JourneyPlanner(NetworkGraph.build([], stations), StationResolver(stations), fares);
    final controller = ChatController(backend: _FailingBackend(), planner: planner);

    await controller.submit('how do I get from A to B');

    expect(controller.messages, hasLength(2));
    expect(controller.messages[0].isUser, isTrue);
    expect(controller.messages[1].isUser, isFalse);
    expect(
      controller.messages[1].text,
      "I couldn't reach the assistant — check your connection and try again.",
    );
    expect(controller.isLoading, isFalse);
  });
}
