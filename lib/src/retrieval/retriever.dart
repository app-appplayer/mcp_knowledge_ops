/// Knowledge retriever for fetching relevant content.
library;

import '../index/knowledge_index.dart';
import '../index/index_entry.dart';
import '../search/search_query.dart';
import '../search/search_result.dart';

/// Abstract retriever interface.
abstract class Retriever {
  /// Retrieve relevant content for a query.
  Future<SearchResults> retrieve(SearchQuery query);

  /// Retrieve top-k results.
  Future<List<SearchResult>> retrieveTopK(String query, {int k = 5});
}

/// Knowledge retriever implementation.
class KnowledgeRetriever implements Retriever {
  final MemoryKnowledgeIndex index;
  final InvertedIndex? textIndex;
  final RetrieverOptions options;

  KnowledgeRetriever({
    required this.index,
    this.textIndex,
    this.options = const RetrieverOptions(),
  });

  @override
  Future<SearchResults> retrieve(SearchQuery query) async {
    final startTime = DateTime.now();

    List<SearchResult> results;

    switch (query.mode) {
      case SearchMode.keyword:
        results = await _keywordSearch(query);
      case SearchMode.semantic:
        results = await _semanticSearch(query);
      case SearchMode.hybrid:
        results = await _hybridSearch(query);
      case SearchMode.exact:
        results = await _exactSearch(query);
    }

    // Apply filters
    results = _applyFilters(results, query);

    // Apply score threshold
    results = results.where((r) => r.score >= query.minScore).toList();

    // Limit results
    if (results.length > query.limit) {
      results = results.sublist(0, query.limit);
    }

    // Assign ranks
    results = results.asMap().entries.map((e) {
      return SearchResult(
        entry: e.value.entry,
        score: e.value.score,
        rank: e.key + 1,
        highlightedContent: e.value.highlightedContent,
        matchInfo: e.value.matchInfo,
      );
    }).toList();

    final duration = DateTime.now().difference(startTime);

    return SearchResults(
      query: query.text,
      results: results,
      totalMatches: results.length,
      duration: duration,
    );
  }

  @override
  Future<List<SearchResult>> retrieveTopK(String query, {int k = 5}) async {
    final searchQuery = SearchQuery(
      text: query,
      mode: options.defaultMode,
      limit: k,
    );
    final results = await retrieve(searchQuery);
    return results.results;
  }

  Future<List<SearchResult>> _keywordSearch(SearchQuery query) async {
    if (textIndex == null) {
      // Fall back to simple content matching
      return _simpleTextSearch(query);
    }

    final scores = textIndex!.search(query.text);
    final results = <SearchResult>[];

    for (final entry in scores.entries) {
      // Get all index entries for this document
      final docEntries = await index.getByDocument(entry.key);
      for (final docEntry in docEntries) {
        results.add(SearchResult(
          entry: docEntry,
          score: entry.value,
          matchInfo: MatchInfo(
            keywordScore: entry.value,
            matchedTerms: _extractMatchedTerms(query.text, docEntry.content),
          ),
        ));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  Future<List<SearchResult>> _simpleTextSearch(SearchQuery query) async {
    final queryTerms = query.text.toLowerCase().split(RegExp(r'\s+'));
    final results = <SearchResult>[];

    for (final entry in index.allEntries) {
      final contentLower = entry.content.toLowerCase();
      var score = 0.0;
      final matchedTerms = <String>[];

      for (final term in queryTerms) {
        if (contentLower.contains(term)) {
          score += 1.0;
          matchedTerms.add(term);
        }
      }

      if (score > 0) {
        results.add(SearchResult(
          entry: entry,
          score: score / queryTerms.length,
          matchInfo: MatchInfo(
            keywordScore: score,
            matchedTerms: matchedTerms,
          ),
        ));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  Future<List<SearchResult>> _semanticSearch(SearchQuery query) async {
    final queryEmbedding = query.embedding;
    if (queryEmbedding == null || queryEmbedding.isEmpty) {
      return [];
    }

    final results = <SearchResult>[];

    for (final entry in index.allEntries) {
      if (!entry.hasEmbedding) continue;

      final similarity = _cosineSimilarity(queryEmbedding, entry.embedding!);
      results.add(SearchResult(
        entry: entry,
        score: similarity,
        matchInfo: MatchInfo(semanticScore: similarity),
      ));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  Future<List<SearchResult>> _hybridSearch(SearchQuery query) async {
    final keywordResults = await _keywordSearch(query);
    final semanticResults = await _semanticSearch(query);

    // Merge results using reciprocal rank fusion
    final scores = <String, double>{};
    final entries = <String, IndexEntry>{};
    final matchInfos = <String, MatchInfo>{};

    const k = 60; // RRF constant

    for (var i = 0; i < keywordResults.length; i++) {
      final result = keywordResults[i];
      final rrfScore = query.keywordWeight / (k + i + 1);
      scores.update(
        result.entry.id,
        (s) => s + rrfScore,
        ifAbsent: () => rrfScore,
      );
      entries[result.entry.id] = result.entry;
      matchInfos[result.entry.id] = MatchInfo(
        keywordScore: result.matchInfo?.keywordScore,
        matchedTerms: result.matchInfo?.matchedTerms ?? [],
      );
    }

    for (var i = 0; i < semanticResults.length; i++) {
      final result = semanticResults[i];
      final rrfScore = query.semanticWeight / (k + i + 1);
      scores.update(
        result.entry.id,
        (s) => s + rrfScore,
        ifAbsent: () => rrfScore,
      );
      entries[result.entry.id] = result.entry;

      final existing = matchInfos[result.entry.id];
      matchInfos[result.entry.id] = MatchInfo(
        keywordScore: existing?.keywordScore,
        semanticScore: result.matchInfo?.semanticScore,
        matchedTerms: existing?.matchedTerms ?? [],
      );
    }

    final results = scores.entries.map((e) {
      return SearchResult(
        entry: entries[e.key]!,
        score: e.value,
        matchInfo: matchInfos[e.key],
      );
    }).toList();

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  Future<List<SearchResult>> _exactSearch(SearchQuery query) async {
    final results = <SearchResult>[];

    for (final entry in index.allEntries) {
      if (entry.content.contains(query.text)) {
        results.add(SearchResult(
          entry: entry,
          score: 1.0,
          matchInfo: MatchInfo(matchedTerms: [query.text]),
        ));
      }
    }

    return results;
  }

  List<SearchResult> _applyFilters(
    List<SearchResult> results,
    SearchQuery query,
  ) {
    var filtered = results;

    // Filter by document IDs
    if (query.documentIds != null && query.documentIds!.isNotEmpty) {
      filtered = filtered
          .where((r) => query.documentIds!.contains(r.documentId))
          .toList();
    }

    // Filter by tags
    if (query.tags != null && query.tags!.isNotEmpty) {
      filtered = filtered.where((r) {
        final entryTags = r.entry.metadata['tags'];
        if (entryTags is List) {
          return query.tags!.any((t) => entryTags.contains(t));
        }
        return false;
      }).toList();
    }

    // Filter by metadata
    if (query.metadataFilter != null && query.metadataFilter!.isNotEmpty) {
      filtered = filtered.where((r) {
        for (final entry in query.metadataFilter!.entries) {
          final value = r.entry.metadata[entry.key];
          if (value != entry.value) return false;
        }
        return true;
      }).toList();
    }

    return filtered;
  }

  List<String> _extractMatchedTerms(String query, String content) {
    final queryTerms = query.toLowerCase().split(RegExp(r'\s+'));
    final contentLower = content.toLowerCase();
    return queryTerms.where((t) => contentLower.contains(t)).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0;

    var dotProduct = 0.0;
    var normA = 0.0;
    var normB = 0.0;

    for (var i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0;
    return dotProduct / (_sqrt(normA) * _sqrt(normB));
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    var guess = x / 2;
    for (var i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}

/// Options for the retriever.
class RetrieverOptions {
  /// Default search mode.
  final SearchMode defaultMode;

  /// Whether to rerank results.
  final bool rerank;

  /// Maximum context length.
  final int maxContextLength;

  const RetrieverOptions({
    this.defaultMode = SearchMode.keyword,
    this.rerank = false,
    this.maxContextLength = 4000,
  });
}
