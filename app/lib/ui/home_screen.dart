import 'package:flutter/material.dart';
import 'package:zurehbar_app/api/local_assistant.dart';
import 'package:zurehbar_app/models/station.dart';
import 'package:zurehbar_app/routing/station_resolver.dart';
import 'package:zurehbar_app/ui/answer_card.dart';
import 'package:zurehbar_app/ui/chat_controller.dart';

const _examples = [
  'University Town to Saddar',
  'How do I get from Hashtnagri to Karkhano Market?',
  'Fare from Board Bazar to Chamkani',
];

class HomeScreen extends StatefulWidget {
  final ChatController controller;
  final StationResolver resolver;

  const HomeScreen({super.key, required this.controller, required this.resolver});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _askController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _scrollController = ScrollController();

  /// UI-4.2.1 vs UI-4.2.2: one free-text box by default, with an explicit
  /// From/To form a tap away for riders who prefer structured entry.
  bool _structuredEntry = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _askController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _askController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    // Keep the newest answer in view (UI-5.6.1).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _submitAsk([String? text]) {
    final query = (text ?? _askController.text).trim();
    if (query.isEmpty) return;
    _askController.clear();
    widget.controller.submit(query);
  }

  void _submitTrip() {
    final from = _fromController.text.trim();
    final to = _toController.text.trim();
    if (from.isEmpty || to.isEmpty) return;
    widget.controller.submitTrip(from, to);
  }

  /// The stop name the rider is part-way through typing: whatever follows the
  /// last "to"/"se"/"→" in the box, or the whole box if there is no separator.
  String _trailingFragment(String text) {
    final matches = LocalAssistant.separator.allMatches(text).toList();
    return matches.isEmpty ? text : text.substring(matches.last.end);
  }

  void _completeFragment(Station station) {
    final text = _askController.text;
    final matches = LocalAssistant.separator.allMatches(text).toList();
    final prefix = matches.isEmpty ? '' : text.substring(0, matches.last.end);
    _askController.text = '$prefix${station.name}';
    _askController.selection =
        TextSelection.collapsed(offset: _askController.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.controller.messages;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZuRehbar'),
        actions: [
          IconButton(
            tooltip: _structuredEntry ? 'Ask in your own words' : 'Enter From / To',
            icon: Icon(_structuredEntry ? Icons.chat_bubble_outline : Icons.swap_vert),
            onPressed: () => setState(() => _structuredEntry = !_structuredEntry),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _emptyState(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      if (message.isUser) return _userBubble(context, message.text);
                      return AnswerCard(
                        replyText: message.text,
                        plan: message.plan,
                        isOffline: message.isOffline,
                      );
                    },
                  ),
          ),
          if (widget.controller.isLoading) const LinearProgressIndicator(),
          SafeArea(
            top: false,
            // The From/To form grows as suggestion chips appear; on a short
            // screen (or with the keyboard up) let it scroll rather than
            // overflow.
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: SingleChildScrollView(
                child: _structuredEntry ? _fromToForm() : _askBox(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    // Scrollable so it survives a short viewport — the From/To form and the
    // on-screen keyboard both eat into the height available here.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_bus, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Ask about any Zu trip', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final example in _examples)
                  ActionChip(label: Text(example), onPressed: () => _submitAsk(example)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _userBubble(BuildContext context, String text) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(text),
        ),
      );

  Widget _askBox() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _suggestionChips(_trailingFragment(_askController.text), _completeFragment),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _askController,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: 'Where to? e.g. "University Town to Saddar"',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submitAsk(),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: () => _submitAsk()),
            ],
          ),
        ),
      ],
    );
  }

  /// Quick-tap stop completions for whatever the rider is typing (UI-4.2.3).
  Widget _suggestionChips(String fragment, void Function(Station) onPick) {
    final suggestions = widget.resolver.suggest(fragment, limit: 4);
    // Nothing to offer once the field already holds the exact stop name.
    if (suggestions.isEmpty ||
        (suggestions.length == 1 &&
            suggestions.first.name.toLowerCase() == fragment.trim().toLowerCase())) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final station in suggestions)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                label: Text(station.name),
                onPressed: () => onPick(station),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fromToForm() => Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stopField(_fromController, 'From', Icons.trip_origin),
            const SizedBox(height: 8),
            _stopField(_toController, 'To', Icons.place_outlined),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitTrip,
                icon: const Icon(Icons.search),
                label: const Text('Find route'),
              ),
            ),
          ],
        ),
      );

  Widget _stopField(TextEditingController controller, String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        _suggestionChips(controller.text, (station) {
          controller.text = station.name;
          setState(() {});
        }),
      ],
    );
  }
}
