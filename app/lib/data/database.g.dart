// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $StationsTable extends Stations with TableInfo<$StationsTable, Station> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _stationIdMeta =
      const VerificationMeta('stationId');
  @override
  late final GeneratedColumn<String> stationId = GeneratedColumn<String>(
      'station_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aliasesJsonMeta =
      const VerificationMeta('aliasesJson');
  @override
  late final GeneratedColumn<String> aliasesJson = GeneratedColumn<String>(
      'aliases_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _urduJsonMeta =
      const VerificationMeta('urduJson');
  @override
  late final GeneratedColumn<String> urduJson = GeneratedColumn<String>(
      'urdu_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _pashtoJsonMeta =
      const VerificationMeta('pashtoJson');
  @override
  late final GeneratedColumn<String> pashtoJson = GeneratedColumn<String>(
      'pashto_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _servedByJsonMeta =
      const VerificationMeta('servedByJson');
  @override
  late final GeneratedColumn<String> servedByJson = GeneratedColumn<String>(
      'served_by_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  @override
  List<GeneratedColumn> get $columns =>
      [stationId, name, aliasesJson, urduJson, pashtoJson, servedByJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stations';
  @override
  VerificationContext validateIntegrity(Insertable<Station> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('station_id')) {
      context.handle(_stationIdMeta,
          stationId.isAcceptableOrUnknown(data['station_id']!, _stationIdMeta));
    } else if (isInserting) {
      context.missing(_stationIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('aliases_json')) {
      context.handle(
          _aliasesJsonMeta,
          aliasesJson.isAcceptableOrUnknown(
              data['aliases_json']!, _aliasesJsonMeta));
    }
    if (data.containsKey('urdu_json')) {
      context.handle(_urduJsonMeta,
          urduJson.isAcceptableOrUnknown(data['urdu_json']!, _urduJsonMeta));
    }
    if (data.containsKey('pashto_json')) {
      context.handle(
          _pashtoJsonMeta,
          pashtoJson.isAcceptableOrUnknown(
              data['pashto_json']!, _pashtoJsonMeta));
    }
    if (data.containsKey('served_by_json')) {
      context.handle(
          _servedByJsonMeta,
          servedByJson.isAcceptableOrUnknown(
              data['served_by_json']!, _servedByJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {stationId};
  @override
  Station map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Station(
      stationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}station_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      aliasesJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}aliases_json'])!,
      urduJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}urdu_json'])!,
      pashtoJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pashto_json'])!,
      servedByJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}served_by_json'])!,
    );
  }

  @override
  $StationsTable createAlias(String alias) {
    return $StationsTable(attachedDatabase, alias);
  }
}

class Station extends DataClass implements Insertable<Station> {
  final String stationId;
  final String name;
  final String aliasesJson;
  final String urduJson;
  final String pashtoJson;
  final String servedByJson;
  const Station(
      {required this.stationId,
      required this.name,
      required this.aliasesJson,
      required this.urduJson,
      required this.pashtoJson,
      required this.servedByJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['station_id'] = Variable<String>(stationId);
    map['name'] = Variable<String>(name);
    map['aliases_json'] = Variable<String>(aliasesJson);
    map['urdu_json'] = Variable<String>(urduJson);
    map['pashto_json'] = Variable<String>(pashtoJson);
    map['served_by_json'] = Variable<String>(servedByJson);
    return map;
  }

  StationsCompanion toCompanion(bool nullToAbsent) {
    return StationsCompanion(
      stationId: Value(stationId),
      name: Value(name),
      aliasesJson: Value(aliasesJson),
      urduJson: Value(urduJson),
      pashtoJson: Value(pashtoJson),
      servedByJson: Value(servedByJson),
    );
  }

  factory Station.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Station(
      stationId: serializer.fromJson<String>(json['stationId']),
      name: serializer.fromJson<String>(json['name']),
      aliasesJson: serializer.fromJson<String>(json['aliasesJson']),
      urduJson: serializer.fromJson<String>(json['urduJson']),
      pashtoJson: serializer.fromJson<String>(json['pashtoJson']),
      servedByJson: serializer.fromJson<String>(json['servedByJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'stationId': serializer.toJson<String>(stationId),
      'name': serializer.toJson<String>(name),
      'aliasesJson': serializer.toJson<String>(aliasesJson),
      'urduJson': serializer.toJson<String>(urduJson),
      'pashtoJson': serializer.toJson<String>(pashtoJson),
      'servedByJson': serializer.toJson<String>(servedByJson),
    };
  }

  Station copyWith(
          {String? stationId,
          String? name,
          String? aliasesJson,
          String? urduJson,
          String? pashtoJson,
          String? servedByJson}) =>
      Station(
        stationId: stationId ?? this.stationId,
        name: name ?? this.name,
        aliasesJson: aliasesJson ?? this.aliasesJson,
        urduJson: urduJson ?? this.urduJson,
        pashtoJson: pashtoJson ?? this.pashtoJson,
        servedByJson: servedByJson ?? this.servedByJson,
      );
  Station copyWithCompanion(StationsCompanion data) {
    return Station(
      stationId: data.stationId.present ? data.stationId.value : this.stationId,
      name: data.name.present ? data.name.value : this.name,
      aliasesJson:
          data.aliasesJson.present ? data.aliasesJson.value : this.aliasesJson,
      urduJson: data.urduJson.present ? data.urduJson.value : this.urduJson,
      pashtoJson:
          data.pashtoJson.present ? data.pashtoJson.value : this.pashtoJson,
      servedByJson: data.servedByJson.present
          ? data.servedByJson.value
          : this.servedByJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Station(')
          ..write('stationId: $stationId, ')
          ..write('name: $name, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('urduJson: $urduJson, ')
          ..write('pashtoJson: $pashtoJson, ')
          ..write('servedByJson: $servedByJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      stationId, name, aliasesJson, urduJson, pashtoJson, servedByJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Station &&
          other.stationId == this.stationId &&
          other.name == this.name &&
          other.aliasesJson == this.aliasesJson &&
          other.urduJson == this.urduJson &&
          other.pashtoJson == this.pashtoJson &&
          other.servedByJson == this.servedByJson);
}

class StationsCompanion extends UpdateCompanion<Station> {
  final Value<String> stationId;
  final Value<String> name;
  final Value<String> aliasesJson;
  final Value<String> urduJson;
  final Value<String> pashtoJson;
  final Value<String> servedByJson;
  final Value<int> rowid;
  const StationsCompanion({
    this.stationId = const Value.absent(),
    this.name = const Value.absent(),
    this.aliasesJson = const Value.absent(),
    this.urduJson = const Value.absent(),
    this.pashtoJson = const Value.absent(),
    this.servedByJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StationsCompanion.insert({
    required String stationId,
    required String name,
    this.aliasesJson = const Value.absent(),
    this.urduJson = const Value.absent(),
    this.pashtoJson = const Value.absent(),
    this.servedByJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : stationId = Value(stationId),
        name = Value(name);
  static Insertable<Station> custom({
    Expression<String>? stationId,
    Expression<String>? name,
    Expression<String>? aliasesJson,
    Expression<String>? urduJson,
    Expression<String>? pashtoJson,
    Expression<String>? servedByJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (stationId != null) 'station_id': stationId,
      if (name != null) 'name': name,
      if (aliasesJson != null) 'aliases_json': aliasesJson,
      if (urduJson != null) 'urdu_json': urduJson,
      if (pashtoJson != null) 'pashto_json': pashtoJson,
      if (servedByJson != null) 'served_by_json': servedByJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StationsCompanion copyWith(
      {Value<String>? stationId,
      Value<String>? name,
      Value<String>? aliasesJson,
      Value<String>? urduJson,
      Value<String>? pashtoJson,
      Value<String>? servedByJson,
      Value<int>? rowid}) {
    return StationsCompanion(
      stationId: stationId ?? this.stationId,
      name: name ?? this.name,
      aliasesJson: aliasesJson ?? this.aliasesJson,
      urduJson: urduJson ?? this.urduJson,
      pashtoJson: pashtoJson ?? this.pashtoJson,
      servedByJson: servedByJson ?? this.servedByJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (stationId.present) {
      map['station_id'] = Variable<String>(stationId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (aliasesJson.present) {
      map['aliases_json'] = Variable<String>(aliasesJson.value);
    }
    if (urduJson.present) {
      map['urdu_json'] = Variable<String>(urduJson.value);
    }
    if (pashtoJson.present) {
      map['pashto_json'] = Variable<String>(pashtoJson.value);
    }
    if (servedByJson.present) {
      map['served_by_json'] = Variable<String>(servedByJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StationsCompanion(')
          ..write('stationId: $stationId, ')
          ..write('name: $name, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('urduJson: $urduJson, ')
          ..write('pashtoJson: $pashtoJson, ')
          ..write('servedByJson: $servedByJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutesTable extends Routes with TableInfo<$RoutesTable, Route> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _routeIdMeta =
      const VerificationMeta('routeId');
  @override
  late final GeneratedColumn<String> routeId = GeneratedColumn<String>(
      'route_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mapLabelMeta =
      const VerificationMeta('mapLabel');
  @override
  late final GeneratedColumn<String> mapLabel = GeneratedColumn<String>(
      'map_label', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _serviceTypeMeta =
      const VerificationMeta('serviceType');
  @override
  late final GeneratedColumn<String> serviceType = GeneratedColumn<String>(
      'service_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lengthKmMeta =
      const VerificationMeta('lengthKm');
  @override
  late final GeneratedColumn<double> lengthKm = GeneratedColumn<double>(
      'length_km', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _headwayMinLowMeta =
      const VerificationMeta('headwayMinLow');
  @override
  late final GeneratedColumn<int> headwayMinLow = GeneratedColumn<int>(
      'headway_min_low', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _headwayMinHighMeta =
      const VerificationMeta('headwayMinHigh');
  @override
  late final GeneratedColumn<int> headwayMinHigh = GeneratedColumn<int>(
      'headway_min_high', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _routableMeta =
      const VerificationMeta('routable');
  @override
  late final GeneratedColumn<bool> routable = GeneratedColumn<bool>(
      'routable', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("routable" IN (0, 1))'));
  static const VerificationMeta _endpointsJsonMeta =
      const VerificationMeta('endpointsJson');
  @override
  late final GeneratedColumn<String> endpointsJson = GeneratedColumn<String>(
      'endpoints_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _directionsJsonMeta =
      const VerificationMeta('directionsJson');
  @override
  late final GeneratedColumn<String> directionsJson = GeneratedColumn<String>(
      'directions_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        routeId,
        mapLabel,
        serviceType,
        lengthKm,
        headwayMinLow,
        headwayMinHigh,
        routable,
        endpointsJson,
        directionsJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routes';
  @override
  VerificationContext validateIntegrity(Insertable<Route> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('route_id')) {
      context.handle(_routeIdMeta,
          routeId.isAcceptableOrUnknown(data['route_id']!, _routeIdMeta));
    } else if (isInserting) {
      context.missing(_routeIdMeta);
    }
    if (data.containsKey('map_label')) {
      context.handle(_mapLabelMeta,
          mapLabel.isAcceptableOrUnknown(data['map_label']!, _mapLabelMeta));
    }
    if (data.containsKey('service_type')) {
      context.handle(
          _serviceTypeMeta,
          serviceType.isAcceptableOrUnknown(
              data['service_type']!, _serviceTypeMeta));
    } else if (isInserting) {
      context.missing(_serviceTypeMeta);
    }
    if (data.containsKey('length_km')) {
      context.handle(_lengthKmMeta,
          lengthKm.isAcceptableOrUnknown(data['length_km']!, _lengthKmMeta));
    }
    if (data.containsKey('headway_min_low')) {
      context.handle(
          _headwayMinLowMeta,
          headwayMinLow.isAcceptableOrUnknown(
              data['headway_min_low']!, _headwayMinLowMeta));
    }
    if (data.containsKey('headway_min_high')) {
      context.handle(
          _headwayMinHighMeta,
          headwayMinHigh.isAcceptableOrUnknown(
              data['headway_min_high']!, _headwayMinHighMeta));
    }
    if (data.containsKey('routable')) {
      context.handle(_routableMeta,
          routable.isAcceptableOrUnknown(data['routable']!, _routableMeta));
    } else if (isInserting) {
      context.missing(_routableMeta);
    }
    if (data.containsKey('endpoints_json')) {
      context.handle(
          _endpointsJsonMeta,
          endpointsJson.isAcceptableOrUnknown(
              data['endpoints_json']!, _endpointsJsonMeta));
    }
    if (data.containsKey('directions_json')) {
      context.handle(
          _directionsJsonMeta,
          directionsJson.isAcceptableOrUnknown(
              data['directions_json']!, _directionsJsonMeta));
    } else if (isInserting) {
      context.missing(_directionsJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {routeId};
  @override
  Route map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Route(
      routeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}route_id'])!,
      mapLabel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}map_label']),
      serviceType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}service_type'])!,
      lengthKm: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}length_km']),
      headwayMinLow: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}headway_min_low']),
      headwayMinHigh: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}headway_min_high']),
      routable: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}routable'])!,
      endpointsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}endpoints_json'])!,
      directionsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}directions_json'])!,
    );
  }

  @override
  $RoutesTable createAlias(String alias) {
    return $RoutesTable(attachedDatabase, alias);
  }
}

class Route extends DataClass implements Insertable<Route> {
  final String routeId;
  final String? mapLabel;
  final String serviceType;
  final double? lengthKm;
  final int? headwayMinLow;
  final int? headwayMinHigh;
  final bool routable;
  final String endpointsJson;
  final String directionsJson;
  const Route(
      {required this.routeId,
      this.mapLabel,
      required this.serviceType,
      this.lengthKm,
      this.headwayMinLow,
      this.headwayMinHigh,
      required this.routable,
      required this.endpointsJson,
      required this.directionsJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['route_id'] = Variable<String>(routeId);
    if (!nullToAbsent || mapLabel != null) {
      map['map_label'] = Variable<String>(mapLabel);
    }
    map['service_type'] = Variable<String>(serviceType);
    if (!nullToAbsent || lengthKm != null) {
      map['length_km'] = Variable<double>(lengthKm);
    }
    if (!nullToAbsent || headwayMinLow != null) {
      map['headway_min_low'] = Variable<int>(headwayMinLow);
    }
    if (!nullToAbsent || headwayMinHigh != null) {
      map['headway_min_high'] = Variable<int>(headwayMinHigh);
    }
    map['routable'] = Variable<bool>(routable);
    map['endpoints_json'] = Variable<String>(endpointsJson);
    map['directions_json'] = Variable<String>(directionsJson);
    return map;
  }

  RoutesCompanion toCompanion(bool nullToAbsent) {
    return RoutesCompanion(
      routeId: Value(routeId),
      mapLabel: mapLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(mapLabel),
      serviceType: Value(serviceType),
      lengthKm: lengthKm == null && nullToAbsent
          ? const Value.absent()
          : Value(lengthKm),
      headwayMinLow: headwayMinLow == null && nullToAbsent
          ? const Value.absent()
          : Value(headwayMinLow),
      headwayMinHigh: headwayMinHigh == null && nullToAbsent
          ? const Value.absent()
          : Value(headwayMinHigh),
      routable: Value(routable),
      endpointsJson: Value(endpointsJson),
      directionsJson: Value(directionsJson),
    );
  }

  factory Route.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Route(
      routeId: serializer.fromJson<String>(json['routeId']),
      mapLabel: serializer.fromJson<String?>(json['mapLabel']),
      serviceType: serializer.fromJson<String>(json['serviceType']),
      lengthKm: serializer.fromJson<double?>(json['lengthKm']),
      headwayMinLow: serializer.fromJson<int?>(json['headwayMinLow']),
      headwayMinHigh: serializer.fromJson<int?>(json['headwayMinHigh']),
      routable: serializer.fromJson<bool>(json['routable']),
      endpointsJson: serializer.fromJson<String>(json['endpointsJson']),
      directionsJson: serializer.fromJson<String>(json['directionsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'routeId': serializer.toJson<String>(routeId),
      'mapLabel': serializer.toJson<String?>(mapLabel),
      'serviceType': serializer.toJson<String>(serviceType),
      'lengthKm': serializer.toJson<double?>(lengthKm),
      'headwayMinLow': serializer.toJson<int?>(headwayMinLow),
      'headwayMinHigh': serializer.toJson<int?>(headwayMinHigh),
      'routable': serializer.toJson<bool>(routable),
      'endpointsJson': serializer.toJson<String>(endpointsJson),
      'directionsJson': serializer.toJson<String>(directionsJson),
    };
  }

  Route copyWith(
          {String? routeId,
          Value<String?> mapLabel = const Value.absent(),
          String? serviceType,
          Value<double?> lengthKm = const Value.absent(),
          Value<int?> headwayMinLow = const Value.absent(),
          Value<int?> headwayMinHigh = const Value.absent(),
          bool? routable,
          String? endpointsJson,
          String? directionsJson}) =>
      Route(
        routeId: routeId ?? this.routeId,
        mapLabel: mapLabel.present ? mapLabel.value : this.mapLabel,
        serviceType: serviceType ?? this.serviceType,
        lengthKm: lengthKm.present ? lengthKm.value : this.lengthKm,
        headwayMinLow:
            headwayMinLow.present ? headwayMinLow.value : this.headwayMinLow,
        headwayMinHigh:
            headwayMinHigh.present ? headwayMinHigh.value : this.headwayMinHigh,
        routable: routable ?? this.routable,
        endpointsJson: endpointsJson ?? this.endpointsJson,
        directionsJson: directionsJson ?? this.directionsJson,
      );
  Route copyWithCompanion(RoutesCompanion data) {
    return Route(
      routeId: data.routeId.present ? data.routeId.value : this.routeId,
      mapLabel: data.mapLabel.present ? data.mapLabel.value : this.mapLabel,
      serviceType:
          data.serviceType.present ? data.serviceType.value : this.serviceType,
      lengthKm: data.lengthKm.present ? data.lengthKm.value : this.lengthKm,
      headwayMinLow: data.headwayMinLow.present
          ? data.headwayMinLow.value
          : this.headwayMinLow,
      headwayMinHigh: data.headwayMinHigh.present
          ? data.headwayMinHigh.value
          : this.headwayMinHigh,
      routable: data.routable.present ? data.routable.value : this.routable,
      endpointsJson: data.endpointsJson.present
          ? data.endpointsJson.value
          : this.endpointsJson,
      directionsJson: data.directionsJson.present
          ? data.directionsJson.value
          : this.directionsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Route(')
          ..write('routeId: $routeId, ')
          ..write('mapLabel: $mapLabel, ')
          ..write('serviceType: $serviceType, ')
          ..write('lengthKm: $lengthKm, ')
          ..write('headwayMinLow: $headwayMinLow, ')
          ..write('headwayMinHigh: $headwayMinHigh, ')
          ..write('routable: $routable, ')
          ..write('endpointsJson: $endpointsJson, ')
          ..write('directionsJson: $directionsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(routeId, mapLabel, serviceType, lengthKm,
      headwayMinLow, headwayMinHigh, routable, endpointsJson, directionsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Route &&
          other.routeId == this.routeId &&
          other.mapLabel == this.mapLabel &&
          other.serviceType == this.serviceType &&
          other.lengthKm == this.lengthKm &&
          other.headwayMinLow == this.headwayMinLow &&
          other.headwayMinHigh == this.headwayMinHigh &&
          other.routable == this.routable &&
          other.endpointsJson == this.endpointsJson &&
          other.directionsJson == this.directionsJson);
}

class RoutesCompanion extends UpdateCompanion<Route> {
  final Value<String> routeId;
  final Value<String?> mapLabel;
  final Value<String> serviceType;
  final Value<double?> lengthKm;
  final Value<int?> headwayMinLow;
  final Value<int?> headwayMinHigh;
  final Value<bool> routable;
  final Value<String> endpointsJson;
  final Value<String> directionsJson;
  final Value<int> rowid;
  const RoutesCompanion({
    this.routeId = const Value.absent(),
    this.mapLabel = const Value.absent(),
    this.serviceType = const Value.absent(),
    this.lengthKm = const Value.absent(),
    this.headwayMinLow = const Value.absent(),
    this.headwayMinHigh = const Value.absent(),
    this.routable = const Value.absent(),
    this.endpointsJson = const Value.absent(),
    this.directionsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutesCompanion.insert({
    required String routeId,
    this.mapLabel = const Value.absent(),
    required String serviceType,
    this.lengthKm = const Value.absent(),
    this.headwayMinLow = const Value.absent(),
    this.headwayMinHigh = const Value.absent(),
    required bool routable,
    this.endpointsJson = const Value.absent(),
    required String directionsJson,
    this.rowid = const Value.absent(),
  })  : routeId = Value(routeId),
        serviceType = Value(serviceType),
        routable = Value(routable),
        directionsJson = Value(directionsJson);
  static Insertable<Route> custom({
    Expression<String>? routeId,
    Expression<String>? mapLabel,
    Expression<String>? serviceType,
    Expression<double>? lengthKm,
    Expression<int>? headwayMinLow,
    Expression<int>? headwayMinHigh,
    Expression<bool>? routable,
    Expression<String>? endpointsJson,
    Expression<String>? directionsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (routeId != null) 'route_id': routeId,
      if (mapLabel != null) 'map_label': mapLabel,
      if (serviceType != null) 'service_type': serviceType,
      if (lengthKm != null) 'length_km': lengthKm,
      if (headwayMinLow != null) 'headway_min_low': headwayMinLow,
      if (headwayMinHigh != null) 'headway_min_high': headwayMinHigh,
      if (routable != null) 'routable': routable,
      if (endpointsJson != null) 'endpoints_json': endpointsJson,
      if (directionsJson != null) 'directions_json': directionsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutesCompanion copyWith(
      {Value<String>? routeId,
      Value<String?>? mapLabel,
      Value<String>? serviceType,
      Value<double?>? lengthKm,
      Value<int?>? headwayMinLow,
      Value<int?>? headwayMinHigh,
      Value<bool>? routable,
      Value<String>? endpointsJson,
      Value<String>? directionsJson,
      Value<int>? rowid}) {
    return RoutesCompanion(
      routeId: routeId ?? this.routeId,
      mapLabel: mapLabel ?? this.mapLabel,
      serviceType: serviceType ?? this.serviceType,
      lengthKm: lengthKm ?? this.lengthKm,
      headwayMinLow: headwayMinLow ?? this.headwayMinLow,
      headwayMinHigh: headwayMinHigh ?? this.headwayMinHigh,
      routable: routable ?? this.routable,
      endpointsJson: endpointsJson ?? this.endpointsJson,
      directionsJson: directionsJson ?? this.directionsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (routeId.present) {
      map['route_id'] = Variable<String>(routeId.value);
    }
    if (mapLabel.present) {
      map['map_label'] = Variable<String>(mapLabel.value);
    }
    if (serviceType.present) {
      map['service_type'] = Variable<String>(serviceType.value);
    }
    if (lengthKm.present) {
      map['length_km'] = Variable<double>(lengthKm.value);
    }
    if (headwayMinLow.present) {
      map['headway_min_low'] = Variable<int>(headwayMinLow.value);
    }
    if (headwayMinHigh.present) {
      map['headway_min_high'] = Variable<int>(headwayMinHigh.value);
    }
    if (routable.present) {
      map['routable'] = Variable<bool>(routable.value);
    }
    if (endpointsJson.present) {
      map['endpoints_json'] = Variable<String>(endpointsJson.value);
    }
    if (directionsJson.present) {
      map['directions_json'] = Variable<String>(directionsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutesCompanion(')
          ..write('routeId: $routeId, ')
          ..write('mapLabel: $mapLabel, ')
          ..write('serviceType: $serviceType, ')
          ..write('lengthKm: $lengthKm, ')
          ..write('headwayMinLow: $headwayMinLow, ')
          ..write('headwayMinHigh: $headwayMinHigh, ')
          ..write('routable: $routable, ')
          ..write('endpointsJson: $endpointsJson, ')
          ..write('directionsJson: $directionsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FareMetaTable extends FareMeta
    with TableInfo<$FareMetaTable, FareMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FareMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _basisMeta = const VerificationMeta('basis');
  @override
  late final GeneratedColumn<String> basis = GeneratedColumn<String>(
      'basis', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _singleJourneyTicketPkrMeta =
      const VerificationMeta('singleJourneyTicketPkr');
  @override
  late final GeneratedColumn<int> singleJourneyTicketPkr = GeneratedColumn<int>(
      'single_journey_ticket_pkr', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _feederExpressFlatFarePkrMeta =
      const VerificationMeta('feederExpressFlatFarePkr');
  @override
  late final GeneratedColumn<int> feederExpressFlatFarePkr =
      GeneratedColumn<int>('feeder_express_flat_fare_pkr', aliasedName, false,
          type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _bandsJsonMeta =
      const VerificationMeta('bandsJson');
  @override
  late final GeneratedColumn<String> bandsJson = GeneratedColumn<String>(
      'bands_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        currency,
        basis,
        singleJourneyTicketPkr,
        feederExpressFlatFarePkr,
        bandsJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fare_meta';
  @override
  VerificationContext validateIntegrity(Insertable<FareMetaData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('basis')) {
      context.handle(
          _basisMeta, basis.isAcceptableOrUnknown(data['basis']!, _basisMeta));
    } else if (isInserting) {
      context.missing(_basisMeta);
    }
    if (data.containsKey('single_journey_ticket_pkr')) {
      context.handle(
          _singleJourneyTicketPkrMeta,
          singleJourneyTicketPkr.isAcceptableOrUnknown(
              data['single_journey_ticket_pkr']!, _singleJourneyTicketPkrMeta));
    } else if (isInserting) {
      context.missing(_singleJourneyTicketPkrMeta);
    }
    if (data.containsKey('feeder_express_flat_fare_pkr')) {
      context.handle(
          _feederExpressFlatFarePkrMeta,
          feederExpressFlatFarePkr.isAcceptableOrUnknown(
              data['feeder_express_flat_fare_pkr']!,
              _feederExpressFlatFarePkrMeta));
    } else if (isInserting) {
      context.missing(_feederExpressFlatFarePkrMeta);
    }
    if (data.containsKey('bands_json')) {
      context.handle(_bandsJsonMeta,
          bandsJson.isAcceptableOrUnknown(data['bands_json']!, _bandsJsonMeta));
    } else if (isInserting) {
      context.missing(_bandsJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FareMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FareMetaData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      basis: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}basis'])!,
      singleJourneyTicketPkr: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}single_journey_ticket_pkr'])!,
      feederExpressFlatFarePkr: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}feeder_express_flat_fare_pkr'])!,
      bandsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bands_json'])!,
    );
  }

  @override
  $FareMetaTable createAlias(String alias) {
    return $FareMetaTable(attachedDatabase, alias);
  }
}

class FareMetaData extends DataClass implements Insertable<FareMetaData> {
  final int id;
  final String currency;
  final String basis;
  final int singleJourneyTicketPkr;
  final int feederExpressFlatFarePkr;
  final String bandsJson;
  const FareMetaData(
      {required this.id,
      required this.currency,
      required this.basis,
      required this.singleJourneyTicketPkr,
      required this.feederExpressFlatFarePkr,
      required this.bandsJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['currency'] = Variable<String>(currency);
    map['basis'] = Variable<String>(basis);
    map['single_journey_ticket_pkr'] = Variable<int>(singleJourneyTicketPkr);
    map['feeder_express_flat_fare_pkr'] =
        Variable<int>(feederExpressFlatFarePkr);
    map['bands_json'] = Variable<String>(bandsJson);
    return map;
  }

  FareMetaCompanion toCompanion(bool nullToAbsent) {
    return FareMetaCompanion(
      id: Value(id),
      currency: Value(currency),
      basis: Value(basis),
      singleJourneyTicketPkr: Value(singleJourneyTicketPkr),
      feederExpressFlatFarePkr: Value(feederExpressFlatFarePkr),
      bandsJson: Value(bandsJson),
    );
  }

  factory FareMetaData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FareMetaData(
      id: serializer.fromJson<int>(json['id']),
      currency: serializer.fromJson<String>(json['currency']),
      basis: serializer.fromJson<String>(json['basis']),
      singleJourneyTicketPkr:
          serializer.fromJson<int>(json['singleJourneyTicketPkr']),
      feederExpressFlatFarePkr:
          serializer.fromJson<int>(json['feederExpressFlatFarePkr']),
      bandsJson: serializer.fromJson<String>(json['bandsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'currency': serializer.toJson<String>(currency),
      'basis': serializer.toJson<String>(basis),
      'singleJourneyTicketPkr': serializer.toJson<int>(singleJourneyTicketPkr),
      'feederExpressFlatFarePkr':
          serializer.toJson<int>(feederExpressFlatFarePkr),
      'bandsJson': serializer.toJson<String>(bandsJson),
    };
  }

  FareMetaData copyWith(
          {int? id,
          String? currency,
          String? basis,
          int? singleJourneyTicketPkr,
          int? feederExpressFlatFarePkr,
          String? bandsJson}) =>
      FareMetaData(
        id: id ?? this.id,
        currency: currency ?? this.currency,
        basis: basis ?? this.basis,
        singleJourneyTicketPkr:
            singleJourneyTicketPkr ?? this.singleJourneyTicketPkr,
        feederExpressFlatFarePkr:
            feederExpressFlatFarePkr ?? this.feederExpressFlatFarePkr,
        bandsJson: bandsJson ?? this.bandsJson,
      );
  FareMetaData copyWithCompanion(FareMetaCompanion data) {
    return FareMetaData(
      id: data.id.present ? data.id.value : this.id,
      currency: data.currency.present ? data.currency.value : this.currency,
      basis: data.basis.present ? data.basis.value : this.basis,
      singleJourneyTicketPkr: data.singleJourneyTicketPkr.present
          ? data.singleJourneyTicketPkr.value
          : this.singleJourneyTicketPkr,
      feederExpressFlatFarePkr: data.feederExpressFlatFarePkr.present
          ? data.feederExpressFlatFarePkr.value
          : this.feederExpressFlatFarePkr,
      bandsJson: data.bandsJson.present ? data.bandsJson.value : this.bandsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FareMetaData(')
          ..write('id: $id, ')
          ..write('currency: $currency, ')
          ..write('basis: $basis, ')
          ..write('singleJourneyTicketPkr: $singleJourneyTicketPkr, ')
          ..write('feederExpressFlatFarePkr: $feederExpressFlatFarePkr, ')
          ..write('bandsJson: $bandsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, currency, basis, singleJourneyTicketPkr,
      feederExpressFlatFarePkr, bandsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FareMetaData &&
          other.id == this.id &&
          other.currency == this.currency &&
          other.basis == this.basis &&
          other.singleJourneyTicketPkr == this.singleJourneyTicketPkr &&
          other.feederExpressFlatFarePkr == this.feederExpressFlatFarePkr &&
          other.bandsJson == this.bandsJson);
}

class FareMetaCompanion extends UpdateCompanion<FareMetaData> {
  final Value<int> id;
  final Value<String> currency;
  final Value<String> basis;
  final Value<int> singleJourneyTicketPkr;
  final Value<int> feederExpressFlatFarePkr;
  final Value<String> bandsJson;
  const FareMetaCompanion({
    this.id = const Value.absent(),
    this.currency = const Value.absent(),
    this.basis = const Value.absent(),
    this.singleJourneyTicketPkr = const Value.absent(),
    this.feederExpressFlatFarePkr = const Value.absent(),
    this.bandsJson = const Value.absent(),
  });
  FareMetaCompanion.insert({
    this.id = const Value.absent(),
    required String currency,
    required String basis,
    required int singleJourneyTicketPkr,
    required int feederExpressFlatFarePkr,
    required String bandsJson,
  })  : currency = Value(currency),
        basis = Value(basis),
        singleJourneyTicketPkr = Value(singleJourneyTicketPkr),
        feederExpressFlatFarePkr = Value(feederExpressFlatFarePkr),
        bandsJson = Value(bandsJson);
  static Insertable<FareMetaData> custom({
    Expression<int>? id,
    Expression<String>? currency,
    Expression<String>? basis,
    Expression<int>? singleJourneyTicketPkr,
    Expression<int>? feederExpressFlatFarePkr,
    Expression<String>? bandsJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currency != null) 'currency': currency,
      if (basis != null) 'basis': basis,
      if (singleJourneyTicketPkr != null)
        'single_journey_ticket_pkr': singleJourneyTicketPkr,
      if (feederExpressFlatFarePkr != null)
        'feeder_express_flat_fare_pkr': feederExpressFlatFarePkr,
      if (bandsJson != null) 'bands_json': bandsJson,
    });
  }

  FareMetaCompanion copyWith(
      {Value<int>? id,
      Value<String>? currency,
      Value<String>? basis,
      Value<int>? singleJourneyTicketPkr,
      Value<int>? feederExpressFlatFarePkr,
      Value<String>? bandsJson}) {
    return FareMetaCompanion(
      id: id ?? this.id,
      currency: currency ?? this.currency,
      basis: basis ?? this.basis,
      singleJourneyTicketPkr:
          singleJourneyTicketPkr ?? this.singleJourneyTicketPkr,
      feederExpressFlatFarePkr:
          feederExpressFlatFarePkr ?? this.feederExpressFlatFarePkr,
      bandsJson: bandsJson ?? this.bandsJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (basis.present) {
      map['basis'] = Variable<String>(basis.value);
    }
    if (singleJourneyTicketPkr.present) {
      map['single_journey_ticket_pkr'] =
          Variable<int>(singleJourneyTicketPkr.value);
    }
    if (feederExpressFlatFarePkr.present) {
      map['feeder_express_flat_fare_pkr'] =
          Variable<int>(feederExpressFlatFarePkr.value);
    }
    if (bandsJson.present) {
      map['bands_json'] = Variable<String>(bandsJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FareMetaCompanion(')
          ..write('id: $id, ')
          ..write('currency: $currency, ')
          ..write('basis: $basis, ')
          ..write('singleJourneyTicketPkr: $singleJourneyTicketPkr, ')
          ..write('feederExpressFlatFarePkr: $feederExpressFlatFarePkr, ')
          ..write('bandsJson: $bandsJson')
          ..write(')'))
        .toString();
  }
}

class $ServiceHoursTableTable extends ServiceHoursTable
    with TableInfo<$ServiceHoursTableTable, ServiceHoursTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServiceHoursTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _opensMeta = const VerificationMeta('opens');
  @override
  late final GeneratedColumn<String> opens = GeneratedColumn<String>(
      'opens', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _closesMeta = const VerificationMeta('closes');
  @override
  late final GeneratedColumn<String> closes = GeneratedColumn<String>(
      'closes', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, opens, closes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'service_hours_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<ServiceHoursTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('opens')) {
      context.handle(
          _opensMeta, opens.isAcceptableOrUnknown(data['opens']!, _opensMeta));
    } else if (isInserting) {
      context.missing(_opensMeta);
    }
    if (data.containsKey('closes')) {
      context.handle(_closesMeta,
          closes.isAcceptableOrUnknown(data['closes']!, _closesMeta));
    } else if (isInserting) {
      context.missing(_closesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServiceHoursTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServiceHoursTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      opens: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}opens'])!,
      closes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}closes'])!,
    );
  }

  @override
  $ServiceHoursTableTable createAlias(String alias) {
    return $ServiceHoursTableTable(attachedDatabase, alias);
  }
}

class ServiceHoursTableData extends DataClass
    implements Insertable<ServiceHoursTableData> {
  final int id;
  final String opens;
  final String closes;
  const ServiceHoursTableData(
      {required this.id, required this.opens, required this.closes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['opens'] = Variable<String>(opens);
    map['closes'] = Variable<String>(closes);
    return map;
  }

  ServiceHoursTableCompanion toCompanion(bool nullToAbsent) {
    return ServiceHoursTableCompanion(
      id: Value(id),
      opens: Value(opens),
      closes: Value(closes),
    );
  }

  factory ServiceHoursTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServiceHoursTableData(
      id: serializer.fromJson<int>(json['id']),
      opens: serializer.fromJson<String>(json['opens']),
      closes: serializer.fromJson<String>(json['closes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'opens': serializer.toJson<String>(opens),
      'closes': serializer.toJson<String>(closes),
    };
  }

  ServiceHoursTableData copyWith({int? id, String? opens, String? closes}) =>
      ServiceHoursTableData(
        id: id ?? this.id,
        opens: opens ?? this.opens,
        closes: closes ?? this.closes,
      );
  ServiceHoursTableData copyWithCompanion(ServiceHoursTableCompanion data) {
    return ServiceHoursTableData(
      id: data.id.present ? data.id.value : this.id,
      opens: data.opens.present ? data.opens.value : this.opens,
      closes: data.closes.present ? data.closes.value : this.closes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServiceHoursTableData(')
          ..write('id: $id, ')
          ..write('opens: $opens, ')
          ..write('closes: $closes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, opens, closes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceHoursTableData &&
          other.id == this.id &&
          other.opens == this.opens &&
          other.closes == this.closes);
}

class ServiceHoursTableCompanion
    extends UpdateCompanion<ServiceHoursTableData> {
  final Value<int> id;
  final Value<String> opens;
  final Value<String> closes;
  const ServiceHoursTableCompanion({
    this.id = const Value.absent(),
    this.opens = const Value.absent(),
    this.closes = const Value.absent(),
  });
  ServiceHoursTableCompanion.insert({
    this.id = const Value.absent(),
    required String opens,
    required String closes,
  })  : opens = Value(opens),
        closes = Value(closes);
  static Insertable<ServiceHoursTableData> custom({
    Expression<int>? id,
    Expression<String>? opens,
    Expression<String>? closes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (opens != null) 'opens': opens,
      if (closes != null) 'closes': closes,
    });
  }

  ServiceHoursTableCompanion copyWith(
      {Value<int>? id, Value<String>? opens, Value<String>? closes}) {
    return ServiceHoursTableCompanion(
      id: id ?? this.id,
      opens: opens ?? this.opens,
      closes: closes ?? this.closes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (opens.present) {
      map['opens'] = Variable<String>(opens.value);
    }
    if (closes.present) {
      map['closes'] = Variable<String>(closes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServiceHoursTableCompanion(')
          ..write('id: $id, ')
          ..write('opens: $opens, ')
          ..write('closes: $closes')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StationsTable stations = $StationsTable(this);
  late final $RoutesTable routes = $RoutesTable(this);
  late final $FareMetaTable fareMeta = $FareMetaTable(this);
  late final $ServiceHoursTableTable serviceHoursTable =
      $ServiceHoursTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [stations, routes, fareMeta, serviceHoursTable];
}

typedef $$StationsTableCreateCompanionBuilder = StationsCompanion Function({
  required String stationId,
  required String name,
  Value<String> aliasesJson,
  Value<String> urduJson,
  Value<String> pashtoJson,
  Value<String> servedByJson,
  Value<int> rowid,
});
typedef $$StationsTableUpdateCompanionBuilder = StationsCompanion Function({
  Value<String> stationId,
  Value<String> name,
  Value<String> aliasesJson,
  Value<String> urduJson,
  Value<String> pashtoJson,
  Value<String> servedByJson,
  Value<int> rowid,
});

class $$StationsTableFilterComposer
    extends Composer<_$AppDatabase, $StationsTable> {
  $$StationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get stationId => $composableBuilder(
      column: $table.stationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get aliasesJson => $composableBuilder(
      column: $table.aliasesJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get urduJson => $composableBuilder(
      column: $table.urduJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pashtoJson => $composableBuilder(
      column: $table.pashtoJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get servedByJson => $composableBuilder(
      column: $table.servedByJson, builder: (column) => ColumnFilters(column));
}

class $$StationsTableOrderingComposer
    extends Composer<_$AppDatabase, $StationsTable> {
  $$StationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get stationId => $composableBuilder(
      column: $table.stationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get aliasesJson => $composableBuilder(
      column: $table.aliasesJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get urduJson => $composableBuilder(
      column: $table.urduJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pashtoJson => $composableBuilder(
      column: $table.pashtoJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get servedByJson => $composableBuilder(
      column: $table.servedByJson,
      builder: (column) => ColumnOrderings(column));
}

class $$StationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StationsTable> {
  $$StationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get stationId =>
      $composableBuilder(column: $table.stationId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get aliasesJson => $composableBuilder(
      column: $table.aliasesJson, builder: (column) => column);

  GeneratedColumn<String> get urduJson =>
      $composableBuilder(column: $table.urduJson, builder: (column) => column);

  GeneratedColumn<String> get pashtoJson => $composableBuilder(
      column: $table.pashtoJson, builder: (column) => column);

  GeneratedColumn<String> get servedByJson => $composableBuilder(
      column: $table.servedByJson, builder: (column) => column);
}

class $$StationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StationsTable,
    Station,
    $$StationsTableFilterComposer,
    $$StationsTableOrderingComposer,
    $$StationsTableAnnotationComposer,
    $$StationsTableCreateCompanionBuilder,
    $$StationsTableUpdateCompanionBuilder,
    (Station, BaseReferences<_$AppDatabase, $StationsTable, Station>),
    Station,
    PrefetchHooks Function()> {
  $$StationsTableTableManager(_$AppDatabase db, $StationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> stationId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> aliasesJson = const Value.absent(),
            Value<String> urduJson = const Value.absent(),
            Value<String> pashtoJson = const Value.absent(),
            Value<String> servedByJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StationsCompanion(
            stationId: stationId,
            name: name,
            aliasesJson: aliasesJson,
            urduJson: urduJson,
            pashtoJson: pashtoJson,
            servedByJson: servedByJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String stationId,
            required String name,
            Value<String> aliasesJson = const Value.absent(),
            Value<String> urduJson = const Value.absent(),
            Value<String> pashtoJson = const Value.absent(),
            Value<String> servedByJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StationsCompanion.insert(
            stationId: stationId,
            name: name,
            aliasesJson: aliasesJson,
            urduJson: urduJson,
            pashtoJson: pashtoJson,
            servedByJson: servedByJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$StationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StationsTable,
    Station,
    $$StationsTableFilterComposer,
    $$StationsTableOrderingComposer,
    $$StationsTableAnnotationComposer,
    $$StationsTableCreateCompanionBuilder,
    $$StationsTableUpdateCompanionBuilder,
    (Station, BaseReferences<_$AppDatabase, $StationsTable, Station>),
    Station,
    PrefetchHooks Function()>;
typedef $$RoutesTableCreateCompanionBuilder = RoutesCompanion Function({
  required String routeId,
  Value<String?> mapLabel,
  required String serviceType,
  Value<double?> lengthKm,
  Value<int?> headwayMinLow,
  Value<int?> headwayMinHigh,
  required bool routable,
  Value<String> endpointsJson,
  required String directionsJson,
  Value<int> rowid,
});
typedef $$RoutesTableUpdateCompanionBuilder = RoutesCompanion Function({
  Value<String> routeId,
  Value<String?> mapLabel,
  Value<String> serviceType,
  Value<double?> lengthKm,
  Value<int?> headwayMinLow,
  Value<int?> headwayMinHigh,
  Value<bool> routable,
  Value<String> endpointsJson,
  Value<String> directionsJson,
  Value<int> rowid,
});

class $$RoutesTableFilterComposer
    extends Composer<_$AppDatabase, $RoutesTable> {
  $$RoutesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get routeId => $composableBuilder(
      column: $table.routeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mapLabel => $composableBuilder(
      column: $table.mapLabel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serviceType => $composableBuilder(
      column: $table.serviceType, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lengthKm => $composableBuilder(
      column: $table.lengthKm, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get headwayMinLow => $composableBuilder(
      column: $table.headwayMinLow, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get headwayMinHigh => $composableBuilder(
      column: $table.headwayMinHigh,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get routable => $composableBuilder(
      column: $table.routable, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endpointsJson => $composableBuilder(
      column: $table.endpointsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get directionsJson => $composableBuilder(
      column: $table.directionsJson,
      builder: (column) => ColumnFilters(column));
}

class $$RoutesTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutesTable> {
  $$RoutesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get routeId => $composableBuilder(
      column: $table.routeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mapLabel => $composableBuilder(
      column: $table.mapLabel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serviceType => $composableBuilder(
      column: $table.serviceType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lengthKm => $composableBuilder(
      column: $table.lengthKm, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get headwayMinLow => $composableBuilder(
      column: $table.headwayMinLow,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get headwayMinHigh => $composableBuilder(
      column: $table.headwayMinHigh,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get routable => $composableBuilder(
      column: $table.routable, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endpointsJson => $composableBuilder(
      column: $table.endpointsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get directionsJson => $composableBuilder(
      column: $table.directionsJson,
      builder: (column) => ColumnOrderings(column));
}

class $$RoutesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutesTable> {
  $$RoutesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get routeId =>
      $composableBuilder(column: $table.routeId, builder: (column) => column);

  GeneratedColumn<String> get mapLabel =>
      $composableBuilder(column: $table.mapLabel, builder: (column) => column);

  GeneratedColumn<String> get serviceType => $composableBuilder(
      column: $table.serviceType, builder: (column) => column);

  GeneratedColumn<double> get lengthKm =>
      $composableBuilder(column: $table.lengthKm, builder: (column) => column);

  GeneratedColumn<int> get headwayMinLow => $composableBuilder(
      column: $table.headwayMinLow, builder: (column) => column);

  GeneratedColumn<int> get headwayMinHigh => $composableBuilder(
      column: $table.headwayMinHigh, builder: (column) => column);

  GeneratedColumn<bool> get routable =>
      $composableBuilder(column: $table.routable, builder: (column) => column);

  GeneratedColumn<String> get endpointsJson => $composableBuilder(
      column: $table.endpointsJson, builder: (column) => column);

  GeneratedColumn<String> get directionsJson => $composableBuilder(
      column: $table.directionsJson, builder: (column) => column);
}

class $$RoutesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RoutesTable,
    Route,
    $$RoutesTableFilterComposer,
    $$RoutesTableOrderingComposer,
    $$RoutesTableAnnotationComposer,
    $$RoutesTableCreateCompanionBuilder,
    $$RoutesTableUpdateCompanionBuilder,
    (Route, BaseReferences<_$AppDatabase, $RoutesTable, Route>),
    Route,
    PrefetchHooks Function()> {
  $$RoutesTableTableManager(_$AppDatabase db, $RoutesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> routeId = const Value.absent(),
            Value<String?> mapLabel = const Value.absent(),
            Value<String> serviceType = const Value.absent(),
            Value<double?> lengthKm = const Value.absent(),
            Value<int?> headwayMinLow = const Value.absent(),
            Value<int?> headwayMinHigh = const Value.absent(),
            Value<bool> routable = const Value.absent(),
            Value<String> endpointsJson = const Value.absent(),
            Value<String> directionsJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RoutesCompanion(
            routeId: routeId,
            mapLabel: mapLabel,
            serviceType: serviceType,
            lengthKm: lengthKm,
            headwayMinLow: headwayMinLow,
            headwayMinHigh: headwayMinHigh,
            routable: routable,
            endpointsJson: endpointsJson,
            directionsJson: directionsJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String routeId,
            Value<String?> mapLabel = const Value.absent(),
            required String serviceType,
            Value<double?> lengthKm = const Value.absent(),
            Value<int?> headwayMinLow = const Value.absent(),
            Value<int?> headwayMinHigh = const Value.absent(),
            required bool routable,
            Value<String> endpointsJson = const Value.absent(),
            required String directionsJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              RoutesCompanion.insert(
            routeId: routeId,
            mapLabel: mapLabel,
            serviceType: serviceType,
            lengthKm: lengthKm,
            headwayMinLow: headwayMinLow,
            headwayMinHigh: headwayMinHigh,
            routable: routable,
            endpointsJson: endpointsJson,
            directionsJson: directionsJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RoutesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RoutesTable,
    Route,
    $$RoutesTableFilterComposer,
    $$RoutesTableOrderingComposer,
    $$RoutesTableAnnotationComposer,
    $$RoutesTableCreateCompanionBuilder,
    $$RoutesTableUpdateCompanionBuilder,
    (Route, BaseReferences<_$AppDatabase, $RoutesTable, Route>),
    Route,
    PrefetchHooks Function()>;
typedef $$FareMetaTableCreateCompanionBuilder = FareMetaCompanion Function({
  Value<int> id,
  required String currency,
  required String basis,
  required int singleJourneyTicketPkr,
  required int feederExpressFlatFarePkr,
  required String bandsJson,
});
typedef $$FareMetaTableUpdateCompanionBuilder = FareMetaCompanion Function({
  Value<int> id,
  Value<String> currency,
  Value<String> basis,
  Value<int> singleJourneyTicketPkr,
  Value<int> feederExpressFlatFarePkr,
  Value<String> bandsJson,
});

class $$FareMetaTableFilterComposer
    extends Composer<_$AppDatabase, $FareMetaTable> {
  $$FareMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get basis => $composableBuilder(
      column: $table.basis, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get singleJourneyTicketPkr => $composableBuilder(
      column: $table.singleJourneyTicketPkr,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get feederExpressFlatFarePkr => $composableBuilder(
      column: $table.feederExpressFlatFarePkr,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bandsJson => $composableBuilder(
      column: $table.bandsJson, builder: (column) => ColumnFilters(column));
}

class $$FareMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $FareMetaTable> {
  $$FareMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get basis => $composableBuilder(
      column: $table.basis, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get singleJourneyTicketPkr => $composableBuilder(
      column: $table.singleJourneyTicketPkr,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get feederExpressFlatFarePkr => $composableBuilder(
      column: $table.feederExpressFlatFarePkr,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bandsJson => $composableBuilder(
      column: $table.bandsJson, builder: (column) => ColumnOrderings(column));
}

class $$FareMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $FareMetaTable> {
  $$FareMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get basis =>
      $composableBuilder(column: $table.basis, builder: (column) => column);

  GeneratedColumn<int> get singleJourneyTicketPkr => $composableBuilder(
      column: $table.singleJourneyTicketPkr, builder: (column) => column);

  GeneratedColumn<int> get feederExpressFlatFarePkr => $composableBuilder(
      column: $table.feederExpressFlatFarePkr, builder: (column) => column);

  GeneratedColumn<String> get bandsJson =>
      $composableBuilder(column: $table.bandsJson, builder: (column) => column);
}

class $$FareMetaTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FareMetaTable,
    FareMetaData,
    $$FareMetaTableFilterComposer,
    $$FareMetaTableOrderingComposer,
    $$FareMetaTableAnnotationComposer,
    $$FareMetaTableCreateCompanionBuilder,
    $$FareMetaTableUpdateCompanionBuilder,
    (FareMetaData, BaseReferences<_$AppDatabase, $FareMetaTable, FareMetaData>),
    FareMetaData,
    PrefetchHooks Function()> {
  $$FareMetaTableTableManager(_$AppDatabase db, $FareMetaTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FareMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FareMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FareMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String> basis = const Value.absent(),
            Value<int> singleJourneyTicketPkr = const Value.absent(),
            Value<int> feederExpressFlatFarePkr = const Value.absent(),
            Value<String> bandsJson = const Value.absent(),
          }) =>
              FareMetaCompanion(
            id: id,
            currency: currency,
            basis: basis,
            singleJourneyTicketPkr: singleJourneyTicketPkr,
            feederExpressFlatFarePkr: feederExpressFlatFarePkr,
            bandsJson: bandsJson,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String currency,
            required String basis,
            required int singleJourneyTicketPkr,
            required int feederExpressFlatFarePkr,
            required String bandsJson,
          }) =>
              FareMetaCompanion.insert(
            id: id,
            currency: currency,
            basis: basis,
            singleJourneyTicketPkr: singleJourneyTicketPkr,
            feederExpressFlatFarePkr: feederExpressFlatFarePkr,
            bandsJson: bandsJson,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FareMetaTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FareMetaTable,
    FareMetaData,
    $$FareMetaTableFilterComposer,
    $$FareMetaTableOrderingComposer,
    $$FareMetaTableAnnotationComposer,
    $$FareMetaTableCreateCompanionBuilder,
    $$FareMetaTableUpdateCompanionBuilder,
    (FareMetaData, BaseReferences<_$AppDatabase, $FareMetaTable, FareMetaData>),
    FareMetaData,
    PrefetchHooks Function()>;
typedef $$ServiceHoursTableTableCreateCompanionBuilder
    = ServiceHoursTableCompanion Function({
  Value<int> id,
  required String opens,
  required String closes,
});
typedef $$ServiceHoursTableTableUpdateCompanionBuilder
    = ServiceHoursTableCompanion Function({
  Value<int> id,
  Value<String> opens,
  Value<String> closes,
});

class $$ServiceHoursTableTableFilterComposer
    extends Composer<_$AppDatabase, $ServiceHoursTableTable> {
  $$ServiceHoursTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get opens => $composableBuilder(
      column: $table.opens, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get closes => $composableBuilder(
      column: $table.closes, builder: (column) => ColumnFilters(column));
}

class $$ServiceHoursTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ServiceHoursTableTable> {
  $$ServiceHoursTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get opens => $composableBuilder(
      column: $table.opens, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get closes => $composableBuilder(
      column: $table.closes, builder: (column) => ColumnOrderings(column));
}

class $$ServiceHoursTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServiceHoursTableTable> {
  $$ServiceHoursTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get opens =>
      $composableBuilder(column: $table.opens, builder: (column) => column);

  GeneratedColumn<String> get closes =>
      $composableBuilder(column: $table.closes, builder: (column) => column);
}

class $$ServiceHoursTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ServiceHoursTableTable,
    ServiceHoursTableData,
    $$ServiceHoursTableTableFilterComposer,
    $$ServiceHoursTableTableOrderingComposer,
    $$ServiceHoursTableTableAnnotationComposer,
    $$ServiceHoursTableTableCreateCompanionBuilder,
    $$ServiceHoursTableTableUpdateCompanionBuilder,
    (
      ServiceHoursTableData,
      BaseReferences<_$AppDatabase, $ServiceHoursTableTable,
          ServiceHoursTableData>
    ),
    ServiceHoursTableData,
    PrefetchHooks Function()> {
  $$ServiceHoursTableTableTableManager(
      _$AppDatabase db, $ServiceHoursTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServiceHoursTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServiceHoursTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServiceHoursTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> opens = const Value.absent(),
            Value<String> closes = const Value.absent(),
          }) =>
              ServiceHoursTableCompanion(
            id: id,
            opens: opens,
            closes: closes,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String opens,
            required String closes,
          }) =>
              ServiceHoursTableCompanion.insert(
            id: id,
            opens: opens,
            closes: closes,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ServiceHoursTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ServiceHoursTableTable,
    ServiceHoursTableData,
    $$ServiceHoursTableTableFilterComposer,
    $$ServiceHoursTableTableOrderingComposer,
    $$ServiceHoursTableTableAnnotationComposer,
    $$ServiceHoursTableTableCreateCompanionBuilder,
    $$ServiceHoursTableTableUpdateCompanionBuilder,
    (
      ServiceHoursTableData,
      BaseReferences<_$AppDatabase, $ServiceHoursTableTable,
          ServiceHoursTableData>
    ),
    ServiceHoursTableData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StationsTableTableManager get stations =>
      $$StationsTableTableManager(_db, _db.stations);
  $$RoutesTableTableManager get routes =>
      $$RoutesTableTableManager(_db, _db.routes);
  $$FareMetaTableTableManager get fareMeta =>
      $$FareMetaTableTableManager(_db, _db.fareMeta);
  $$ServiceHoursTableTableTableManager get serviceHoursTable =>
      $$ServiceHoursTableTableTableManager(_db, _db.serviceHoursTable);
}
