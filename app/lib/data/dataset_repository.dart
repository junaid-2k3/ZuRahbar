import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:zurehbar_app/data/database.dart' hide Station;
import 'package:zurehbar_app/models/station.dart';
import 'package:zurehbar_app/models/zu_route.dart';
import 'package:zurehbar_app/models/fares.dart';
import 'package:zurehbar_app/models/service_hours.dart';

class LoadedDataset {
  final List<Station> stations;
  final List<ZuRoute> routes;
  final Fares fares;
  final ServiceHours serviceHours;

  LoadedDataset({
    required this.stations,
    required this.routes,
    required this.fares,
    required this.serviceHours,
  });
}

class DatasetRepository {
  static Future<void> seedIfEmpty(
    AppDatabase db, {
    required String stationsJson,
    required String routesJson,
    required String faresJson,
    required String serviceHoursJson,
  }) async {
    final alreadySeeded = await db.select(db.stations).get();
    if (alreadySeeded.isNotEmpty) return;

    final stations = (jsonDecode(stationsJson) as List)
        .map((raw) => Station.fromJson(raw as Map<String, dynamic>))
        .toList();
    final routes = (jsonDecode(routesJson) as List)
        .map((raw) => ZuRoute.fromJson(raw as Map<String, dynamic>))
        .toList();
    final fares = Fares.fromJson(jsonDecode(faresJson) as Map<String, dynamic>);
    final serviceHours =
        ServiceHours.fromJson(jsonDecode(serviceHoursJson) as Map<String, dynamic>);

    await db.batch((batch) {
      batch.insertAll(
        db.stations,
        stations.map(
          (station) => StationsCompanion.insert(
            stationId: station.stationId,
            name: station.name,
            aliasesJson: Value(jsonEncode(station.aliases)),
            urduJson: Value(jsonEncode(station.urdu)),
            pashtoJson: Value(jsonEncode(station.pashto)),
            servedByJson: Value(jsonEncode(station.servedBy)),
          ),
        ),
      );
      batch.insertAll(
        db.routes,
        routes.map(
          (route) => RoutesCompanion.insert(
            routeId: route.routeId,
            mapLabel: Value(route.mapLabel),
            serviceType: route.serviceType,
            lengthKm: Value(route.lengthKm),
            headwayMinLow: Value(route.headwayMinLow),
            headwayMinHigh: Value(route.headwayMinHigh),
            routable: route.routable,
            endpointsJson: Value(jsonEncode(route.endpoints)),
            directionsJson: jsonEncode(route.directions
                .map((direction) => {
                      'label': direction.label,
                      'origin_id': direction.originId,
                      'destination_id': direction.destinationId,
                      'stops': direction.stops
                          .map((stop) => {
                                'seq': stop.seq,
                                'station_id': stop.stationId,
                                'platform': stop.platform,
                                'first_bus_mon_thu': stop.firstBusMonThu,
                                'last_bus_mon_thu': stop.lastBusMonThu,
                                'travel_time_to_next_sec': stop.travelTimeToNextSec,
                                'distance_to_next_km': stop.distanceToNextKm,
                              })
                          .toList(),
                    })
                .toList()),
          ),
        ),
      );
      batch.insert(
        db.fareMeta,
        FareMetaCompanion.insert(
          currency: fares.currency,
          basis: fares.basis,
          singleJourneyTicketPkr: fares.singleJourneyTicketPkr,
          feederExpressFlatFarePkr: fares.feederExpressFlatFarePkr,
          bandsJson: jsonEncode(fares.bands
              .map((band) => {
                    'index': band.index,
                    'min_km': band.minKm,
                    'max_km': band.maxKm,
                    'fare_pkr': band.farePkr,
                  })
              .toList()),
        ),
      );
      batch.insert(
        db.serviceHoursTable,
        ServiceHoursTableCompanion.insert(opens: serviceHours.opens, closes: serviceHours.closes),
      );
    });
  }

  static Future<LoadedDataset> loadDomainModels(AppDatabase db) async {
    final stationRows = await db.select(db.stations).get();
    final routeRows = await db.select(db.routes).get();
    final fareRow = await db.select(db.fareMeta).getSingle();
    final hoursRow = await db.select(db.serviceHoursTable).getSingle();

    final stations = stationRows
        .map((row) => Station(
              stationId: row.stationId,
              name: row.name,
              aliases: List<String>.from(jsonDecode(row.aliasesJson) as List),
              urdu: List<String>.from(jsonDecode(row.urduJson) as List),
              pashto: List<String>.from(jsonDecode(row.pashtoJson) as List),
              servedBy: List<String>.from(jsonDecode(row.servedByJson) as List),
            ))
        .toList();

    final routes = routeRows.map((row) {
      final directionsRaw = jsonDecode(row.directionsJson) as List;
      return ZuRoute(
        routeId: row.routeId,
        mapLabel: row.mapLabel,
        serviceType: row.serviceType,
        lengthKm: row.lengthKm,
        headwayMinLow: row.headwayMinLow,
        headwayMinHigh: row.headwayMinHigh,
        routable: row.routable,
        endpoints: List<String>.from(jsonDecode(row.endpointsJson) as List),
        directions: directionsRaw
            .map((raw) => RouteDirection.fromJson(raw as Map<String, dynamic>))
            .toList(),
      );
    }).toList();

    final bandsRaw = jsonDecode(fareRow.bandsJson) as List;
    final fares = Fares(
      currency: fareRow.currency,
      basis: fareRow.basis,
      singleJourneyTicketPkr: fareRow.singleJourneyTicketPkr,
      feederExpressFlatFarePkr: fareRow.feederExpressFlatFarePkr,
      bands: bandsRaw.map((raw) => FareBand.fromJson(raw as Map<String, dynamic>)).toList(),
    );

    return LoadedDataset(
      stations: stations,
      routes: routes,
      fares: fares,
      serviceHours: ServiceHours(opens: hoursRow.opens, closes: hoursRow.closes),
    );
  }
}
