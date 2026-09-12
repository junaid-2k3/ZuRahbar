import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zurehbar_app/data/database.dart';
import 'package:zurehbar_app/data/dataset_repository.dart';
import 'package:zurehbar_app/main.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';
import 'package:zurehbar_app/routing/network_graph.dart';
import 'package:zurehbar_app/routing/station_resolver.dart';
import 'package:zurehbar_app/ui/answer_card.dart';
import 'package:zurehbar_app/ui/chat_controller.dart';

/// Boots the real widget tree over the real bundled dataset, with no backend —
/// the same path a demo build with no API key takes.
///
/// Seeding touches real sqlite, so it has to run through [WidgetTester.runAsync]:
/// inside the test's fake-async zone those futures never complete and the test
/// simply hangs.
Future<ZuRehbarApp> _bootApp(WidgetTester tester) async {
  late ZuRehbarApp app;
  await tester.runAsync(() async => app = await _build());
  return app;
}

Future<ZuRehbarApp> _build() async {
  final db = AppDatabase(openConnection());
  await DatasetRepository.seedIfEmpty(
    db,
    stationsJson: await rootBundle.loadString('assets/data/stations.json'),
    routesJson: await rootBundle.loadString('assets/data/routes.json'),
    faresJson: await rootBundle.loadString('assets/data/fares.json'),
    serviceHoursJson: await rootBundle.loadString('assets/data/service_hours.json'),
  );
  final dataset = await DatasetRepository.loadDomainModels(db);
  final resolver = StationResolver(dataset.stations);
  final planner = JourneyPlanner(
    NetworkGraph.build(dataset.routes, dataset.stations),
    resolver,
    dataset.fares,
  );
  return ZuRehbarApp(
    chatController: ChatController(
      backend: null,
      planner: planner,
      clock: () => DateTime(2026, 9, 14, 12, 0),
    ),
    resolver: resolver,
  );
}

/// A few bounded frames. [WidgetTester.pumpAndSettle] never returns here: the
/// Home screen shows an indeterminate progress bar while a query runs, and
/// that keeps scheduling frames forever.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Each test boots its own in-memory database; that is deliberate, not the
  // shared-executor race drift warns about.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('a typed query produces a routed answer card', (tester) async {
    await tester.pumpWidget(await _bootApp(tester));
    await _settle(tester);

    expect(find.text('Ask about any Zu trip'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'uni town to saddar');
    await tester.tap(find.byIcon(Icons.send));
    await _settle(tester);

    expect(find.byType(AnswerCard), findsOneWidget);
    expect(find.textContaining('SR-08'), findsWidgets);
    expect(find.textContaining('Rs.'), findsWidgets);
  });

  testWidgets('the From/To form plans a trip without free-text parsing', (tester) async {
    await tester.pumpWidget(await _bootApp(tester));
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.swap_vert));
    await _settle(tester);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'Hashtnagri');
    await tester.enterText(fields.at(1), 'Karkhano Market');
    await _settle(tester);

    await tester.tap(find.text('Find route'));
    await _settle(tester);

    expect(find.byType(AnswerCard), findsOneWidget);
    expect(find.textContaining('ER-01'), findsWidgets);
  });

  testWidgets('an unknown stop asks instead of inventing a route', (tester) async {
    await tester.pumpWidget(await _bootApp(tester));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), 'Atlantis to Saddar');
    await tester.tap(find.byIcon(Icons.send));
    await _settle(tester);

    expect(find.textContaining('No Zu station matches'), findsOneWidget);
  });
}
