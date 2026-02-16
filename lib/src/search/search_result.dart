/// Search result definitions.
library;

import '../index/index_entry.dart';

/// A search result.
class SearchResult {
  /// Result entry.
  final IndexEntry entry;

  /// Relevance score.
  final double score;

  /// Rank position.
  final int rank;

  /// Highlighted content (if available).
  final String? highlightedContent;

  /// Match info.
  final MatchInfo? matchInfo;

  const SearchResult({
    required this.entry,
    required this.score,
    this.rank = 0,
    this.highlightedContent,
    this.matchInfo,
  });

  /// Create from JSON.
  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      entry: IndexEntry.fromJson(json['entry'] as Map<String, dynamic>),
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      rank: json['rank'] as int? ?? 0,
      highlightedContent: json['highlightedContent'] as String?,
      matchInfo: json['matchInfo'] != null
          ? MatchInfo.fromJson(json['matchInfo'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'entry': entry.toJson(),
        'score': score,
        'rank': rank,
        if (highlightedContent != null) 'highlightedContent': highlightedContent,
        if (matchInfo != null) 'matchInfo': matchInfo!.toJson(),
      };

  /// Get document ID.
  String get documentId => entry.documentId;

  /// Get content.
  String get content => entry.content;

  @override
  String toString() => 'SearchResult(doc=${entry.documentId}, score=$score)';
}

/// Match information for a search result.
class MatchInfo {
  /// Matched terms.
  final List<String> matchedTerms;

  /// Match positions.
  final List<MatchPosition> positions;

  /// Keyword score component.
  final double? keywordScore;

  /// Semantic score component.
  final double? semanticScore;

  const MatchInfo({
    this.matchedTerms = const [],
    this.positions = const [],
    this.keywordScore,
    this.semanticScore,
  });

  factory MatchInfo.fromJson(Map<String, dynamic> json) {
    return MatchInfo(
      matchedTerms: (json['matchedTerms'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      positions: (json['positions'] as List<dynamic>?)
              ?.map((e) => MatchPosition.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      keywordScore: (json['keywordScore'] as num?)?.toDouble(),
      semanticScore: (json['semanticScore'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (matchedTerms.isNotEmpty) 'matchedTerms': matchedTerms,
        if (positions.isNotEmpty)
          'positions': positions.map((p) => p.toJson()).toList(),
        if (keywordScore != null) 'keywordScore': keywordScore,
        if (semanticScore != null) 'semanticScore': semanticScore,
      };
}

/// Position of a match.
class MatchPosition {
  /// Start position.
  final int start;

  /// End position.
  final int end;

  /// Matched term.
  final String term;

  const MatchPosition({
    required this.start,
    required this.end,
    required this.term,
  });

  factory MatchPosition.fromJson(Map<String, dynamic> json) {
    return MatchPosition(
      start: json['start'] as int? ?? 0,
      end: json['end'] as int? ?? 0,
      term: json['term'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'term': term,
      };

  /// Get match length.
  int get length => end - start;
}

/// Collection of search results.
class SearchResults {
  /// Query that produced these results.
  final String query;

  /// Result entries.
  final List<SearchResult> results;

  /// Total matches (may be more than returned).
  final int totalMatches;

  /// Search duration.
  final Duration? duration;

  /// Search metadata.
  final Map<String, dynamic> metadata;

  const SearchResults({
    required this.query,
    required this.results,
    this.totalMatches = 0,
    this.duration,
    this.metadata = const {},
  });

  /// Create from JSON.
  factory SearchResults.fromJson(Map<String, dynamic> json) {
    return SearchResults(
      query: json['query'] as String? ?? '',
      results: (json['results'] as List<dynamic>?)
              ?.map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalMatches: json['totalMatches'] as int? ?? 0,
      duration: json['durationMs'] != null
          ? Duration(milliseconds: json['durationMs'] as int)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'query': query,
        'results': results.map((r) => r.toJson()).toList(),
        'totalMatches': totalMatches,
        if (duration != null) 'durationMs': duration!.inMilliseconds,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  /// Check if there are results.
  bool get hasResults => results.isNotEmpty;

  /// Get result count.
  int get count => results.length;

  /// Get the top result.
  SearchResult? get top => results.isNotEmpty ? results.first : null;

  /// Get results above a score threshold.
  List<SearchResult> aboveScore(double threshold) {
    return results.where((r) => r.score >= threshold).toList();
  }

  /// Get results for a specific document.
  List<SearchResult> forDocument(String documentId) {
    return results.where((r) => r.documentId == documentId).toList();
  }

  @override
  String toString() => 'SearchResults($query: ${results.length} results)';
}
