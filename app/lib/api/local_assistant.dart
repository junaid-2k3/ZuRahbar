import 'package:zurehbar_app/api/backend_client.dart';
import 'package:zurehbar_app/routing/journey_planner.dart';

/// A deterministic stand-in for the two Qwen calls, running entirely on-device.
///
/// Routing and fares are already computed locally, so the only thing a dead
/// network costs the rider is the natural wording around them. NFR-1 asks for
/// graceful degradation rather than a dead app, so [ChatController] falls back
/// to this whenever Qwen is unreachable — and uses it outright when the build
/// carries no API key.
class LocalAssistant implements BackendClient {
  const LocalAssistant();

  @override
  Future<ExtractedQuery> extractQuery(String text) async => extract(text);

  @override
  Future<String> phraseAnswer(Map<String, dynamic> planJson) async =>
      throw UnsupportedError('Use phrase(plan) — the local phrasing needs the typed plan.');

  // --- Extraction -----------------------------------------------------------

  /// Filler that precedes the origin in the way riders actually type.
  /// Longest first, so "how do i get from" wins over "from".
  static final _leadIns = [
    'what is the fare from',
    'how much is the fare from',
    'how do i get from',
    'how do i go from',
    'how to get from',
    'how to go from',
    'i want to go from',
    'i need to go from',
    'take me from',
    'route from',
    'fare from',
    'bus from',
    'travel from',
    'go from',
    'from',
  ];

  /// The word riders put between origin and destination: English "to",
  /// Roman Urdu "se"/"say" (as in "Saddar se Chamkani"), Urdu "سے", and the
  /// arrows people type.
  static final separator = RegExp(
    r'\s(?:to|se|say|tak|towards|→|->|سے|تک)\s',
    caseSensitive: false,
  );

  static final _fareWords = RegExp(r'fare|kiraya|kirya|price|cost|کرایہ', caseSensitive: false);

  /// True when the rider said "there"/"wahan" — a follow-up hanging off the
  /// previous answer's destination rather than its origin (FR-7.1).
  static final anaphora = RegExp(r'\bthere\b|\bwahan\b|وہاں', caseSensitive: false);

  static final _bareAnaphor =
      RegExp(r'^(?:there|wahan|وہاں)$', caseSensitive: false);

  /// "there" is a pointer at the previous answer, not a stop name. Whichever
  /// extractor produced it, the caller has to fill it in from session context.
  static bool isAnaphoric(String? side) =>
      side != null && _bareAnaphor.hasMatch(side.trim());

  /// Rule-based version of the extractQuery prompt. Deliberately conservative:
  /// it returns null rather than guess, and the caller then asks the rider.
  static ExtractedQuery extract(String rawText) {
    var text = rawText.trim();
    final intent = _fareWords.hasMatch(text) ? 'fare' : 'route';

    var lowered = text.toLowerCase();
    for (final leadIn in _leadIns) {
      if (lowered.startsWith('$leadIn ')) {
        text = text.substring(leadIn.length).trim();
        lowered = text.toLowerCase();
        break;
      }
    }

    final match = separator.firstMatch(text);
    if (match == null) {
      // No separator: treat the whole thing as a destination ("get me to Saddar")
      // and let the caller supply the origin from session context.
      return ExtractedQuery(
        origin: null,
        destination: _cleanSide(text),
        intent: intent,
      );
    }

    return ExtractedQuery(
      origin: _cleanSide(text.substring(0, match.start)),
      destination: _cleanSide(text.substring(match.end)),
      intent: intent,
    );
  }

  static final _trailingNoise =
      RegExp(r'[\s,.?!]*(?:\btak\b|\bplease\b|\bkitna\b|\bhai\b|\bhoga\b)?[\s,.?!]*$',
          caseSensitive: false);
  static final _leadingNoise =
      RegExp(r'^[\s,.?!]*(?:\bthe\b|\bto\b|\bat\b|\bgo\b|\bget\b)?[\s,.?!]*', caseSensitive: false);

  static String? _cleanSide(String side) {
    final cleaned =
        side.replaceFirst(_leadingNoise, '').replaceFirst(_trailingNoise, '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  // --- Phrasing -------------------------------------------------------------

  /// Rule-based version of the phraseAnswer prompt, over the typed plan.
  static String phrase(JourneyPlan plan) {
    if (!plan.found) {
      final parts = <String>[
        plan.message.isNotEmpty ? plan.message : 'I could not plan that trip.',
        ...plan.warnings,
      ];
      return parts.join(' ');
    }

    final sentences = <String>[];
    for (var i = 0; i < plan.legs.length; i++) {
      final leg = plan.legs[i];
      final verb = i == 0 ? 'Take' : 'then take';
      final stops = leg.stopCount == 1 ? '1 stop' : '${leg.stopCount} stops';
      sentences.add('$verb ${leg.routeId} from ${leg.boardStation} to '
          '${leg.alightStation} ($stops, about ${_minutes(leg.rideTimeMin)})');
    }
    var reply = '${sentences.join(', ')}.';

    if (plan.legs.length > 1) {
      final transfers = plan.legs.skip(1).map((leg) => leg.boardStation).join(' and ');
      reply += ' Change at $transfers.';
    }

    reply += ' Total about ${_minutes(plan.totalTimeMin)} including waiting';
    if (plan.fare != null) {
      reply += ', and the fare is about Rs. ${plan.fare!.totalPkr}';
    }
    reply += '.';

    final frequency = _frequency(plan.legs.first);
    if (frequency != null) reply += ' ${plan.legs.first.routeId} runs $frequency.';

    if (plan.serviceAvailable == false) {
      reply += ' Note that this is outside the published service hours right now.';
      // Say when to come back, not just that it is shut (FR-9.3).
      final windows = [
        for (final leg in plan.legs)
          if (leg.firstBus != null && leg.lastBus != null)
            '${leg.routeId} runs ${leg.firstBus}–${leg.lastBus}',
      ];
      if (windows.isNotEmpty) reply += ' ${windows.join('; ')}.';
    }
    for (final warning in plan.warnings) {
      reply += ' $warning';
    }
    if (plan.fare != null && plan.fare!.isEstimate) {
      reply += ' ${plan.fare!.note}';
    }
    return reply;
  }

  static String _minutes(double value) => '${value.round()} min';

  static String? _frequency(Leg leg) {
    final low = leg.headwayMinLow;
    if (low == null) return null;
    final high = leg.headwayMinHigh;
    if (high == null || high == low) return 'about every $low minutes';
    return 'about every $low–$high minutes';
  }
}
