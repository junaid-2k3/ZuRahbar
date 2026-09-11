import 'package:collection/collection.dart';
import 'package:zurehbar_app/models/station.dart';
import 'package:zurehbar_app/models/zu_route.dart';

const transferPenaltySec = 90;
const defaultHeadwayMin = 15.0;

class Edge {
  final String to;
  final String kind; // "board" | "ride" | "alight"
  final int weightSec;
  final double distanceKm;
  final String? routeId;

  Edge({required this.to, required this.kind, required this.weightSec, this.distanceKm = 0.0, this.routeId});
}

class StopNodeData {
  final String routeId;
  final int direction;
  final String? directionLabel;
  final String stationId;
  final String? platform;
  final String? firstBusMonThu;
  final String? lastBusMonThu;

  StopNodeData({
    required this.routeId,
    required this.direction,
    this.directionLabel,
    required this.stationId,
    this.platform,
    this.firstBusMonThu,
    this.lastBusMonThu,
  });
}

class GraphPath {
  final List<String> nodes;
  final int totalWeightSec;

  GraphPath({required this.nodes, required this.totalWeightSec});
}

String stationNode(String stationId) => 'station:$stationId';
String stopNode(String routeId, int direction, String stationId) =>
    'stop:$routeId:$direction:$stationId';

class NetworkGraph {
  final Map<String, List<Edge>> _adjacency;
  final Map<String, StopNodeData> stopNodes;
  final Map<String, ZuRoute> routesById;
  final Map<String, Station> stationsById;

  NetworkGraph._(this._adjacency, this.stopNodes, this.routesById, this.stationsById);

  List<Edge> edgesFrom(String node) => _adjacency[node] ?? const [];

  static double? _meanHeadway(ZuRoute route) {
    if (route.headwayMinLow == null) return null;
    final high = route.headwayMinHigh ?? route.headwayMinLow!;
    return (route.headwayMinLow! + high) / 2;
  }

  static int _fallbackRideTime(ZuRoute route, int stopCount) {
    final lengthKm = route.lengthKm ?? 0;
    final legs = (stopCount - 1).clamp(1, 1 << 30);
    if (lengthKm == 0) return 180;
    return ((lengthKm / legs) / 20 * 3600).round();
  }

  static NetworkGraph build(List<ZuRoute> routes, List<Station> stations) {
    final adjacency = <String, List<Edge>>{};
    final stopNodes = <String, StopNodeData>{};
    void addEdge(String from, Edge edge) => adjacency.putIfAbsent(from, () => []).add(edge);

    for (final station in stations) {
      adjacency.putIfAbsent(stationNode(station.stationId), () => []);
    }

    for (final route in routes) {
      if (!route.routable) continue;
      final headway = _meanHeadway(route) ?? defaultHeadwayMin;
      final waitSec = (headway * 60 / 2).round();

      for (var directionIndex = 0; directionIndex < route.directions.length; directionIndex++) {
        final stops = route.directions[directionIndex].stops;
        for (final stop in stops) {
          final node = stopNode(route.routeId, directionIndex, stop.stationId);
          stopNodes[node] = StopNodeData(
            routeId: route.routeId,
            direction: directionIndex,
            directionLabel: route.directions[directionIndex].label,
            stationId: stop.stationId,
            platform: stop.platform,
            firstBusMonThu: stop.firstBusMonThu,
            lastBusMonThu: stop.lastBusMonThu,
          );
          final station = stationNode(stop.stationId);
          adjacency.putIfAbsent(station, () => []);
          addEdge(station, Edge(to: node, kind: 'board', weightSec: waitSec + transferPenaltySec));
          addEdge(node, Edge(to: station, kind: 'alight', weightSec: 0));
        }

        for (var i = 0; i < stops.length - 1; i++) {
          final current = stops[i];
          final next = stops[i + 1];
          final ride = current.travelTimeToNextSec ?? _fallbackRideTime(route, stops.length);
          addEdge(
            stopNode(route.routeId, directionIndex, current.stationId),
            Edge(
              to: stopNode(route.routeId, directionIndex, next.stationId),
              kind: 'ride',
              weightSec: ride,
              distanceKm: current.distanceToNextKm ?? 0.0,
              routeId: route.routeId,
            ),
          );
        }
      }
    }

    return NetworkGraph._(
      adjacency,
      stopNodes,
      {for (final route in routes) route.routeId: route},
      {for (final station in stations) station.stationId: station},
    );
  }

  GraphPath? shortestPath(String originStationId, String destinationStationId) {
    final source = stationNode(originStationId);
    final target = stationNode(destinationStationId);
    if (!_adjacency.containsKey(source) || !_adjacency.containsKey(target)) return null;

    final distances = <String, int>{source: 0};
    final previous = <String, String>{};
    final visited = <String>{};
    final queue = HeapPriorityQueue<MapEntry<String, int>>(
      (a, b) => a.value.compareTo(b.value),
    )..add(MapEntry(source, 0));

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final node = current.key;
      if (!visited.add(node)) continue;
      if (node == target) break;

      for (final edge in edgesFrom(node)) {
        final candidate = (distances[node] ?? 0) + edge.weightSec;
        if (candidate < (distances[edge.to] ?? 1 << 62)) {
          distances[edge.to] = candidate;
          previous[edge.to] = node;
          queue.add(MapEntry(edge.to, candidate));
        }
      }
    }

    if (!distances.containsKey(target)) return null;

    final path = <String>[target];
    var node = target;
    while (node != source) {
      node = previous[node]!;
      path.add(node);
    }
    return GraphPath(nodes: path.reversed.toList(), totalWeightSec: distances[target]!);
  }
}
