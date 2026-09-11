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
