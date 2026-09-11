import 'package:flutter_test/flutter_test.dart';
import 'package:zurehbar_app/models/station.dart';
import 'package:zurehbar_app/models/zu_route.dart';
import 'package:zurehbar_app/models/fares.dart';
import 'package:zurehbar_app/routing/network_graph.dart';
import 'package:zurehbar_app/routing/station_resolver.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';

Station _station(String id, {String? name, List<String> servedBy = const []}) => Station(
      stationId: id,
      name: name ?? id,
      aliases: [],
      urdu: [],
      pashto: [],
      servedBy: servedBy,
    );

Fares _fares() => Fares(
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
  test('plans a direct trip and prices it on total distance, never auto-applying flat fare', () {
    final routes = [
      ZuRoute(
        routeId: 'ER-01',
        mapLabel: 'BRT Xpress Route 01',
        serviceType: 'express',
        routable: true,
        endpoints: const ['a', 'b'],
        directions: [
          RouteDirection(label: 'a to b', originId: 'a', destinationId: 'b', stops: [
            RouteStop(seq: 0, stationId: 'a', travelTimeToNextSec: 300, distanceToNextKm: 6.0),
            RouteStop(seq: 1, stationId: 'b'),
          ]),
        ],
      ),
    ];
    final stations = [_station('a', name: 'A Stop'), _station('b', name: 'B Stop')];
    final graph = NetworkGraph.build(routes, stations);
    final planner = JourneyPlanner(graph, StationResolver(stations), _fares());

    final plan = planner.plan('A Stop', 'B Stop');

    expect(plan.found, isTrue);
    expect(plan.legs, hasLength(1));
    expect(plan.legs.first.routeId, 'ER-01');
    expect(plan.fare!.basis, 'distance_band');
    expect(plan.fare!.totalPkr, 35); // 6.0 km falls in band 2, not the flat Rs. 55
    expect(plan.fare!.note, contains('express'));
    expect(plan.fare!.note, contains('does not say which'));
    expect(plan.serviceAvailable, isNull); // no timeOfDay given
  });

  test('reports origin and destination the same as not found, per FR-9.2', () {
    final stations = [_station('a')];
    final graph = NetworkGraph.build([], stations);
    final planner = JourneyPlanner(graph, StationResolver(stations), _fares());

    final plan = planner.plan('a', 'a');

    expect(plan.found, isFalse);
    expect(plan.message, contains('same station'));
  });

  test('toJson uses the snake_case shape phraseAnswer expects', () {
    final routes = [
      ZuRoute(
        routeId: 'ER-01',
        serviceType: 'express',
        routable: true,
        endpoints: const ['a', 'b'],
        directions: [
          RouteDirection(label: 'a to b', originId: 'a', destinationId: 'b', stops: [
            RouteStop(seq: 0, stationId: 'a', travelTimeToNextSec: 120, distanceToNextKm: 2.0),
            RouteStop(seq: 1, stationId: 'b'),
          ]),
        ],
      ),
    ];
    final stations = [_station('a'), _station('b')];
    final graph = NetworkGraph.build(routes, stations);
    final planner = JourneyPlanner(graph, StationResolver(stations), _fares());

    final json = planner.plan('a', 'b').toJson();

    expect(json['found'], isTrue);
    expect(json['legs'], isA<List>());
    expect((json['legs'] as List).first['route_id'], 'ER-01');
    expect(json['fare'], isA<Map>());
    expect(json['fare']['total_pkr'], isA<int>());
  });

  ZuRoute threeStopRoute() => ZuRoute(
        routeId: 'ER-01',
        mapLabel: 'BRT Xpress Route 01',
        serviceType: 'express',
        routable: true,
        endpoints: const ['a', 'c'],
        directions: [
          RouteDirection(label: 'a to c', originId: 'a', destinationId: 'c', stops: [
            RouteStop(
              seq: 0,
              stationId: 'a',
              travelTimeToNextSec: 180,
              distanceToNextKm: 3.0,
              firstBusMonThu: '06:30',
              lastBusMonThu: '19:00',
            ),
            RouteStop(seq: 1, stationId: 'b', travelTimeToNextSec: 180, distanceToNextKm: 3.0),
            RouteStop(seq: 2, stationId: 'c'),
          ]),
        ],
      );

  test('reports service_available true when the query time is inside the boarding stop\'s hours', () {
    final routes = [threeStopRoute()];
    final stations = [_station('a'), _station('b', name: 'Mid Stop'), _station('c')];
    final graph = NetworkGraph.build(routes, stations);
    final planner = JourneyPlanner(graph, StationResolver(stations), _fares());

    final plan = planner.plan('a', 'c', timeOfDay: '10:00', dayOfWeek: 'monday');

    expect(plan.serviceAvailable, isTrue);
    expect(plan.warnings, isEmpty);
  });

  test('reports service_available false and warns when the query time is outside published hours', () {
    final routes = [threeStopRoute()];
    final stations = [_station('a'), _station('b', name: 'Mid Stop'), _station('c')];
    final graph = NetworkGraph.build(routes, stations);
    final planner = JourneyPlanner(graph, StationResolver(stations), _fares());

    final plan = planner.plan('a', 'c', timeOfDay: '20:00', dayOfWeek: 'monday');

    expect(plan.serviceAvailable, isFalse);
    expect(plan.warnings, hasLength(1));
    expect(plan.warnings.first, contains('ER-01'));
    expect(plan.warnings.first, contains('outside their published service hours'));
  });

  test('toJson includes service_available, intermediate_stations, first_bus and last_bus', () {
    final routes = [threeStopRoute()];
    final stations = [_station('a'), _station('b', name: 'Mid Stop'), _station('c')];
    final graph = NetworkGraph.build(routes, stations);
    final planner = JourneyPlanner(graph, StationResolver(stations), _fares());

    final json = planner.plan('a', 'c', timeOfDay: '10:00', dayOfWeek: 'monday').toJson();
    final leg = (json['legs'] as List).first as Map<String, dynamic>;

    expect(json['service_available'], isTrue);
    expect(leg['intermediate_stations'], ['Mid Stop']);
    expect(leg['first_bus'], '06:30');
    expect(leg['last_bus'], '19:00');
  });

  test('intermediateStations resolves station ids to display names, not raw ids', () {
    final stations = [_station('a'), _station('mid', name: 'Mid Stop'), _station('c')];
    final routesWithMidId = [
      ZuRoute(
        routeId: 'ER-01',
        mapLabel: 'BRT Xpress Route 01',
        serviceType: 'express',
        routable: true,
        endpoints: const ['a', 'c'],
        directions: [
          RouteDirection(label: 'a to c', originId: 'a', destinationId: 'c', stops: [
            RouteStop(seq: 0, stationId: 'a', travelTimeToNextSec: 180, distanceToNextKm: 3.0),
            RouteStop(seq: 1, stationId: 'mid', travelTimeToNextSec: 180, distanceToNextKm: 3.0),
            RouteStop(seq: 2, stationId: 'c'),
          ]),
        ],
      ),
    ];
    final graph = NetworkGraph.build(routesWithMidId, stations);
    final planner = JourneyPlanner(graph, StationResolver(stations), _fares());

    final plan = planner.plan('a', 'c');

    expect(plan.legs.first.intermediateStations, ['Mid Stop']);
    expect(plan.legs.first.intermediateStations, isNot(contains('mid')));
  });

  test('an ambiguous origin match asks a clarifying question instead of guessing (FR-2.2)', () {
    final stations = [
      _station('university-town', name: 'University Town'),
      _station('university-road', name: 'University Road'),
      _station('b', name: 'B Stop'),
    ];
    final graph = NetworkGraph.build([], stations);
    final planner = JourneyPlanner(graph, StationResolver(stations), _fares());

    final plan = planner.plan('University', 'B Stop');

    expect(plan.found, isFalse);
    expect(plan.message, contains('Which station'));
    expect(plan.warnings, hasLength(1));
    expect(plan.warnings.first, contains('University Town'));
    expect(plan.warnings.first, contains('University Road'));
  });

  test('coverage warnings explain a missing path caused by a non-routable route', () {
    final nonRoutableRoute = ZuRoute(
      routeId: 'ER-99',
      serviceType: 'express',
      routable: false,
      endpoints: const ['A Stop', 'B Stop'],
      directions: [
        RouteDirection(label: 'a to b', originId: 'a', destinationId: 'b', stops: [
          RouteStop(seq: 0, stationId: 'a'),
          RouteStop(seq: 1, stationId: 'b'),
        ]),
      ],
    );
    final stations = [
      _station('a', name: 'A Stop', servedBy: ['ER-99']),
      _station('b', name: 'B Stop'),
    ];
    final graph = NetworkGraph.build([nonRoutableRoute], stations);
    final planner = JourneyPlanner(graph, StationResolver(stations), _fares());

    final plan = planner.plan('A Stop', 'B Stop');

    expect(plan.found, isFalse);
    expect(plan.warnings, isNotEmpty);
    expect(plan.warnings.any((w) => w.contains('ER-99')), isTrue);
  });

  test('coverage warnings fall back to a generic note when no explanation applies', () {
    final routeOne = ZuRoute(
      routeId: 'ER-01',
      serviceType: 'express',
      routable: true,
      endpoints: const ['A Stop', 'C Stop'],
      directions: [
        RouteDirection(label: 'a to c', originId: 'a', destinationId: 'c', stops: [
          RouteStop(seq: 0, stationId: 'a', travelTimeToNextSec: 60, distanceToNextKm: 1.0),
          RouteStop(seq: 1, stationId: 'c'),
        ]),
      ],
    );
    final routeTwo = ZuRoute(
      routeId: 'ER-02',
      serviceType: 'express',
      routable: true,
      endpoints: const ['B Stop', 'D Stop'],
      directions: [
        RouteDirection(label: 'b to d', originId: 'b', destinationId: 'd', stops: [
          RouteStop(seq: 0, stationId: 'b', travelTimeToNextSec: 60, distanceToNextKm: 1.0),
          RouteStop(seq: 1, stationId: 'd'),
        ]),
      ],
    );
    final stations = [
      _station('a', name: 'A Stop', servedBy: ['ER-01']),
      _station('b', name: 'B Stop', servedBy: ['ER-02']),
      _station('c', name: 'C Stop', servedBy: ['ER-01']),
      _station('d', name: 'D Stop', servedBy: ['ER-02']),
    ];
    final graph = NetworkGraph.build([routeOne, routeTwo], stations);
    final planner = JourneyPlanner(graph, StationResolver(stations), _fares());

    final plan = planner.plan('A Stop', 'B Stop');

    expect(plan.found, isFalse);
    expect(plan.warnings, hasLength(1));
    expect(plan.warnings.first, contains('Some routes have no published stop list'));
  });
}
