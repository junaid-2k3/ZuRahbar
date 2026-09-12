import 'package:flutter_test/flutter_test.dart';
import 'package:zurehbar_app/api/local_assistant.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';

void main() {
  group('extraction', () {
    test('splits "X to Y"', () {
      final extracted = LocalAssistant.extract('University Town to Saddar');
      expect(extracted.origin, 'University Town');
      expect(extracted.destination, 'Saddar');
      expect(extracted.intent, 'route');
    });

    test('strips an English lead-in', () {
      final extracted = LocalAssistant.extract('How do I get from Hashtnagri to Chamkani?');
      expect(extracted.origin, 'Hashtnagri');
      expect(extracted.destination, 'Chamkani');
    });

    test('handles Roman Urdu "se"', () {
      final extracted = LocalAssistant.extract('Saddar se Board Bazar');
      expect(extracted.origin, 'Saddar');
      expect(extracted.destination, 'Board Bazar');
    });

    test('flags a fare question', () {
      final extracted = LocalAssistant.extract('Fare from Saddar to Chamkani');
      expect(extracted.intent, 'fare');
      expect(extracted.origin, 'Saddar');
    });

    test('a bare destination leaves the origin for session context', () {
      final extracted = LocalAssistant.extract('Chamkani');
      expect(extracted.origin, isNull);
      expect(extracted.destination, 'Chamkani');
    });

    test('recognises "there" as a pointer, not a stop', () {
      expect(LocalAssistant.isAnaphoric('there'), isTrue);
      expect(LocalAssistant.isAnaphoric('Chamkani'), isFalse);
    });
  });

  group('phrasing', () {
    Leg leg(String routeId, String from, String to) => Leg(
          routeId: routeId,
          serviceType: 'express',
          boardStationId: from.toLowerCase(),
          boardStation: from,
          alightStationId: to.toLowerCase(),
          alightStation: to,
          stopCount: 3,
          rideTimeMin: 12.0,
          waitTimeMin: 3.0,
          distanceKm: 4.0,
          headwayMinLow: 4,
          headwayMinHigh: 6,
        );

    test('a one-leg plan reads as a single instruction with fare and frequency', () {
      final plan = JourneyPlan(
        found: true,
        origin: 'Alpha',
        destination: 'Bravo',
        legs: [leg('ER-01', 'Alpha', 'Bravo')],
        totalTimeMin: 15.0,
        fare: FareBreakdown(
          totalPkr: 30,
          basis: 'distance_band',
          distanceKm: 4.0,
          bandIndex: 1,
          isEstimate: true,
          note: 'Band 1 applies.',
        ),
      );

      final reply = LocalAssistant.phrase(plan);
      expect(reply, contains('Take ER-01 from Alpha to Bravo'));
      expect(reply, contains('Rs. 30'));
      expect(reply, contains('every 4–6 minutes'));
    });

    test('a two-leg plan names the transfer point', () {
      final plan = JourneyPlan(
        found: true,
        origin: 'Alpha',
        destination: 'Delta',
        legs: [leg('ER-01', 'Alpha', 'Bravo'), leg('SR-08', 'Bravo', 'Delta')],
        totalTimeMin: 33.0,
      );

      expect(LocalAssistant.phrase(plan), contains('Change at Bravo'));
    });

    test('a failed plan repeats the planner message and its warnings', () {
      final plan = JourneyPlan(
        found: false,
        origin: 'Alpha',
        destination: 'Nowhere',
        message: 'No Zu station matches "Nowhere".',
        warnings: const ['Did you mean: Alpha?'],
      );

      final reply = LocalAssistant.phrase(plan);
      expect(reply, contains('No Zu station matches'));
      expect(reply, contains('Did you mean'));
    });
  });
}
