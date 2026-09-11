# Flutter App Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Flutter app's Phase 1 slice: bundled dataset loaded into Drift, an on-device Dart port of this repo's Python route-stop graph + journey planner + fare calculator, fuzzy stop-name matching, and a Home screen that turns a rider's text query into a structured-card answer via the two backend Qwen proxies.

**Architecture:** Pure-Dart domain models and algorithms (graph, planner, fuzzy matching) that don't depend on Flutter or Drift, so they're unit-testable in isolation — mirroring `zurehbar/graph/network.py` and `zurehbar/graph/plan.py` field-for-field. Drift wraps them for on-device persistence of the bundled dataset. The UI layer is a thin final task that wires domain logic to widgets.

**Tech Stack:** Flutter (Dart ≥3.3), Drift (SQLite ORM) + `sqlite3_flutter_libs`, Dio for the two backend HTTP calls, `package:collection` for the Dijkstra priority queue. Riverpod is available per the project's tech stack table but Phase 1's state needs are simple enough that a single `ChangeNotifier`-backed controller is used instead — swap for Riverpod later if state grows; this is an implementation detail, not a spec requirement.

**Spec:** `docs/superpowers/specs/2026-09-11-zurehbar-phase1-design.md`

## Global Constraints

- Fare calculation must never auto-apply the flat express fare — always return the distance-band fare with the caveat note, exactly mirroring `zurehbar/graph/plan.py:112-165` (spec decision #6).
- Multi-leg fare prices the whole trip once on total distance (spec decision #3) — do not sum per-leg fares.
- No GPS-based nearest-stop resolution and no vector/embedding-based fuzzy matching in Phase 1 — plain string/fuzzy matching only (per the Functional SRS's own note and this session's ground rules).
- The JSON a completed `JourneyPlan` serializes to for `phraseAnswer` must match the Backend plan's `JourneyPlanPayload` shape (snake_case keys, mirroring `zurehbar/graph/plan.py`'s dataclasses) — see Task 5.
- Home screen only in Phase 1 (spec: "Phase 1 UI scope"). Saved Routes and Settings are navigation stubs with no logic.
- Running tests needs a system SQLite library available to `package:sqlite3` (already true on most Linux dev machines; install `libsqlite3-dev` if `flutter test` fails to open a native database).

---

### Task 1: Domain models and JSON parsers

**Files:**
- Create: `app/lib/models/station.dart`
- Create: `app/lib/models/zu_route.dart`
- Create: `app/lib/models/fares.dart`
- Create: `app/lib/models/service_hours.dart`
- Test: `app/test/models/dataset_parsing_test.dart`

**Interfaces:**
- Produces: `Station.fromJson`, `ZuRoute.fromJson`, `Fares.fromJson`, `ServiceHours.fromJson` — the only entry points every later task uses to get typed data out of the bundled JSON. `RouteDirection` and `RouteStop` are nested inside `zu_route.dart`. `FareBand` is nested inside `fares.dart`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/models/dataset_parsing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zurehbar_app/models/station.dart';
import 'package:zurehbar_app/models/zu_route.dart';
import 'package:zurehbar_app/models/fares.dart';
import 'package:zurehbar_app/models/service_hours.dart';

void main() {
  test('Station.fromJson reads aliases and scripts', () {
    final station = Station.fromJson({
      'station_id': 'abasyn-university',
      'name': 'Abasyn University',
      'aliases': ['Abaseen University', 'Abasyn'],
      'urdu': ['ابا سین یونیورسٹی'],
      'pashto': [],
      'served_by': ['DR-04B'],
    });

    expect(station.stationId, 'abasyn-university');
    expect(station.aliases, ['Abaseen University', 'Abasyn']);
    expect(station.urdu, ['ابا سین یونیورسٹی']);
    expect(station.servedBy, ['DR-04B']);
  });

  test('ZuRoute.fromJson reads directions and stops in order', () {
    final route = ZuRoute.fromJson({
      'route_id': 'ER-01',
      'map_label': 'BRT Xpress Route 01',
      'service_type': 'express',
      'length_km': 27.0,
      'headway_min_low': 4,
      'headway_min_high': 6,
      'routable': true,
      'endpoints': ['Chamkani', 'Karkhano Market'],
      'directions': [
        {
          'label': 'Chamkani to Kharkhano',
          'origin_id': 'chamkani',
          'destination_id': 'karkhano-market',
          'stops': [
            {
              'seq': 0,
              'station_id': 'chamkani',
              'platform': '3',
              'first_bus_mon_thu': '06:30',
              'last_bus_mon_thu': '19:00',
              'travel_time_to_next_sec': 85,
              'distance_to_next_km': 0.774,
            },
            {
              'seq': 1,
              'station_id': 'sardar-garhi',
              'platform': '3',
              'first_bus_mon_thu': '06:31',
              'last_bus_mon_thu': '19:01',
            },
          ],
        },
      ],
    });

    expect(route.routeId, 'ER-01');
    expect(route.serviceType, 'express');
    expect(route.routable, true);
    expect(route.directions, hasLength(1));
    expect(route.directions[0].stops, hasLength(2));
    expect(route.directions[0].stops[0].travelTimeToNextSec, 85);
    expect(route.directions[0].stops[1].travelTimeToNextSec, isNull);
  });

  test('Fares.fromJson reads bands with a nullable upper bound on the last band', () {
    final fares = Fares.fromJson({
      'currency': 'PKR',
      'basis': 'distance_km',
      'single_journey_ticket_pkr': 70,
      'feeder_express_flat_fare_pkr': 55,
      'bands': [
        {'index': 1, 'min_km': 0.0, 'max_km': 5.0, 'fare_pkr': 30},
        {'index': 9, 'min_km': 40.1, 'max_km': null, 'fare_pkr': 70},
      ],
    });

    expect(fares.singleJourneyTicketPkr, 70);
    expect(fares.feederExpressFlatFarePkr, 55);
    expect(fares.bands, hasLength(2));
    expect(fares.bands.last.maxKm, isNull);
  });

  test('ServiceHours.fromJson reads opens/closes', () {
    final hours = ServiceHours.fromJson({'opens': '06:00', 'closes': '22:00'});

    expect(hours.opens, '06:00');
    expect(hours.closes, '22:00');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app && flutter test test/models/dataset_parsing_test.dart`
Expected: FAIL — `lib/models/station.dart` etc. do not exist yet.

- [ ] **Step 3: Write the minimal implementation**

```dart
// app/lib/models/station.dart
class Station {
  final String stationId;
  final String name;
  final List<String> aliases;
  final List<String> urdu;
  final List<String> pashto;
  final List<String> servedBy;

  Station({
    required this.stationId,
    required this.name,
    required this.aliases,
    required this.urdu,
    required this.pashto,
    required this.servedBy,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      stationId: json['station_id'] as String,
      name: json['name'] as String,
      aliases: List<String>.from(json['aliases'] as List? ?? const []),
      urdu: List<String>.from(json['urdu'] as List? ?? const []),
      pashto: List<String>.from(json['pashto'] as List? ?? const []),
      servedBy: List<String>.from(json['served_by'] as List? ?? const []),
    );
  }
}
```

```dart
// app/lib/models/zu_route.dart
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
```

```dart
// app/lib/models/fares.dart
class FareBand {
  final int index;
  final double minKm;
  final double? maxKm;
  final int farePkr;

  FareBand({required this.index, required this.minKm, this.maxKm, required this.farePkr});

  factory FareBand.fromJson(Map<String, dynamic> json) {
    return FareBand(
      index: json['index'] as int,
      minKm: (json['min_km'] as num).toDouble(),
      maxKm: (json['max_km'] as num?)?.toDouble(),
      farePkr: json['fare_pkr'] as int,
    );
  }
}

class Fares {
  final String currency;
  final String basis;
  final int singleJourneyTicketPkr;
  final int feederExpressFlatFarePkr;
  final List<FareBand> bands;

  Fares({
    required this.currency,
    required this.basis,
    required this.singleJourneyTicketPkr,
    required this.feederExpressFlatFarePkr,
    required this.bands,
  });

  factory Fares.fromJson(Map<String, dynamic> json) {
    return Fares(
      currency: json['currency'] as String,
      basis: json['basis'] as String,
      singleJourneyTicketPkr: json['single_journey_ticket_pkr'] as int,
      feederExpressFlatFarePkr: json['feeder_express_flat_fare_pkr'] as int,
      bands: (json['bands'] as List)
          .map((band) => FareBand.fromJson(band as Map<String, dynamic>))
          .toList(),
    );
  }
}
```

```dart
// app/lib/models/service_hours.dart
class ServiceHours {
  final String opens;
  final String closes;

  ServiceHours({required this.opens, required this.closes});

  factory ServiceHours.fromJson(Map<String, dynamic> json) {
    return ServiceHours(
      opens: json['opens'] as String,
      closes: json['closes'] as String,
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd app && flutter test test/models/dataset_parsing_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/models/station.dart app/lib/models/zu_route.dart \
  app/lib/models/fares.dart app/lib/models/service_hours.dart \
  app/test/models/dataset_parsing_test.dart
git commit -m "feat(app): add dataset domain models and JSON parsers"
```

---

### Task 2: Drift schema and dataset repository

**Files:**
- Create: `app/lib/data/database.dart`
- Create: `app/lib/data/dataset_repository.dart`
- Test: `app/test/data/dataset_repository_test.dart`

**Interfaces:**
- Consumes: `Station`, `ZuRoute`, `Fares`, `ServiceHours` from Task 1.
- Produces: `DatasetRepository.seedIfEmpty(AppDatabase db, {required String stationsJson, required String routesJson, required String faresJson, required String serviceHoursJson})` — inserts once, no-ops if `Stations` table already has rows. `DatasetRepository.loadDomainModels(AppDatabase db) -> Future<LoadedDataset>` where `LoadedDataset` bundles `List<Station> stations`, `List<ZuRoute> routes`, `Fares fares`, `ServiceHours serviceHours` — this is what Task 3/4/5 and the UI actually consume; nothing downstream touches Drift rows directly.

- [ ] **Step 1: Write the Drift schema**

```dart
// app/lib/data/database.dart
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'database.g.dart';

class Stations extends Table {
  TextColumn get stationId => text()();
  TextColumn get name => text()();
  TextColumn get aliasesJson => text().withDefault(const Constant('[]'))();
  TextColumn get urduJson => text().withDefault(const Constant('[]'))();
  TextColumn get pashtoJson => text().withDefault(const Constant('[]'))();
  TextColumn get servedByJson => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {stationId};
}

class Routes extends Table {
  TextColumn get routeId => text()();
  TextColumn get mapLabel => text().nullable()();
  TextColumn get serviceType => text()();
  RealColumn get lengthKm => real().nullable()();
  IntColumn get headwayMinLow => integer().nullable()();
  IntColumn get headwayMinHigh => integer().nullable()();
  BoolColumn get routable => boolean()();
  TextColumn get endpointsJson => text().withDefault(const Constant('[]'))();
  TextColumn get directionsJson => text()();

  @override
  Set<Column> get primaryKey => {routeId};
}

class FareMeta extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get currency => text()();
  TextColumn get basis => text()();
  IntColumn get singleJourneyTicketPkr => integer()();
  IntColumn get feederExpressFlatFarePkr => integer()();
  TextColumn get bandsJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class ServiceHoursTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get opens => text()();
  TextColumn get closes => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Stations, Routes, FareMeta, ServiceHoursTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}

QueryExecutor openConnection() => NativeDatabase.memory();
```

Directions/stops are stored as one JSON blob per route (`directionsJson`) rather than normalized join tables — this repo's Karpathy-style constraint is minimal, no-premature-abstraction code, and Phase 1 never queries into individual stops from SQL; the graph builder (Task 3) always wants the whole nested structure back as `List<RouteDirection>`, so a join-table round-trip would only add complexity nothing reads.

- [ ] **Step 2: Write the failing test**

```dart
// app/test/data/dataset_repository_test.dart
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
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd app && flutter test test/data/dataset_repository_test.dart`
Expected: FAIL — `lib/data/dataset_repository.dart` does not exist, and `database.g.dart` hasn't been generated yet.

- [ ] **Step 4: Generate Drift code and write the minimal implementation**

Run: `cd app && flutter pub run build_runner build --delete-conflicting-outputs`
Expected: creates `app/lib/data/database.g.dart`.

```dart
// app/lib/data/dataset_repository.dart
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:zurehbar_app/data/database.dart';
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
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd app && flutter test test/data/dataset_repository_test.dart`
Expected: PASS (1 test)

- [ ] **Step 6: Commit**

```bash
git add app/lib/data/database.dart app/lib/data/database.g.dart \
  app/lib/data/dataset_repository.dart app/test/data/dataset_repository_test.dart
git commit -m "feat(app): add Drift schema and dataset repository"
```

---

### Task 3: Route-stop graph and Dijkstra shortest path

**Files:**
- Create: `app/lib/routing/network_graph.dart`
- Test: `app/test/routing/network_graph_test.dart`

**Interfaces:**
- Consumes: `List<Station>`, `List<ZuRoute>` from Task 1.
- Produces: `NetworkGraph.build(List<ZuRoute> routes, List<Station> stations) -> NetworkGraph`, and `NetworkGraph.shortestPath(String originStationId, String destinationStationId) -> GraphPath?` where `GraphPath` holds `List<String> nodes` and `int totalWeightSec`. Task 5 (journey planner) consumes both.

- [ ] **Step 1: Write the failing test**

This mirrors the two-route, one-transfer scenario `zurehbar/graph/network.py`'s docstring describes.

```dart
// app/test/routing/network_graph_test.dart
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app && flutter test test/routing/network_graph_test.dart`
Expected: FAIL — `lib/routing/network_graph.dart` does not exist.

- [ ] **Step 3: Write the minimal implementation**

```dart
// app/lib/routing/network_graph.dart
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
```

- [ ] **Step 4: Add the `collection` dependency**

In `app/pubspec.yaml`, under `dependencies`, add `collection: ^1.18.0` (declared in Task 7's full `pubspec.yaml` — if that task hasn't run yet, add it now so this task's test can run standalone).

Run: `cd app && flutter pub get`

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd app && flutter test test/routing/network_graph_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add app/lib/routing/network_graph.dart app/test/routing/network_graph_test.dart app/pubspec.yaml
git commit -m "feat(app): port the route-stop graph and Dijkstra shortest path to Dart"
```

---

### Task 4: Fuzzy stop-name resolution (FR-1.3)

**Files:**
- Create: `app/lib/routing/station_resolver.dart`
- Test: `app/test/routing/station_resolver_test.dart`

**Interfaces:**
- Consumes: `List<Station>` from Task 1.
- Produces: `StationResolver(List<Station> stations).resolve(String query) -> StationMatch` where `StationMatch` is `StationMatch.exact(String stationId)`, `StationMatch.ambiguous(List<String> candidateStationIds)` (FR-2.2: ask a clarifying question rather than guess), or `StationMatch.notFound()`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/routing/station_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zurehbar_app/models/station.dart';
import 'package:zurehbar_app/routing/station_resolver.dart';

void main() {
  final stations = [
    Station(
      stationId: 'university-town',
      name: 'University Town',
      aliases: ['Uni Town'],
      urdu: [],
      pashto: [],
      servedBy: [],
    ),
    Station(
      stationId: 'university-road',
      name: 'University Road',
      aliases: [],
      urdu: [],
      pashto: [],
      servedBy: [],
    ),
    Station(
      stationId: 'saddar',
      name: 'Saddar',
      aliases: [],
      urdu: ['صدر'],
      pashto: [],
      servedBy: [],
    ),
  ];
  final resolver = StationResolver(stations);

  test('resolves an exact canonical name', () {
    expect(resolver.resolve('Saddar'), StationMatch.exact('saddar'));
  });

  test('resolves a loosely typed alias', () {
    expect(resolver.resolve('uni town'), StationMatch.exact('university-town'));
  });

  test('resolves an Urdu script alias', () {
    expect(resolver.resolve('صدر'), StationMatch.exact('saddar'));
  });

  test('returns ambiguous when a partial query matches multiple stations similarly', () {
    final result = resolver.resolve('university');
    expect(result.isAmbiguous, isTrue);
    expect(result.candidateStationIds, containsAll(['university-town', 'university-road']));
  });

  test('returns notFound for a completely unrelated query', () {
    expect(resolver.resolve('xyz123nonsense').isNotFound, isTrue);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app && flutter test test/routing/station_resolver_test.dart`
Expected: FAIL — `lib/routing/station_resolver.dart` does not exist.

- [ ] **Step 3: Write the minimal implementation**

```dart
// app/lib/routing/station_resolver.dart
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
```

Note: this needs `Station` imported — add `import 'package:zurehbar_app/models/station.dart';` at the top.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd app && flutter test test/routing/station_resolver_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/routing/station_resolver.dart app/test/routing/station_resolver_test.dart
git commit -m "feat(app): add fuzzy stop-name resolution (FR-1.3)"
```

---

### Task 5: Journey planner and fare calculator

**Files:**
- Create: `app/lib/routing/journey_planner.dart`
- Test: `app/test/routing/journey_planner_test.dart`

**Interfaces:**
- Consumes: `NetworkGraph` (Task 3), `StationResolver`/`StationMatch` (Task 4), `Fares`/`FareBand` (Task 1).
- Produces: `JourneyPlanner(NetworkGraph graph, StationResolver resolver, Fares fares).plan(String origin, String destination) -> JourneyPlan`. `JourneyPlan.toJson()` produces the exact snake_case shape the Backend plan's `phraseAnswer` expects (`JourneyPlanPayload`). This is the last piece the UI task (Task 7) calls before hitting the backend.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/routing/journey_planner_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zurehbar_app/models/station.dart';
import 'package:zurehbar_app/models/zu_route.dart';
import 'package:zurehbar_app/models/fares.dart';
import 'package:zurehbar_app/routing/network_graph.dart';
import 'package:zurehbar_app/routing/station_resolver.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';

Station _station(String id, {String? name}) =>
    Station(stationId: id, name: name ?? id, aliases: [], urdu: [], pashto: [], servedBy: []);

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
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app && flutter test test/routing/journey_planner_test.dart`
Expected: FAIL — `lib/routing/journey_planner.dart` does not exist.

- [ ] **Step 3: Write the minimal implementation**

```dart
// app/lib/routing/journey_planner.dart
import 'package:zurehbar_app/models/fares.dart';
import 'package:zurehbar_app/routing/network_graph.dart';
import 'package:zurehbar_app/routing/station_resolver.dart';

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

  JourneyPlan({
    required this.found,
    required this.origin,
    required this.destination,
    this.legs = const [],
    this.totalTimeMin = 0.0,
    this.fare,
    this.warnings = const [],
    this.message = '',
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

  JourneyPlan plan(String origin, String destination) {
    final originMatch = resolver.resolve(origin);
    final destinationMatch = resolver.resolve(destination);

    if (!originMatch.isExact || !destinationMatch.isExact) {
      final unresolvedName = !originMatch.isExact ? origin : destination;
      return JourneyPlan(
        found: false,
        origin: origin,
        destination: destination,
        message: 'No Zu station matches "$unresolvedName".',
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
      );
    }

    final legs = _legsFromPath(path.nodes);
    final totalTimeMin =
        legs.fold<double>(0, (sum, leg) => sum + leg.rideTimeMin + leg.waitTimeMin);

    return JourneyPlan(
      found: legs.isNotEmpty,
      origin: graph.stationsById[originId]?.name ?? origin,
      destination: graph.stationsById[destinationId]?.name ?? destination,
      legs: legs,
      totalTimeMin: double.parse(totalTimeMin.toStringAsFixed(1)),
      fare: legs.isNotEmpty ? calculateFare(legs, fares) : null,
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
          ));
        }
        current = null;
      }
    }

    return legs;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd app && flutter test test/routing/journey_planner_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/routing/journey_planner.dart app/test/routing/journey_planner_test.dart
git commit -m "feat(app): port journey planner and fare calculator to Dart"
```

---

### Task 6: Backend client

**Files:**
- Create: `app/lib/api/backend_client.dart`
- Test: `app/test/api/backend_client_test.dart`

**Interfaces:**
- Consumes: `JourneyPlan.toJson()` from Task 5.
- Produces: an abstract `BackendClient` interface (so Task 7's tests can fake it) with `extractQuery(String text) -> Future<ExtractedQuery>` (`ExtractedQuery` = `{String? origin, String? destination, String intent}`) and `phraseAnswer(Map<String, dynamic> planJson) -> Future<String>`, plus a concrete `DioBackendClient(Dio dio, {required String baseUrl})` implementation. Task 7 (UI) is the only consumer.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/api/backend_client_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zurehbar_app/api/backend_client.dart';

void main() {
  test('extractQuery posts text and parses origin/destination/intent', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter((path, body) {
      expect(path, '/extractQuery');
      return {'origin': 'University Town', 'destination': 'Saddar', 'intent': 'route'};
    });
    final client = DioBackendClient(dio, baseUrl: 'https://example.test');

    final result = await client.extractQuery('how do I get from uni town to saddar');

    expect(result.origin, 'University Town');
    expect(result.destination, 'Saddar');
    expect(result.intent, 'route');
  });

  test('phraseAnswer posts the plan JSON and returns the reply string', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter((path, body) {
      expect(path, '/phraseAnswer');
      expect(body['found'], true);
      return {'reply': 'Take the ER-01, about 26 minutes, Rs. 45.'};
    });
    final client = DioBackendClient(dio, baseUrl: 'https://example.test');

    final reply = await client.phraseAnswer({'found': true, 'legs': []});

    expect(reply, 'Take the ER-01, about 26 minutes, Rs. 45.');
  });
}

/// Minimal fake HttpClientAdapter so these tests need no network access.
class _FakeAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(String path, Map<String, dynamic> body) onRequest;
  _FakeAdapter(this.onRequest);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bodyMap = options.data is Map<String, dynamic>
        ? options.data as Map<String, dynamic>
        : <String, dynamic>{};
    final responseJson = onRequest(options.path, bodyMap);
    final bytes = Uint8List.fromList(jsonEncode(responseJson).codeUnits);
    return ResponseBody.fromBytes(bytes, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
```

Add `import 'dart:convert';` and `import 'dart:typed_data';` to the test file's imports alongside the ones shown.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app && flutter test test/api/backend_client_test.dart`
Expected: FAIL — `lib/api/backend_client.dart` does not exist.

- [ ] **Step 3: Write the minimal implementation**

```dart
// app/lib/api/backend_client.dart
import 'package:dio/dio.dart';

class ExtractedQuery {
  final String? origin;
  final String? destination;
  final String intent;

  ExtractedQuery({this.origin, this.destination, required this.intent});

  factory ExtractedQuery.fromJson(Map<String, dynamic> json) => ExtractedQuery(
        origin: json['origin'] as String?,
        destination: json['destination'] as String?,
        intent: json['intent'] as String? ?? 'other',
      );
}

/// Abstract so tests (and Task 7's controller test) can fake it without
/// needing a real Dio instance or base URL.
abstract class BackendClient {
  Future<ExtractedQuery> extractQuery(String text);
  Future<String> phraseAnswer(Map<String, dynamic> planJson);
}

class DioBackendClient implements BackendClient {
  final Dio dio;
  final String baseUrl;

  DioBackendClient(this.dio, {required this.baseUrl});

  @override
  Future<ExtractedQuery> extractQuery(String text) async {
    final response = await dio.post('$baseUrl/extractQuery', data: {'text': text});
    return ExtractedQuery.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<String> phraseAnswer(Map<String, dynamic> planJson) async {
    final response = await dio.post('$baseUrl/phraseAnswer', data: {'plan': planJson});
    return (response.data as Map<String, dynamic>)['reply'] as String;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd app && flutter test test/api/backend_client_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/api/backend_client.dart app/test/api/backend_client_test.dart
git commit -m "feat(app): add Dio backend client for the Qwen proxy endpoints"
```

---

### Task 7: App scaffold and Home screen

**Files:**
- Create: `app/pubspec.yaml`
- Create: `app/lib/main.dart`
- Create: `app/lib/ui/home_screen.dart`
- Create: `app/lib/ui/answer_card.dart`
- Create: `app/lib/ui/chat_controller.dart`
- Test: `app/test/ui/chat_controller_test.dart`

**Interfaces:**
- Consumes: `DatasetRepository` (Task 2), `NetworkGraph`/`JourneyPlanner` (Task 3/5), `BackendClient` (Task 6).
- Produces: nothing further downstream — this is the last task in this plan.

- [ ] **Step 1: Write `pubspec.yaml`**

```yaml
name: zurehbar_app
description: ZuRehbar rider assistant — Phase 1 (text Q&A, on-device routing, fare calc).
publish_to: 'none'
version: 0.1.0

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  drift: ^2.16.0
  sqlite3_flutter_libs: ^0.5.20
  path_provider: ^2.1.0
  path: ^1.9.0
  dio: ^5.4.0
  collection: ^1.18.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: ^2.16.0
  build_runner: ^2.4.0

flutter:
  uses-material-design: true
  assets:
    - assets/data/routes.json
    - assets/data/stations.json
    - assets/data/fares.json
    - assets/data/service_hours.json
```

Run: `cd app && flutter create . --platforms=android --org pk.transpeshawar.zurehbar` (only if `app/` doesn't already have the generated Android scaffold — `flutter create .` is safe to re-run in an existing Flutter project and won't overwrite the files above) then `flutter pub get`.

- [ ] **Step 2: Write the failing test for the chat controller**

The controller (not the widget tree) is what carries the query→answer logic, so it's what gets a real test; the widget itself is a thin render of its state (verified by manual run per the spec's "Testing" section, since this repo does manual testing only for UI).

```dart
// app/test/ui/chat_controller_test.dart
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
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd app && flutter test test/ui/chat_controller_test.dart`
Expected: FAIL — `lib/ui/chat_controller.dart` does not exist.

- [ ] **Step 4: Write the minimal implementation**

```dart
// app/lib/ui/chat_controller.dart
import 'package:flutter/foundation.dart';
import 'package:zurehbar_app/api/backend_client.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';

class ChatMessage {
  final bool isUser;
  final String text;
  final JourneyPlan? plan;

  ChatMessage({required this.isUser, required this.text, this.plan});
}

class ChatController extends ChangeNotifier {
  final BackendClient backend;
  final JourneyPlanner planner;
  final List<ChatMessage> messages = [];
  bool isLoading = false;

  ChatController({required this.backend, required this.planner});

  Future<void> submit(String rawText) async {
    messages.add(ChatMessage(isUser: true, text: rawText));
    isLoading = true;
    notifyListeners();

    try {
      final extracted = await backend.extractQuery(rawText);
      if (extracted.origin == null || extracted.destination == null) {
        messages.add(ChatMessage(
          isUser: false,
          text: 'Where are you starting from, and where are you headed?',
        ));
        return;
      }

      final plan = planner.plan(extracted.origin!, extracted.destination!);
      final reply = await backend.phraseAnswer(plan.toJson());
      messages.add(ChatMessage(isUser: false, text: reply, plan: plan));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd app && flutter test test/ui/chat_controller_test.dart`
Expected: PASS (1 test)

- [ ] **Step 6: Build the Home screen and app shell**

No new automated test here — per the spec's Testing section (manual testing only, matching the Project Plan's own team choice) this step is verified by running the app, not by a widget test. Read `app/lib/ui/chat_controller.dart` (Step 4) and `app/lib/routing/journey_planner.dart` (Task 5) before writing this so the field names below match exactly.

```dart
// app/lib/ui/answer_card.dart
import 'package:flutter/material.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';

const _serviceTypeColors = {
  'express': Colors.deepOrange,
  'super_express': Colors.red,
  'standard': Colors.blue,
  'direct': Colors.teal,
};

class AnswerCard extends StatelessWidget {
  final String replyText;
  final JourneyPlan? plan;

  const AnswerCard({super.key, required this.replyText, this.plan});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(replyText),
            if (plan != null && plan!.found) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: plan!.legs
                    .map((leg) => Chip(
                          label: Text(leg.routeId),
                          backgroundColor:
                              (_serviceTypeColors[leg.serviceType] ?? Colors.grey).withOpacity(0.2),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 4),
              Text('Fare: Rs. ${plan!.fare?.totalPkr ?? '—'} · '
                  '${plan!.totalTimeMin.toStringAsFixed(0)} min'),
            ],
          ],
        ),
      ),
    );
  }
}
```

```dart
// app/lib/ui/home_screen.dart
import 'package:flutter/material.dart';
import 'package:zurehbar_app/ui/answer_card.dart';
import 'package:zurehbar_app/ui/chat_controller.dart';

class HomeScreen extends StatefulWidget {
  final ChatController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    widget.controller.submit(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ZuRehbar')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.controller.messages.length,
              itemBuilder: (context, index) {
                final message = widget.controller.messages[index];
                if (message.isUser) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(message.text),
                    ),
                  );
                }
                return AnswerCard(replyText: message.text, plan: message.plan);
              },
            ),
          ),
          if (widget.controller.isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Where to? e.g. "University Town to Saddar"',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _submit),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
// app/lib/main.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zurehbar_app/api/backend_client.dart';
import 'package:zurehbar_app/data/database.dart';
import 'package:zurehbar_app/data/dataset_repository.dart';
import 'package:zurehbar_app/routing/network_graph.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';
import 'package:zurehbar_app/routing/station_resolver.dart';
import 'package:zurehbar_app/ui/chat_controller.dart';
import 'package:zurehbar_app/ui/home_screen.dart';

// Set at build/run time: --dart-define=BACKEND_BASE_URL=https://<region>-<project-id>.cloudfunctions.net
const _backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'http://10.0.2.2:5001/REPLACE_WITH_PROJECT_ID/us-central1',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase(openConnection());
  await DatasetRepository.seedIfEmpty(
    db,
    stationsJson: await rootBundle.loadString('assets/data/stations.json'),
    routesJson: await rootBundle.loadString('assets/data/routes.json'),
    faresJson: await rootBundle.loadString('assets/data/fares.json'),
    serviceHoursJson: await rootBundle.loadString('assets/data/service_hours.json'),
  );
  final dataset = await DatasetRepository.loadDomainModels(db);

  final graph = NetworkGraph.build(dataset.routes, dataset.stations);
  final resolver = StationResolver(dataset.stations);
  final planner = JourneyPlanner(graph, resolver, dataset.fares);
  final backend = DioBackendClient(Dio(), baseUrl: _backendBaseUrl);
  final chatController = ChatController(backend: backend, planner: planner);

  runApp(ZuRehbarApp(chatController: chatController));
}

class ZuRehbarApp extends StatelessWidget {
  final ChatController chatController;

  const ZuRehbarApp({super.key, required this.chatController});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZuRehbar',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green, brightness: Brightness.dark),
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          body: TabBarView(
            children: [
              HomeScreen(controller: chatController),
              const Center(child: Text('Saved Routes — coming in Phase 4')),
              const Center(child: Text('Settings — coming in Phase 4')),
            ],
          ),
          bottomNavigationBar: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.home), text: 'Home'),
              Tab(icon: Icon(Icons.star), text: 'Saved Routes'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}
```

`_backendBaseUrl`'s default targets the Android emulator's host loopback (`10.0.2.2`) talking to a local Functions emulator — replace `REPLACE_WITH_PROJECT_ID`, or pass `--dart-define=BACKEND_BASE_URL=...` pointing at the deployed Functions URLs from the Backend plan's Task 2, Step 5 note.

- [ ] **Step 7: Run the app and manually verify the golden path**

Run: `cd app && flutter run -d emulator-5554` (or whichever device/emulator is attached), with the Backend plan's functions running locally (`cd backend/functions && npm run serve`) or deployed.

Manually check, per the spec's Testing section:
- A direct-route query (e.g. two stations on the same route) returns a card with the right route badge, fare, and time.
- Same origin and destination returns the FR-9.2 message, not a crash or nonsense answer.
- An unresolvable station name returns a "no station matches" message rather than guessing.

- [ ] **Step 8: Commit**

```bash
git add app/pubspec.yaml app/lib/main.dart app/lib/ui/home_screen.dart \
  app/lib/ui/answer_card.dart app/lib/ui/chat_controller.dart \
  app/test/ui/chat_controller_test.dart
git commit -m "feat(app): add Home screen, app shell, and chat controller"
```
