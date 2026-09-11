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
