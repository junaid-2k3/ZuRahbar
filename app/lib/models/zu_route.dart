class RouteStop {
  final int seq;
  final String stationId;
  final String? platform;
  final String? firstBusMonThu;
  final String? lastBusMonThu;
  final int? travelTimeToNextSec;
  final double? distanceToNextKm;

  RouteStop({
    required this.seq,
    required this.stationId,
    this.platform,
    this.firstBusMonThu,
    this.lastBusMonThu,
    this.travelTimeToNextSec,
    this.distanceToNextKm,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      seq: json['seq'] as int,
      stationId: json['station_id'] as String,
      platform: json['platform'] as String?,
      firstBusMonThu: json['first_bus_mon_thu'] as String?,
      lastBusMonThu: json['last_bus_mon_thu'] as String?,
      travelTimeToNextSec: json['travel_time_to_next_sec'] as int?,
      distanceToNextKm: (json['distance_to_next_km'] as num?)?.toDouble(),
    );
  }
}

class RouteDirection {
  final String label;
  final String originId;
  final String destinationId;
  final List<RouteStop> stops;

  RouteDirection({
    required this.label,
    required this.originId,
    required this.destinationId,
    required this.stops,
  });

  factory RouteDirection.fromJson(Map<String, dynamic> json) {
    return RouteDirection(
      label: json['label'] as String? ?? '',
      originId: json['origin_id'] as String,
      destinationId: json['destination_id'] as String,
      stops: (json['stops'] as List)
          .map((stop) => RouteStop.fromJson(stop as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ZuRoute {
  final String routeId;
  final String? mapLabel;
  final String serviceType;
  final double? lengthKm;
  final int? headwayMinLow;
  final int? headwayMinHigh;
  final bool routable;
  final List<String> endpoints;
  final List<RouteDirection> directions;

  ZuRoute({
    required this.routeId,
    this.mapLabel,
    required this.serviceType,
    this.lengthKm,
    this.headwayMinLow,
    this.headwayMinHigh,
    required this.routable,
    required this.endpoints,
    required this.directions,
  });

  factory ZuRoute.fromJson(Map<String, dynamic> json) {
    return ZuRoute(
      routeId: json['route_id'] as String,
      mapLabel: json['map_label'] as String?,
      serviceType: json['service_type'] as String,
      lengthKm: (json['length_km'] as num?)?.toDouble(),
      headwayMinLow: json['headway_min_low'] as int?,
      headwayMinHigh: json['headway_min_high'] as int?,
      routable: json['routable'] as bool? ?? false,
      endpoints: List<String>.from(json['endpoints'] as List? ?? const []),
      directions: (json['directions'] as List? ?? const [])
          .map((direction) => RouteDirection.fromJson(direction as Map<String, dynamic>))
          .toList(),
    );
  }
}
