/// Context builder for constructing retrieval context.
library;

import '../search/search_result.dart';

/// Builds context from search results.
class ContextBuilder {
  final ContextBuilderOptions options;

  const ContextBuilder({this.options = const ContextBuilderOptions()});

  /// Build context from search results.
  String build(SearchResults results) {
    if (!results.hasResults) return '';

    final buffer = StringBuffer();
    var totalLength = 0;
    var addedCount = 0;

    for (final result in results.results) {
      if (addedCount >= options.maxChunks) break;

      final content = _formatChunk(result, addedCount + 1);
      if (totalLength + content.length > options.maxLength) {
        // Try to add truncated content
        final remaining = options.maxLength - totalLength;
        if (remaining > options.minChunkLength) {
          buffer.write(content.substring(0, remaining));
          buffer.write('...');
        }
        break;
      }

      if (buffer.isNotEmpty) {
        buffer.write(options.chunkSeparator);
      }
      buffer.write(content);
      totalLength += content.length;
      addedCount++;
    }

    return buffer.toString();
  }

  /// Build context with metadata.
  ContextResult buildWithMetadata(SearchResults results) {
    final context = build(results);
    final sources = results.results
        .take(options.maxChunks)
        .map((r) => ContextSource(
              documentId: r.documentId,
              chunkId: r.entry.chunkId,
              score: r.score,
              title: r.entry.metadata['title'] as String?,
            ))
        .toList();

    return ContextResult(
      context: context,
      sources: sources,
      totalResults: results.totalMatches,
      includedResults: sources.length,
    );
  }

  /// Build context as a list of chunks.
  List<ContextChunk> buildChunks(SearchResults results) {
    final chunks = <ContextChunk>[];
    var addedLength = 0;

    for (final result in results.results) {
      if (chunks.length >= options.maxChunks) break;
      if (addedLength >= options.maxLength) break;

      var content = result.content;
      if (addedLength + content.length > options.maxLength) {
        content = content.substring(0, options.maxLength - addedLength);
      }

      chunks.add(ContextChunk(
        content: content,
        documentId: result.documentId,
        chunkId: result.entry.chunkId,
        score: result.score,
        metadata: result.entry.metadata,
      ));

      addedLength += content.length;
    }

    return chunks;
  }

  String _formatChunk(SearchResult result, int index) {
    final buffer = StringBuffer();

    if (options.includeMetadata) {
      final title = result.entry.metadata['title'] as String?;
      if (title != null) {
        buffer.writeln('[$index] Source: $title');
      }
      if (options.includeScore) {
        buffer.writeln('Relevance: ${(result.score * 100).toStringAsFixed(1)}%');
      }
      buffer.writeln();
    }

    buffer.write(result.content);

    return buffer.toString();
  }
}

/// Options for context building.
class ContextBuilderOptions {
  /// Maximum context length.
  final int maxLength;

  /// Maximum number of chunks.
  final int maxChunks;

  /// Minimum chunk length to include.
  final int minChunkLength;

  /// Separator between chunks.
  final String chunkSeparator;

  /// Whether to include metadata.
  final bool includeMetadata;

  /// Whether to include relevance scores.
  final bool includeScore;

  /// Whether to deduplicate similar content.
  final bool deduplicate;

  const ContextBuilderOptions({
    this.maxLength = 4000,
    this.maxChunks = 5,
    this.minChunkLength = 50,
    this.chunkSeparator = '\n\n---\n\n',
    this.includeMetadata = true,
    this.includeScore = false,
    this.deduplicate = true,
  });

  ContextBuilderOptions copyWith({
    int? maxLength,
    int? maxChunks,
    int? minChunkLength,
    String? chunkSeparator,
    bool? includeMetadata,
    bool? includeScore,
    bool? deduplicate,
  }) {
    return ContextBuilderOptions(
      maxLength: maxLength ?? this.maxLength,
      maxChunks: maxChunks ?? this.maxChunks,
      minChunkLength: minChunkLength ?? this.minChunkLength,
      chunkSeparator: chunkSeparator ?? this.chunkSeparator,
      includeMetadata: includeMetadata ?? this.includeMetadata,
      includeScore: includeScore ?? this.includeScore,
      deduplicate: deduplicate ?? this.deduplicate,
    );
  }
}

/// Result of context building.
class ContextResult {
  /// Built context string.
  final String context;

  /// Source references.
  final List<ContextSource> sources;

  /// Total number of results found.
  final int totalResults;

  /// Number of results included in context.
  final int includedResults;

  const ContextResult({
    required this.context,
    required this.sources,
    this.totalResults = 0,
    this.includedResults = 0,
  });

  /// Check if context is empty.
  bool get isEmpty => context.isEmpty;

  /// Check if context has sources.
  bool get hasSources => sources.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'context': context,
        'sources': sources.map((s) => s.toJson()).toList(),
        'totalResults': totalResults,
        'includedResults': includedResults,
      };
}

/// A source reference in the context.
class ContextSource {
  /// Document ID.
  final String documentId;

  /// Chunk ID.
  final String? chunkId;

  /// Relevance score.
  final double score;

  /// Document title.
  final String? title;

  const ContextSource({
    required this.documentId,
    this.chunkId,
    this.score = 0,
    this.title,
  });

  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        if (chunkId != null) 'chunkId': chunkId,
        'score': score,
        if (title != null) 'title': title,
      };
}

/// A chunk of context.
class ContextChunk {
  /// Chunk content.
  final String content;

  /// Document ID.
  final String documentId;

  /// Chunk ID.
  final String? chunkId;

  /// Relevance score.
  final double score;

  /// Chunk metadata.
  final Map<String, dynamic> metadata;

  const ContextChunk({
    required this.content,
    required this.documentId,
    this.chunkId,
    this.score = 0,
    this.metadata = const {},
  });

  int get length => content.length;

  Map<String, dynamic> toJson() => {
        'content': content,
        'documentId': documentId,
        if (chunkId != null) 'chunkId': chunkId,
        'score': score,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}
