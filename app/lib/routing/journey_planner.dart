import 'package:zurehbar_app/models/fares.dart';
import 'package:zurehbar_app/routing/network_graph.dart';
import 'package:zurehbar_app/routing/station_resolver.dart';

const _weekendDays = {'friday', 'saturday', 'sunday'};

/// Returns minutes since midnight, or null if unparseable. Mirrors
/// zurehbar/graph/plan.py's _parse_time exactly (same am/pm handling,
/// same range validation).
int? _parseTimeToMinutes(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  var text = value.trim().toLowerCase().replaceAll('.', ':');
  String? meridiem;
  for (final suffix in ['am', 'pm']) {
    if (text.endsWith(suffix)) {
      meridiem = suffix;
      text = text.substring(0, text.length - suffix.length).trim();
      break;
    }
  }
  final parts = text.split(':');
  int hour, minute;
  try {
    hour = int.parse(parts[0]);
    minute = parts.length > 1 ? int.parse(parts[1]) : 0;
  } catch (_) {
    return null;
  }
  if (meridiem == 'pm' && hour < 12) hour += 12;
  if (meridiem == 'am' && hour == 12) hour = 0;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

/// Mirrors zurehbar/graph/plan.py's _service_window. The `weekend` param
/// is intentionally unused, matching the Python source exactly (weekend-
/// specific service hours aren't in the Phase 1 dataset).
bool? _serviceWindow(Leg leg, int atMinutes, bool weekend) {
  final first = leg.firstBus;
  final last = leg.lastBus;
  if (first == null || last == null) return null;
  final firstMin = _parseTimeToMinutes(first);
  final lastMin = _parseTimeToMinutes(last);
  if (firstMin == null || lastMin == null) return null;
  return atMinutes >= firstMin && atMinutes <= lastMin;
}

/// Explains a missing path when the cause is missing data, not a missing bus.
/// Mirrors zurehbar/graph/plan.py's _coverage_warnings.
List<String> _coverageWarnings(
  NetworkGraph graph,
  StationResolver resolver,
  String originId,
  String destinationId,
) {
  final warnings = <String>[];
  for (final stationId in [originId, destinationId]) {
    final station = graph.stationsById[stationId];
    final unroutable = <String>{
      for (final routeId in station?.servedBy ?? const <String>[])
        if (!(graph.routesById[routeId]?.routable ?? false)) routeId,
    };
    for (final route in graph.routesById.values) {
      final endpointIds = route.endpoints
          .map((name) => resolver.resolve(name))
          .where((match) => match.isExact)
          .map((match) => match.stationId!)
          .toSet();
      if (!endpointIds.contains(stationId) || unroutable.contains(route.routeId)) {
        continue;
      }
      final inSequence = route.directions.any(
        (direction) => direction.stops.any((stop) => stop.stationId == stationId),
      );
      if (!inSequence) {
        unroutable.add(route.routeId);
      }
    }
    if (unroutable.isNotEmpty) {
      final name = station?.name ?? stationId;
      final sortedIds = unroutable.toList()..sort();
      warnings.add(
        '$name is served by ${sortedIds.join(', ')}, whose stop sequence is not '
        'published on the website, so those routes are excluded from planning. The trip '
        'may well be possible on one of them.',
      );
    }
  }
  if (warnings.isEmpty) {
    warnings.add(
      'Some routes have no published stop list and are excluded from planning; '
      'the trip may still be possible in practice.',
    );
  }
  return warnings;
}

class Leg {
  final String routeId;
  final String? routeLabel;
  final String serviceType;
  final String? directionLabel;
  final String boardStationId;
  final String boardStation;
  final String alightStationId;
  final String alightStation;
  final String? platform;
  final int stopCount;
  final double rideTimeMin;
  final double waitTimeMin;
  final double distanceKm;
  final List<String> intermediateStations;
  final String? firstBus;
  final String? lastBus;

  Leg({
    required this.routeId,
    this.routeLabel,
    required this.serviceType,
    this.directionLabel,
    required this.boardStationId,
    required this.boardStation,
    required this.alightStationId,
    required this.alightStation,
    this.platform,
    required this.stopCount,
    required this.rideTimeMin,
    required this.waitTimeMin,
    required this.distanceKm,
    this.intermediateStations = const [],
    this.firstBus,
    this.lastBus,
  });

  Map<String, dynamic> toJson() => {
        'route_id': routeId,
        'route_label': routeLabel,
        'service_type': serviceType,
        'direction_label': directionLabel,
        'board_station_id': boardStationId,
        'board_station': boardStation,
        'alight_station_id': alightStationId,
        'alight_station': alightStation,
        'platform': platform,
        'stop_count': stopCount,
        'ride_time_min': rideTimeMin,
        'wait_time_min': waitTimeMin,
        'distance_km': distanceKm,
        'intermediate_stations': intermediateStations,
        'first_bus': firstBus,
        'last_bus': lastBus,
      };
}

class FareBreakdown {
  final int totalPkr;
  final String basis;
  final double distanceKm;
  final int? bandIndex;
  final bool isEstimate;
  final String note;

  FareBreakdown({
    required this.totalPkr,
    required this.basis,
    required this.distanceKm,
    this.bandIndex,
    required this.isEstimate,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'total_pkr': totalPkr,
        'basis': basis,
        'distance_km': distanceKm,
        'band_index': bandIndex,
        'is_estimate': isEstimate,
        'note': note,
      };
}

class JourneyPlan {
  final bool found;
  final String origin;
  final String destination;
  final List<Leg> legs;
  final double totalTimeMin;
  final FareBreakdown? fare;
  final List<String> warnings;
  final String message;
  final bool? serviceAvailable;

  JourneyPlan({
    required this.found,
    required this.origin,
    required this.destination,
    this.legs = const [],
    this.totalTimeMin = 0.0,
    this.fare,
    this.warnings = const [],
    this.message = '',
    this.serviceAvailable,
  });

  Map<String, dynamic> toJson() => {
        'found': found,
        'origin': origin,
        'destination': destination,
        'legs': legs.map((leg) => leg.toJson()).toList(),
        'transfers': legs.length > 1 ? legs.skip(1).map((leg) => leg.boardStation).toList() : [],
        'total_time_min': totalTimeMin,
        'fare': fare?.toJson(),
        'warnings': warnings,
        'message': message,
        'service_available': serviceAvailable,
      };
}

/// Fare for a whole journey — priced once on total distance (never sum-of-legs),
/// and never auto-applies the flat express fare. Mirrors
/// zurehbar/graph/plan.py:112-165 exactly; see that docstring for why.
FareBreakdown calculateFare(List<Leg> legs, Fares fares) {
  final distanceKm =
      double.parse(legs.fold<double>(0, (sum, leg) => sum + leg.distanceKm).toStringAsFixed(2));

  int fare = fares.bands.last.farePkr;
  int? bandIndex;
  for (final band in fares.bands) {
    final withinLower = distanceKm >= band.minKm - 1e-9;
    final withinUpper = band.maxKm == null || distanceKm <= band.maxKm! + 1e-9;
    if (withinLower && withinUpper) {
      fare = band.farePkr;
      bandIndex = band.index;
      break;
    }
  }
  fare = fare < fares.singleJourneyTicketPkr ? fare : fares.singleJourneyTicketPkr;

  var note = 'About $distanceKm km of travel falls in fare band $bandIndex, '
      'Rs. $fare. Distances are interpolated from published route lengths, so '
      'treat the band as approximate when a trip sits near a boundary.';
  if (legs.any((leg) => leg.serviceType == 'express' || leg.serviceType == 'super_express')) {
    note += ' This trip uses an express service; express buses on feeder routes are charged '
        'a flat Rs. ${fares.feederExpressFlatFarePkr}, so the fare may be that instead. '
        'The website does not say which express routes count as feeder services.';
  }

  return FareBreakdown(
    totalPkr: fare,
    basis: 'distance_band',
    distanceKm: distanceKm,
    bandIndex: bandIndex,
    isEstimate: true,
    note: note,
  );
}

class JourneyPlanner {
  final NetworkGraph graph;
  final StationResolver resolver;
  final Fares fares;

  JourneyPlanner(this.graph, this.resolver, this.fares);

  JourneyPlan plan(String origin, String destination, {String? timeOfDay, String? dayOfWeek}) {
    final originMatch = resolver.resolve(origin);
    final destinationMatch = resolver.resolve(destination);

    if (!originMatch.isExact || !destinationMatch.isExact) {
      final originProblem = !originMatch.isExact;
      final match = originProblem ? originMatch : destinationMatch;
      final rawName = originProblem ? origin : destination;

      if (match.isAmbiguous) {
        final candidateNames = match.candidateStationIds
            .map((id) => graph.stationsById[id]?.name ?? id)
            .toList();
        return JourneyPlan(
          found: false,
          origin: origin,
          destination: destination,
          message: 'Which station did you mean for "$rawName"?',
          warnings: ['Did you mean: ${candidateNames.join(', ')}?'],
        );
      }

      return JourneyPlan(
        found: false,
        origin: origin,
        destination: destination,
        message: 'No Zu station matches "$rawName".',
      );
    }

    final originId = originMatch.stationId!;
    final destinationId = destinationMatch.stationId!;

    if (originId == destinationId) {
      return JourneyPlan(
        found: false,
        origin: graph.stationsById[originId]?.name ?? origin,
        destination: graph.stationsById[destinationId]?.name ?? destination,
        message: 'Origin and destination are the same station.',
      );
    }

    final path = graph.shortestPath(originId, destinationId);
    if (path == null) {
      return JourneyPlan(
        found: false,
        origin: graph.stationsById[originId]?.name ?? origin,
        destination: graph.stationsById[destinationId]?.name ?? destination,
        message: 'No Zu route connects these two stations in the current dataset.',
        warnings: _coverageWarnings(graph, resolver, originId, destinationId),
      );
    }

    final legs = _legsFromPath(path.nodes);
    final totalTimeMin =
        legs.fold<double>(0, (sum, leg) => sum + leg.rideTimeMin + leg.waitTimeMin);

    bool? serviceAvailable;
    final warnings = <String>[];
    final atMinutes = _parseTimeToMinutes(timeOfDay);
    if (atMinutes != null && legs.isNotEmpty) {
      final weekend = _weekendDays.contains((dayOfWeek ?? '').trim().toLowerCase());
      final windows = legs.map((leg) => _serviceWindow(leg, atMinutes, weekend)).toList();
      if (windows.any((w) => w == false)) {
        serviceAvailable = false;
        final closed = [
          for (var i = 0; i < legs.length; i++)
            if (windows[i] == false) legs[i].routeId
        ];
        warnings.add(
          'At $timeOfDay these routes are outside their published service hours: '
          '${closed.join(', ')}. Zu runs roughly 06:00 to 22:00, and individual routes '
          'stop earlier.',
        );
      } else if (windows.every((w) => w == true)) {
        serviceAvailable = true;
      }
    }

    return JourneyPlan(
      found: legs.isNotEmpty,
      origin: graph.stationsById[originId]?.name ?? origin,
      destination: graph.stationsById[destinationId]?.name ?? destination,
      legs: legs,
      totalTimeMin: double.parse(totalTimeMin.toStringAsFixed(1)),
      fare: legs.isNotEmpty ? calculateFare(legs, fares) : null,
      warnings: warnings,
      serviceAvailable: serviceAvailable,
    );
  }

  List<Leg> _legsFromPath(List<String> path) {
    final legs = <Leg>[];
    Map<String, dynamic>? current;

    for (var i = 0; i < path.length - 1; i++) {
      final from = path[i];
      final to = path[i + 1];
      final edge = graph.edgesFrom(from).firstWhere((edge) => edge.to == to);

      if (edge.kind == 'board') {
        final data = graph.stopNodes[to]!;
        final route = graph.routesById[data.routeId];
        current = {
          'routeId': data.routeId,
          'routeLabel': route?.mapLabel,
          'serviceType': route?.serviceType ?? 'unknown',
          'directionLabel': data.directionLabel,
          'boardStationId': data.stationId,
          'platform': data.platform,
          'waitSec': edge.weightSec,
          'rideSec': 0,
          'distanceKm': 0.0,
          'stations': <String>[data.stationId],
          'firstBus': data.firstBusMonThu,
          'lastBus': data.lastBusMonThu,
        };
      } else if (edge.kind == 'ride' && current != null) {
        current['rideSec'] = (current['rideSec'] as int) + edge.weightSec;
        current['distanceKm'] = (current['distanceKm'] as double) + edge.distanceKm;
        (current['stations'] as List<String>).add(graph.stopNodes[to]!.stationId);
      } else if (edge.kind == 'alight' && current != null) {
        final stations = current['stations'] as List<String>;
        if (stations.length > 1) {
          legs.add(Leg(
            routeId: current['routeId'] as String,
            routeLabel: current['routeLabel'] as String?,
            serviceType: current['serviceType'] as String,
            directionLabel: current['directionLabel'] as String?,
            boardStationId: stations.first,
            boardStation: graph.stationsById[stations.first]?.name ?? stations.first,
            alightStationId: stations.last,
            alightStation: graph.stationsById[stations.last]?.name ?? stations.last,
            platform: current['platform'] as String?,
            stopCount: stations.length - 1,
            rideTimeMin: double.parse(((current['rideSec'] as int) / 60).toStringAsFixed(1)),
            waitTimeMin: double.parse(((current['waitSec'] as int) / 60).toStringAsFixed(1)),
            distanceKm: double.parse((current['distanceKm'] as double).toStringAsFixed(2)),
            intermediateStations: stations.length > 2
                ? stations
                    .sublist(1, stations.length - 1)
                    .map((id) => graph.stationsById[id]?.name ?? id)
                    .toList()
                : const <String>[],
            firstBus: current['firstBus'] as String?,
            lastBus: current['lastBus'] as String?,
          ));
        }
        current = null;
      }
    }

    return legs;
  }
}
