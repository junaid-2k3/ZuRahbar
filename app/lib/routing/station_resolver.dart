import 'package:zurehbar_app/models/station.dart';

class StationMatch {
  final String? stationId;
  final List<String> candidateStationIds;

  StationMatch._({this.stationId, this.candidateStationIds = const []});

  factory StationMatch.exact(String stationId) => StationMatch._(stationId: stationId);
  factory StationMatch.ambiguous(List<String> candidateStationIds) =>
      StationMatch._(candidateStationIds: candidateStationIds);
  factory StationMatch.notFound() => StationMatch._();

  bool get isExact => stationId != null;
  bool get isAmbiguous => stationId == null && candidateStationIds.isNotEmpty;
  bool get isNotFound => stationId == null && candidateStationIds.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is StationMatch &&
      other.stationId == stationId &&
      other.candidateStationIds.join(',') == candidateStationIds.join(',');

  @override
  int get hashCode => Object.hash(stationId, candidateStationIds.join(','));
}

String _normalize(String input) => input.trim().toLowerCase();

class StationResolver {
  final List<Station> stations;

  StationResolver(this.stations);

  StationMatch resolve(String query) {
    final needle = _normalize(query);
    if (needle.isEmpty) return StationMatch.notFound();

    // 1. Exact match against the canonical name or any alias/script variant.
    for (final station in stations) {
      final names = [station.name, ...station.aliases, ...station.urdu, ...station.pashto];
      if (names.any((name) => _normalize(name) == needle)) {
        return StationMatch.exact(station.stationId);
      }
    }

    // 2. Substring match — a station name containing the query, or vice versa.
    final substringMatches = stations.where((station) {
      final names = [station.name, ...station.aliases];
      return names.any(
        (name) => _normalize(name).contains(needle) || needle.contains(_normalize(name)),
      );
    }).toList();

    if (substringMatches.length == 1) {
      return StationMatch.exact(substringMatches.first.stationId);
    }
    if (substringMatches.length > 1) {
      return StationMatch.ambiguous(substringMatches.map((s) => s.stationId).toList());
    }

    return StationMatch.notFound();
  }
}
