import 'package:flutter/foundation.dart';
import 'package:zurehbar_app/api/backend_client.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';

class ChatMessage {
  final bool isUser;
  final String text;
  final JourneyPlan? plan;

  ChatMessage({required this.isUser, required this.text, this.plan});
}

class ChatController extends ChangeNotifier {
  final BackendClient backend;
  final JourneyPlanner planner;
  final List<ChatMessage> messages = [];
  bool isLoading = false;

  ChatController({required this.backend, required this.planner});

  Future<void> submit(String rawText) async {
    messages.add(ChatMessage(isUser: true, text: rawText));
    isLoading = true;
    notifyListeners();

    try {
      final extracted = await backend.extractQuery(rawText);
      if (extracted.origin == null || extracted.destination == null) {
        messages.add(ChatMessage(
          isUser: false,
          text: 'Where are you starting from, and where are you headed?',
        ));
        return;
      }

      final plan = planner.plan(extracted.origin!, extracted.destination!);
      final reply = await backend.phraseAnswer(plan.toJson());
      messages.add(ChatMessage(isUser: false, text: reply, plan: plan));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
