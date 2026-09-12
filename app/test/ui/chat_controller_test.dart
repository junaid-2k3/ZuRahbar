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
  final List<Map<String, dynamic>> phrasedPlans = [];

  @override
  Future<ExtractedQuery> extractQuery(String text) async =>
      ExtractedQuery(origin: 'Alpha', destination: 'Bravo', intent: 'route');

  @override
  Future<String> phraseAnswer(Map<String, dynamic> planJson) async {
    phrasedPlans.add(planJson);
    return 'Take ER-01 from Alpha to Bravo.';
  }
}

class _FailingBackend implements BackendClient {
  @override
  Future<ExtractedQuery> extractQuery(String text) async =>
      throw Exception('network unreachable');

  @override
  Future<String> phraseAnswer(Map<String, dynamic> planJson) async =>
      throw Exception('network unreachable');
}

final _stations = [
  Station(stationId: 'alpha', name: 'Alpha', aliases: [], urdu: [], pashto: [], servedBy: []),
  Station(stationId: 'bravo', name: 'Bravo', aliases: [], urdu: [], pashto: [], servedBy: []),
  Station(stationId: 'delta', name: 'Delta', aliases: [], urdu: [], pashto: [], servedBy: []),
];

final _routes = [
  ZuRoute(
    routeId: 'ER-01',
    serviceType: 'express',
    headwayMinLow: 4,
    headwayMinHigh: 6,
    routable: true,
    endpoints: const ['alpha', 'delta'],
    directions: [
      RouteDirection(label: 'alpha to delta', originId: 'alpha', destinationId: 'delta', stops: [
        RouteStop(
          seq: 0,
          stationId: 'alpha',
          travelTimeToNextSec: 60,
          distanceToNextKm: 1.0,
          firstBusMonThu: '06:30',
          lastBusMonThu: '19:00',
        ),
        RouteStop(
          seq: 1,
          stationId: 'bravo',
          travelTimeToNextSec: 60,
          distanceToNextKm: 1.0,
          firstBusMonThu: '06:30',
          lastBusMonThu: '19:00',
        ),
        RouteStop(seq: 2, stationId: 'delta'),
      ]),
    ],
  ),
];

final _fares = Fares(
  currency: 'PKR',
  basis: 'distance_km',
  singleJourneyTicketPkr: 70,
  feederExpressFlatFarePkr: 55,
  bands: [FareBand(index: 1, minKm: 0.0, maxKm: 5.0, farePkr: 30)],
);

JourneyPlanner _planner({List<ZuRoute>? routes}) => JourneyPlanner(
      NetworkGraph.build(routes ?? _routes, _stations),
      StationResolver(_stations),
      _fares,
    );

DateTime _middayMonday() => DateTime(2026, 9, 14, 12, 0);

void main() {
  test('submitting a query appends a user message then an assistant answer', () async {
    final backend = _FakeBackend();
    final controller = ChatController(
      backend: backend,
      planner: _planner(),
      clock: _middayMonday,
    );

    await controller.submit('how do I get from Alpha to Bravo');

    expect(controller.messages, hasLength(2));
    expect(controller.messages[0].isUser, isTrue);
    expect(controller.messages[1].text, 'Take ER-01 from Alpha to Bravo.');
    expect(controller.messages[1].isOffline, isFalse);
    expect(controller.messages[1].plan?.found, isTrue);
    // The plan handed to Qwen carries the numbers it must not recompute.
    expect(backend.phrasedPlans.single['fare'], isNotNull);
  });

  test('an unreachable backend still answers, worded on-device', () async {
    final controller = ChatController(
      backend: _FailingBackend(),
      planner: _planner(),
      clock: _middayMonday,
    );

    await controller.submit('Alpha to Bravo');

    expect(controller.messages, hasLength(2));
    expect(controller.messages[1].isOffline, isTrue);
    expect(controller.messages[1].plan?.found, isTrue);
    expect(controller.messages[1].text, contains('ER-01'));
    expect(controller.messages[1].text, contains('Rs. 30'));
    expect(controller.isLoading, isFalse);
  });

  test('a build with no backend at all answers entirely on-device', () async {
    final controller = ChatController(
      backend: null,
      planner: _planner(),
      clock: _middayMonday,
    );

    await controller.submit('how do I get from Alpha to Bravo?');

    expect(controller.messages[1].isOffline, isTrue);
    expect(controller.messages[1].plan?.found, isTrue);
  });

  test('a follow-up that names no origin reuses the session origin', () async {
    final controller = ChatController(
      backend: null,
      planner: _planner(),
      clock: _middayMonday,
    );

    await controller.submit('Alpha to Bravo');
    await controller.submit('Delta');

    expect(controller.messages.last.plan?.origin, 'Alpha');
    expect(controller.messages.last.plan?.destination, 'Delta');
  });

  test('"from there" hangs the follow-up off the previous destination', () async {
    final controller = ChatController(
      backend: null,
      planner: _planner(),
      clock: _middayMonday,
    );

    await controller.submit('Alpha to Bravo');
    await controller.submit('from there to Delta');

    expect(controller.messages.last.plan?.origin, 'Bravo');
    expect(controller.messages.last.plan?.destination, 'Delta');
  });

  test('a query outside service hours still routes but says so (FR-9.3)', () async {
    final controller = ChatController(
      backend: null,
      planner: _planner(),
      clock: () => DateTime(2026, 9, 14, 23, 30),
    );

    await controller.submit('Alpha to Bravo');

    expect(controller.messages.last.plan?.serviceAvailable, isFalse);
    expect(controller.messages.last.text, contains('service hours'));
  });

  test('the From/To form skips extraction entirely', () async {
    final backend = _FakeBackend();
    final controller = ChatController(
      backend: backend,
      planner: _planner(),
      clock: _middayMonday,
    );

    await controller.submitTrip('Alpha', 'Delta');

    expect(controller.messages[0].text, 'Alpha → Delta');
    expect(controller.messages[1].plan?.destination, 'Delta');
  });

  test('a query missing both endpoints asks rather than guesses', () async {
    final controller = ChatController(
      backend: null,
      planner: _planner(),
      clock: _middayMonday,
    );

    await controller.submit('hello');

    expect(controller.messages.last.text, contains('Which stop are you starting from?'));
  });
}
