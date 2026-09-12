import 'package:zurehbar_app/models/station.dart';

class StationMatch {
  final String? stationId;
  final List<String> candidateStationIds;

  StationMatch._({this.stationId, this.candidateStationIds = const []});

  factory StationMatch.exact(String stationId) => StationMatch._(stationId: stationId);
  factory StationMatch.ambiguous(List<String> candidateStationIds) =>
      StationMatch._(candidateStationIds: candidateStationIds);
  factory StationMatch.notFound() => StationMatch._();

  bool get isExact => stationId != null;
  bool get isAmbiguous => stationId == null && candidateStationIds.isNotEmpty;
  bool get isNotFound => stationId == null && candidateStationIds.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is StationMatch &&
      other.stationId == stationId &&
      other.candidateStationIds.join(',') == candidateStationIds.join(',');

  @override
  int get hashCode => Object.hash(stationId, candidateStationIds.join(','));
}

/// A query scores at least this well against a station name before it counts
/// as a match at all. Below it the rider gets "no such stop" rather than a
/// confidently wrong guess.
const _matchThreshold = 0.7;

/// If the runner-up scores within this of the winner, the two are too close to
/// pick between and the rider is asked which they meant (FR-2.2).
const _ambiguityMargin = 0.05;

final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// Arabic/Urdu diacritics, tatweel, and the zero-width joiners that ride along
/// in copied text. Mirrors `_URDU_MARKS` in zurehbar/model/naming.py — folding
/// must not strip the letters themselves, or every Urdu alias collapses onto
/// one station.
final _urduMarks = RegExp('[\\u064B-\\u0652\\u0670\\u0640\\u200B-\\u200F]');

/// Aggressive comparison key: case, punctuation and spacing all dropped.
String _fold(String input) =>
    input.toLowerCase().replaceAll(_urduMarks, '').replaceAll(_nonWord, '');

List<String> _tokenize(String input) => input
    .toLowerCase()
    .replaceAll(_urduMarks, '')
    .split(_nonWord)
    .where((token) => token.isNotEmpty)
    .toList();

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      final deletion = previous[j] + 1;
      final insertion = current[j - 1] + 1;
      current[j] = substitution < deletion
          ? (substitution < insertion ? substitution : insertion)
          : (deletion < insertion ? deletion : insertion);
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}

double _max(double a, double b) => a > b ? a : b;

/// 1.0 for identical strings, decaying with edit distance.
double _similarity(String a, String b) {
  if (a == b) return 1.0;
  if (a.isEmpty || b.isEmpty) return 0.0;
  final longest = a.length > b.length ? a.length : b.length;
  final shortest = a.length > b.length ? b.length : a.length;
  // An edit distance is at least the length gap, so a big gap can never score
  // well enough to matter. Skipping those keeps autocomplete responsive.
  if ((longest - shortest) / longest > 0.5) return 0.0;
  return 1 - _levenshtein(a, b) / longest;
}

/// How well every word the rider typed is accounted for by the station's words.
/// A prefix counts as a near-hit, which is what makes "uni town" land on
/// "University Town" (FR-1.3's own example).
double _tokenScore(List<String> query, List<String> candidate) {
  if (query.isEmpty || candidate.isEmpty) return 0.0;
  var matched = 0.0;
  for (final queryToken in query) {
    var best = 0.0;
    for (final candidateToken in candidate) {
      final double score;
      if (candidateToken == queryToken) {
        score = 1.0;
      } else if (candidateToken.startsWith(queryToken)) {
        score = 0.95;
      } else {
        score = _similarity(queryToken, candidateToken);
      }
      if (score > best) best = score;
    }
    matched += best;
  }
  // Matching only some of the station's words is a weaker signal than matching
  // all of them: "university" alone should not beat "university town".
  final coverage = matched / query.length;
  final breadth =
      query.length / (candidate.length > query.length ? candidate.length : query.length);
  return coverage * (0.8 + 0.2 * breadth);
}

class _ScoredStation {
  final Station station;
  final double score;
  _ScoredStation(this.station, this.score);
}

/// Every spelling the dataset knows for one station — canonical name, Roman
/// Urdu aliases, Urdu/Pashto script — folded and tokenized once at startup.
/// Folding on every keystroke instead made autocomplete visibly laggy.
class _IndexedStation {
  final Station station;
  final List<String> foldedNames;
  final List<List<String>> tokenizedNames;

  _IndexedStation(this.station)
      : foldedNames = [
          for (final name in [
            station.name,
            ...station.aliases,
            ...station.urdu,
            ...station.pashto,
          ])
            _fold(name),
        ],
        tokenizedNames = [
          for (final name in [
            station.name,
            ...station.aliases,
            ...station.urdu,
            ...station.pashto,
          ])
            _tokenize(name),
        ];
}

class StationResolver {
  final List<Station> stations;
  final List<_IndexedStation> _index;

  StationResolver(this.stations)
      : _index = [for (final station in stations) _IndexedStation(station)];

  double _scoreStation(_IndexedStation indexed, String folded, List<String> queryTokens) {
    var best = 0.0;
    for (var i = 0; i < indexed.foldedNames.length; i++) {
      final candidate = indexed.foldedNames[i];
      if (candidate == folded) return 1.0;
      final combined = _max(
        _similarity(folded, candidate),
        _tokenScore(queryTokens, indexed.tokenizedNames[i]),
      );
      if (combined > best) best = combined;
    }
    return best;
  }

  List<_ScoredStation> _rank(String query) {
    final folded = _fold(query);
    if (folded.isEmpty) return const [];
    final queryTokens = _tokenize(query);
    final scored = [
      for (final indexed in _index)
        _ScoredStation(indexed.station, _scoreStation(indexed, folded, queryTokens)),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  StationMatch resolve(String query) {
    final ranked = _rank(query);
    if (ranked.isEmpty || ranked.first.score < _matchThreshold) {
      return StationMatch.notFound();
    }

    final best = ranked.first;
    if (best.score >= 1.0) return StationMatch.exact(best.station.stationId);

    final contenders = ranked
        .where((candidate) => candidate.score >= best.score - _ambiguityMargin)
        .toList();
    if (contenders.length == 1) return StationMatch.exact(best.station.stationId);
    return StationMatch.ambiguous(
      contenders.take(5).map((candidate) => candidate.station.stationId).toList(),
    );
  }

  /// Autocomplete feed (UI-4.2.3): the closest station names to what the rider
  /// has typed so far, best first.
  List<Station> suggest(String query, {int limit = 6}) {
    if (query.trim().isEmpty) return const [];
    return _rank(query)
        .where((candidate) => candidate.score >= 0.5)
        .take(limit)
        .map((candidate) => candidate.station)
        .toList();
  }
}
