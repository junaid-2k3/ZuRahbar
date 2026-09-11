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
