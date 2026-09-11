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
