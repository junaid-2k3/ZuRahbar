import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:zurehbar_app/data/database.dart';
import 'package:zurehbar_app/data/dataset_repository.dart';

const stationsJson = '''
[{"station_id": "chamkani", "name": "Chamkani", "aliases": [], "urdu": [], "pashto": [], "served_by": ["ER-01"]}]
''';
const routesJson = '''
[{"route_id": "ER-01", "map_label": "BRT Xpress Route 01", "service_type": "express",
  "length_km": 27.0, "headway_min_low": 4, "headway_min_high": 6, "routable": true,
  "endpoints": ["Chamkani", "Karkhano Market"], "directions": []}]
''';
const faresJson = '''
{"currency": "PKR", "basis": "distance_km", "single_journey_ticket_pkr": 70,
 "feeder_express_flat_fare_pkr": 55, "bands": [{"index": 1, "min_km": 0.0, "max_km": 5.0, "fare_pkr": 30}]}
''';
const serviceHoursJson = '{"opens": "06:00", "closes": "22:00"}';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(openConnection()));
  tearDown(() => db.close());

  test('seedIfEmpty populates all four tables, then is a no-op on a second call', () async {
    await DatasetRepository.seedIfEmpty(
      db,
      stationsJson: stationsJson,
      routesJson: routesJson,
      faresJson: faresJson,
      serviceHoursJson: serviceHoursJson,
    );

    final loaded = await DatasetRepository.loadDomainModels(db);
    expect(loaded.stations, hasLength(1));
    expect(loaded.routes, hasLength(1));
    expect(loaded.fares.singleJourneyTicketPkr, 70);
    expect(loaded.serviceHours.opens, '06:00');

    // Second call must not duplicate rows.
    await DatasetRepository.seedIfEmpty(
      db,
      stationsJson: stationsJson,
      routesJson: routesJson,
      faresJson: faresJson,
      serviceHoursJson: serviceHoursJson,
    );
    final reloaded = await DatasetRepository.loadDomainModels(db);
    expect(reloaded.stations, hasLength(1));
  });
}
