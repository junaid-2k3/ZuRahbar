import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zurehbar_app/api/local_assistant.dart';
import 'package:zurehbar_app/models/fares.dart';
import 'package:zurehbar_app/models/station.dart';
import 'package:zurehbar_app/models/zu_route.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';
import 'package:zurehbar_app/routing/network_graph.dart';
import 'package:zurehbar_app/routing/station_resolver.dart';

/// Exercises routing against the real dataset in assets/data/, which the unit
/// tests (inline fixtures) never touch. Regenerate it with
/// `python -m zurehbar.pipeline --only export-app`.
void main() {
  late JourneyPlanner planner;
  late StationResolver resolver;
  late List<Station> stations;

  setUpAll(() {
    String read(String name) => File('assets/data/$name').readAsStringSync();
    stations = (jsonDecode(read('stations.json')) as List)
        .map((raw) => Station.fromJson(raw as Map<String, dynamic>))
        .toList();
    final routes = (jsonDecode(read('routes.json')) as List)
        .map((raw) => ZuRoute.fromJson(raw as Map<String, dynamic>))
        .toList();
    final fares = Fares.fromJson(jsonDecode(read('fares.json')) as Map<String, dynamic>);
    resolver = StationResolver(stations);
    planner = JourneyPlanner(NetworkGraph.build(routes, stations), resolver, fares);
  });

  test('a one-seat ride down the main corridor is priced by distance', () {
    final plan = planner.plan('Chamkani', 'Karkhano Market');
    expect(plan.found, isTrue);
    expect(plan.legs.map((leg) => leg.routeId), ['ER-01']);
    expect(plan.fare!.distanceKm, 27.0);
    expect(plan.fare!.totalPkr, 60);
    expect(plan.fare!.isEstimate, isTrue);
  });

  test('a trip off the corridor transfers onto it', () {
    final plan = planner.plan('Abasyn University', 'Chamkani');
    expect(plan.found, isTrue);
    expect(plan.legs, hasLength(2));
    // Both legs are priced once on the whole trip's distance, never summed.
    expect(plan.fare!.distanceKm, closeTo(11.59, 0.01));
    expect(plan.legs.first.alightStation, plan.legs.last.boardStation);
  });

  test('loosely typed and misspelled stop names still resolve (FR-1.3)', () {
    for (final trip in [
      ['uni town', 'saddar'],
      ['hashnagri', 'sadar'],
      ['karkhano', 'chamkani'],
      ['board bazaar', 'saddar'],
      ['islamia collage', 'dabgari'],
    ]) {
      final plan = planner.plan(trip[0], trip[1]);
      expect(plan.found, isTrue, reason: '${trip[0]} -> ${trip[1]} did not route');
      expect(plan.fare, isNotNull);
    }
  });

  test('an Urdu-script stop name resolves', () {
    final plan = planner.plan('ابا سین یونیورسٹی', 'Chamkani');
    expect(plan.found, isTrue);
    expect(plan.origin, 'Abasyn University');
  });

  test('a location that is not a Zu stop is refused, not guessed at', () {
    final plan = planner.plan('Nowhere Town', 'Saddar');
    expect(plan.found, isFalse);
    expect(plan.message, contains('No Zu station matches'));
  });

  test('identical origin and destination is called out (FR-9.2)', () {
    final plan = planner.plan('Chamkani', 'Chamkani');
    expect(plan.found, isFalse);
    expect(plan.message, contains('same station'));
  });

  test('every station in the dataset resolves to itself by its own name', () {
    final failures = [
      for (final station in stations)
        if (resolver.resolve(station.name).stationId != station.stationId) station.name,
    ];
    expect(failures, isEmpty);
  });

  test('a sentence with several "to"s splits on the right one', () {
    // Typed on a real phone during testing: the first " to " is inside the
    // filler, and both real stop names follow it.
    final extracted = LocalAssistant.extract(
      'I have to Fast University to Saddar Bazar',
      isStop: (name) => resolver.resolve(name).isExact,
    );
    expect(extracted.origin, 'Fast University');
    expect(extracted.destination, 'Saddar Bazar');

    final plan = planner.plan(extracted.origin!, extracted.destination!);
    expect(plan.found, isTrue);
    expect(plan.fare, isNotNull);
  });

  test('other ways riders phrase the same trip all land on the same stops', () {
    for (final query in [
      'how do I get from Fast University to Saddar Bazar',
      'I want to go to Saddar Bazar from Fast University',
      'Fast University se Saddar Bazar',
      'fast uni to saddar',
    ]) {
      final extracted = LocalAssistant.extract(
        query,
        isStop: (name) => resolver.resolve(name).isExact,
      );
      expect(extracted.origin, isNotNull, reason: 'no origin from "$query"');
      expect(extracted.destination, isNotNull, reason: 'no destination from "$query"');
      final plan = planner.plan(extracted.origin!, extracted.destination!);
      expect(plan.found, isTrue, reason: '"$query" did not route');
    }
  });

  test('off-hours queries still route and say the service is closed (FR-9.3)', () {
    final plan = planner.plan(
      'Hashtnagri',
      'Saddar',
      timeOfDay: '23:30',
      dayOfWeek: 'monday',
    );
    expect(plan.found, isTrue);
    expect(plan.serviceAvailable, isFalse);
    expect(plan.warnings.join(' '), contains('service hours'));
  });
}
