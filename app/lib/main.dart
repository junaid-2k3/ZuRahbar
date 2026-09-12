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
//
// With no key the app still runs: routing and fares are computed on-device
// anyway, and LocalAssistant words the answer. Only the conversational
// phrasing and free-form query parsing get simpler.
const _qwenApiKey = String.fromEnvironment('QWEN_API_KEY');
const _qwenBaseUrl = String.fromEnvironment('QWEN_API_BASE_URL');
const _qwenModel = String.fromEnvironment('QWEN_MODEL');

// Alibaba Model Studio's international endpoint, which takes an `sk-…` key.
// It replaced ModelScope (`ms-…`, api-inference.modelscope.cn) as the default
// because that host is unreachable from Peshawar — 100% packet loss on both
// home wifi and 4G — so it could never answer a rider here. Both are
// OpenAI-compatible; override either with --dart-define.
const _defaultQwenBaseUrl = 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1';
const _defaultQwenModel = 'qwen-plus';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final LoadedDataset dataset;
  try {
    final db = AppDatabase(openConnection());
    await DatasetRepository.seedIfEmpty(
      db,
      stationsJson: await rootBundle.loadString('assets/data/stations.json'),
      routesJson: await rootBundle.loadString('assets/data/routes.json'),
      faresJson: await rootBundle.loadString('assets/data/fares.json'),
      serviceHoursJson: await rootBundle.loadString('assets/data/service_hours.json'),
    );
    dataset = await DatasetRepository.loadDomainModels(db);
  } catch (error, stackTrace) {
    // assets/data/ is gitignored and generated. Say so on screen rather than
    // dying to a blank window.
    debugPrint('ZuRehbar: dataset failed to load: $error\n$stackTrace');
    runApp(const _DatasetMissingApp());
    return;
  }

  final graph = NetworkGraph.build(dataset.routes, dataset.stations);
  final resolver = StationResolver(dataset.stations);
  final planner = JourneyPlanner(graph, resolver, dataset.fares);
  final backend = _qwenApiKey.isEmpty
      ? null
      : QwenDirectClient(
          Dio(BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
          )),
          apiKey: _qwenApiKey,
          baseUrl: _qwenBaseUrl.isNotEmpty ? _qwenBaseUrl : _defaultQwenBaseUrl,
          model: _qwenModel.isNotEmpty ? _qwenModel : _defaultQwenModel,
        );
  final chatController = ChatController(backend: backend, planner: planner);

  runApp(ZuRehbarApp(chatController: chatController, resolver: resolver));
}

/// Shown when the bundled dataset could not be read at startup.
class _DatasetMissingApp extends StatelessWidget {
  const _DatasetMissingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZuRehbar',
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'The Zu dataset could not be loaded.\n\n'
              'Regenerate it and rebuild:\n'
              'python -m zurehbar.pipeline --only export-app',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class ZuRehbarApp extends StatelessWidget {
  final ChatController chatController;
  final StationResolver resolver;

  const ZuRehbarApp({super.key, required this.chatController, required this.resolver});

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
              HomeScreen(controller: chatController, resolver: resolver),
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
