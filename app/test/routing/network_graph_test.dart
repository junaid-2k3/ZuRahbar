import 'package:flutter_test/flutter_test.dart';
import 'package:zurehbar_app/models/station.dart';
import 'package:zurehbar_app/models/zu_route.dart';
import 'package:zurehbar_app/routing/network_graph.dart';

Station _station(String id) =>
    Station(stationId: id, name: id, aliases: [], urdu: [], pashto: [], servedBy: []);

void main() {
  test('prefers a one-seat ride over a transfer that saves no real time', () {
    final routes = [
      ZuRoute(
        routeId: 'ER-01',
        serviceType: 'express',
        routable: true,
        endpoints: const ['a', 'c'],
        directions: [
          RouteDirection(label: 'a to c', originId: 'a', destinationId: 'c', stops: [
            RouteStop(seq: 0, stationId: 'a', travelTimeToNextSec: 100, distanceToNextKm: 1.0),
            RouteStop(seq: 1, stationId: 'b', travelTimeToNextSec: 100, distanceToNextKm: 1.0),
            RouteStop(seq: 2, stationId: 'c'),
          ]),
        ],
      ),
      ZuRoute(
        routeId: 'SR-02',
        serviceType: 'standard',
        routable: true,
        endpoints: const ['b', 'c'],
        directions: [
          RouteDirection(label: 'b to c', originId: 'b', destinationId: 'c', stops: [
            RouteStop(seq: 0, stationId: 'b', travelTimeToNextSec: 10, distanceToNextKm: 0.1),
            RouteStop(seq: 1, stationId: 'c'),
          ]),
        ],
      ),
    ];
    final stations = [_station('a'), _station('b'), _station('c')];

    final graph = NetworkGraph.build(routes, stations);
    final path = graph.shortestPath('a', 'c');

    expect(path, isNotNull);
    // Riding ER-01 straight through beats boarding ER-01 to b then
    // transferring to SR-02, because the transfer costs a wait + penalty
    // the through-ride never pays.
    expect(path!.nodes.where((node) => node.startsWith('stop:ER-01')), isNotEmpty);
    expect(path.nodes.any((node) => node.startsWith('stop:SR-02')), isFalse);
  });

  test('returns null when no route connects two stations', () {
    final routes = <ZuRoute>[];
    final stations = [_station('x'), _station('y')];

    final graph = NetworkGraph.build(routes, stations);

    expect(graph.shortestPath('x', 'y'), isNull);
  });

  test('skips non-routable routes entirely', () {
    final routes = [
      ZuRoute(
        routeId: 'DR-11',
        serviceType: 'direct',
        routable: false,
        endpoints: const ['p', 'q'],
        directions: [
          RouteDirection(label: 'p to q', originId: 'p', destinationId: 'q', stops: [
            RouteStop(seq: 0, stationId: 'p', travelTimeToNextSec: 60),
            RouteStop(seq: 1, stationId: 'q'),
          ]),
        ],
      ),
    ];
    final stations = [_station('p'), _station('q')];

    final graph = NetworkGraph.build(routes, stations);

    expect(graph.shortestPath('p', 'q'), isNull);
  });
}
