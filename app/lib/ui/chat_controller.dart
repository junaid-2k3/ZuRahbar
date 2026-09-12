import 'package:flutter/foundation.dart';
import 'package:zurehbar_app/api/backend_client.dart';
import 'package:zurehbar_app/api/local_assistant.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';

class ChatMessage {
  final bool isUser;
  final String text;
  final JourneyPlan? plan;

  /// True when the answer was worded on-device because Qwen was unreachable
  /// (or no API key was built in). The routing and fare numbers are identical
  /// either way — only the wording is.
  final bool isOffline;

  ChatMessage({
    required this.isUser,
    required this.text,
    this.plan,
    this.isOffline = false,
  });
}

const _weekdayNames = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

class ChatController extends ChangeNotifier {
  /// Qwen, when the build has an API key. Null means this build talks to
  /// nobody and answers entirely on-device.
  final BackendClient? backend;
  final JourneyPlanner planner;

  /// Overridable so tests get a fixed clock instead of the wall clock.
  final DateTime Function() now;

  final List<ChatMessage> messages = [];
  bool isLoading = false;

  // Session context for follow-up queries (FR-7.1/FR-7.2).
  String? _sessionOrigin;
  String? _sessionDestination;

  ChatController({
    required this.backend,
    required this.planner,
    DateTime Function()? clock,
  }) : now = clock ?? DateTime.now;

  /// A free-text query: Qwen (or the local rules) pulls the two endpoints out
  /// of it first.
  Future<void> submit(String rawText) async {
    messages.add(ChatMessage(isUser: true, text: rawText));
    isLoading = true;
    notifyListeners();
    try {
      var degraded = backend == null;
      ExtractedQuery extracted;
      if (backend == null) {
        extracted = LocalAssistant.extract(rawText);
      } else {
        try {
          extracted = await backend!.extractQuery(rawText);
        } catch (_) {
          degraded = true;
          extracted = LocalAssistant.extract(rawText);
        }
      }

      final extractedOrigin = extracted.origin;
      final origin = extractedOrigin == null || LocalAssistant.isAnaphoric(extractedOrigin)
          ? _rememberedOrigin(rawText)
          : extractedOrigin;
      final destination = extracted.destination;

      if (origin == null || destination == null) {
        messages.add(ChatMessage(
          isUser: false,
          text: origin == null && destination == null
              ? 'Where are you starting from, and where are you headed?'
              : origin == null
                  ? 'Which stop are you starting from?'
                  : 'Where would you like to go?',
          isOffline: degraded,
        ));
        return;
      }

      await _answer(origin, destination, degraded: degraded);
    } catch (error, stackTrace) {
      debugPrint('ZuRehbar: query failed: $error\n$stackTrace');
      messages.add(ChatMessage(
        isUser: false,
        text: 'Something went wrong working that trip out. Please try again.',
      ));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// The structured From/To form (UI-4.2.2): both endpoints are already known,
  /// so there is nothing for Qwen to extract.
  Future<void> submitTrip(String origin, String destination) async {
    messages.add(ChatMessage(isUser: true, text: '$origin → $destination'));
    isLoading = true;
    notifyListeners();
    try {
      await _answer(origin, destination, degraded: backend == null);
    } catch (error, stackTrace) {
      debugPrint('ZuRehbar: trip failed: $error\n$stackTrace');
      messages.add(ChatMessage(
        isUser: false,
        text: 'Something went wrong working that trip out. Please try again.',
      ));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// A follow-up that names no origin reuses the session's. "…to Hayatabad
  /// from there" hangs off the last *destination*; anything else falls back to
  /// the last origin (FR-7.2).
  String? _rememberedOrigin(String rawText) =>
      LocalAssistant.anaphora.hasMatch(rawText)
          ? _sessionDestination ?? _sessionOrigin
          : _sessionOrigin;

  Future<void> _answer(String origin, String destination, {required bool degraded}) async {
    final at = now();
    final plan = planner.plan(
      origin,
      destination,
      timeOfDay: '${at.hour.toString().padLeft(2, '0')}:'
          '${at.minute.toString().padLeft(2, '0')}',
      dayOfWeek: _weekdayNames[at.weekday - 1],
    );

    var offline = degraded;
    String reply;
    if (offline) {
      reply = LocalAssistant.phrase(plan);
    } else {
      try {
        reply = await backend!.phraseAnswer(plan.toJson());
      } catch (_) {
        offline = true;
        reply = LocalAssistant.phrase(plan);
      }
    }

    if (plan.found) {
      _sessionOrigin = plan.origin;
      _sessionDestination = plan.destination;
    }
    messages.add(ChatMessage(isUser: false, text: reply, plan: plan, isOffline: offline));
  }
}
