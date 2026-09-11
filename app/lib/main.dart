import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zurehbar_app/api/qwen_direct_client.dart';
import 'package:zurehbar_app/data/database.dart';
import 'package:zurehbar_app/data/dataset_repository.dart';
import 'package:zurehbar_app/routing/network_graph.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';
import 'package:zurehbar_app/routing/station_resolver.dart';
import 'package:zurehbar_app/ui/chat_controller.dart';
import 'package:zurehbar_app/ui/home_screen.dart';

// Interim Phase 1 wiring: the app calls Qwen directly instead of through the
// backend/ Firebase Functions proxy, because Cloud Functions v2 needs a
// Blaze billing account just to reach any external API and that wasn't
// available. Never hardcode the key here — pass it at build/run time:
//   flutter run --dart-define=QWEN_API_KEY=...
// backend/ is untouched and dormant; swap back to DioBackendClient (see
// api/backend_client.dart) once a backend host is available again.
const _qwenApiKey = String.fromEnvironment('QWEN_API_KEY');
const _qwenBaseUrl = String.fromEnvironment('QWEN_API_BASE_URL');
const _qwenModel = String.fromEnvironment('QWEN_MODEL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_qwenApiKey.isEmpty) {
    throw StateError(
      'QWEN_API_KEY was not provided. Run with '
      '--dart-define=QWEN_API_KEY=<your key>.',
    );
  }

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
  final backend = QwenDirectClient(
    Dio(),
    apiKey: _qwenApiKey,
    baseUrl: _qwenBaseUrl.isNotEmpty ? _qwenBaseUrl : 'https://api-inference.modelscope.cn/v1',
    model: _qwenModel.isNotEmpty ? _qwenModel : 'Qwen/Qwen2.5-72B-Instruct',
  );
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
