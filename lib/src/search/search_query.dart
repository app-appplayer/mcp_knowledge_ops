/// Search query definitions.
library;

/// Search modes.
enum SearchMode {
  /// Keyword-based search.
  keyword,

  /// Semantic similarity search.
  semantic,

  /// Hybrid search (keyword + semantic).
  hybrid,

  /// Exact match search.
  exact;
}

/// A search query.
class SearchQuery {
  /// Query text.
  final String text;

  /// Search mode.
  final SearchMode mode;

  /// Maximum results to return.
  final int limit;

  /// Minimum score threshold.
  final double minScore;

  /// Filter by document IDs.
  final List<String>? documentIds;

  /// Filter by tags.
  final List<String>? tags;

  /// Filter by metadata.
  final Map<String, dynamic>? metadataFilter;

  /// Include content in results.
  final bool includeContent;

  /// Include embeddings in results.
  final bool includeEmbeddings;

  /// Query embedding (for semantic search).
  final List<double>? embedding;

  /// Weight for keyword component in hybrid search.
  final double keywordWeight;

  /// Weight for semantic component in hybrid search.
  final double semanticWeight;

  const SearchQuery({
    required this.text,
    this.mode = SearchMode.keyword,
    this.limit = 10,
    this.minScore = 0.0,
    this.documentIds,
    this.tags,
    this.metadataFilter,
    this.includeContent = true,
    this.includeEmbeddings = false,
    this.embedding,
    this.keywordWeight = 0.5,
    this.semanticWeight = 0.5,
  });

  /// Create from JSON.
  factory SearchQuery.fromJson(Map<String, dynamic> json) {
    return SearchQuery(
      text: json['text'] as String? ?? '',
      mode: SearchMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => SearchMode.keyword,
      ),
      limit: json['limit'] as int? ?? 10,
      minScore: (json['minScore'] as num?)?.toDouble() ?? 0.0,
      documentIds: (json['documentIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      tags: (json['tags'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      metadataFilter: json['metadataFilter'] as Map<String, dynamic>?,
      includeContent: json['includeContent'] as bool? ?? true,
      includeEmbeddings: json['includeEmbeddings'] as bool? ?? false,
      embedding: (json['embedding'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      keywordWeight: (json['keywordWeight'] as num?)?.toDouble() ?? 0.5,
      semanticWeight: (json['semanticWeight'] as num?)?.toDouble() ?? 0.5,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'text': text,
        'mode': mode.name,
        'limit': limit,
        'minScore': minScore,
        if (documentIds != null) 'documentIds': documentIds,
        if (tags != null) 'tags': tags,
        if (metadataFilter != null) 'metadataFilter': metadataFilter,
        'includeContent': includeContent,
        'includeEmbeddings': includeEmbeddings,
        if (embedding != null) 'embedding': embedding,
        'keywordWeight': keywordWeight,
        'semanticWeight': semanticWeight,
      };

  /// Copy with modifications.
  SearchQuery copyWith({
    String? text,
    SearchMode? mode,
    int? limit,
    double? minScore,
    List<String>? documentIds,
    List<String>? tags,
    Map<String, dynamic>? metadataFilter,
    bool? includeContent,
    bool? includeEmbeddings,
    List<double>? embedding,
    double? keywordWeight,
    double? semanticWeight,
  }) {
    return SearchQuery(
      text: text ?? this.text,
      mode: mode ?? this.mode,
      limit: limit ?? this.limit,
      minScore: minScore ?? this.minScore,
      documentIds: documentIds ?? this.documentIds,
      tags: tags ?? this.tags,
      metadataFilter: metadataFilter ?? this.metadataFilter,
      includeContent: includeContent ?? this.includeContent,
      includeEmbeddings: includeEmbeddings ?? this.includeEmbeddings,
      embedding: embedding ?? this.embedding,
      keywordWeight: keywordWeight ?? this.keywordWeight,
      semanticWeight: semanticWeight ?? this.semanticWeight,
    );
  }

  /// Create a keyword search query.
  factory SearchQuery.keyword(String text, {int limit = 10}) {
    return SearchQuery(
      text: text,
      mode: SearchMode.keyword,
      limit: limit,
    );
  }

  /// Create a semantic search query.
  factory SearchQuery.semantic(
    String text, {
    List<double>? embedding,
    int limit = 10,
  }) {
    return SearchQuery(
      text: text,
      mode: SearchMode.semantic,
      embedding: embedding,
      limit: limit,
    );
  }

  /// Create a hybrid search query.
  factory SearchQuery.hybrid(
    String text, {
    List<double>? embedding,
    int limit = 10,
    double keywordWeight = 0.5,
    double semanticWeight = 0.5,
  }) {
    return SearchQuery(
      text: text,
      mode: SearchMode.hybrid,
      embedding: embedding,
      limit: limit,
      keywordWeight: keywordWeight,
      semanticWeight: semanticWeight,
    );
  }

  @override
  String toString() => 'SearchQuery($text, mode: ${mode.name}, limit: $limit)';
}

/// Query builder for constructing search queries.
class SearchQueryBuilder {
  String _text = '';
  SearchMode _mode = SearchMode.keyword;
  int _limit = 10;
  double _minScore = 0.0;
  List<String>? _documentIds;
  List<String>? _tags;
  Map<String, dynamic>? _metadataFilter;
  bool _includeContent = true;
  bool _includeEmbeddings = false;
  List<double>? _embedding;
  double _keywordWeight = 0.5;
  double _semanticWeight = 0.5;

  /// Set query text.
  SearchQueryBuilder text(String text) {
    _text = text;
    return this;
  }

  /// Set search mode.
  SearchQueryBuilder mode(SearchMode mode) {
    _mode = mode;
    return this;
  }

  /// Set result limit.
  SearchQueryBuilder limit(int limit) {
    _limit = limit;
    return this;
  }

  /// Set minimum score.
  SearchQueryBuilder minScore(double score) {
    _minScore = score;
    return this;
  }

  /// Filter by document IDs.
  SearchQueryBuilder filterDocuments(List<String> ids) {
    _documentIds = ids;
    return this;
  }

  /// Filter by tags.
  SearchQueryBuilder filterTags(List<String> tags) {
    _tags = tags;
    return this;
  }

  /// Filter by metadata.
  SearchQueryBuilder filterMetadata(Map<String, dynamic> filter) {
    _metadataFilter = filter;
    return this;
  }

  /// Include content in results.
  SearchQueryBuilder withContent(bool include) {
    _includeContent = include;
    return this;
  }

  /// Include embeddings in results.
  SearchQueryBuilder withEmbeddings(bool include) {
    _includeEmbeddings = include;
    return this;
  }

  /// Set query embedding.
  SearchQueryBuilder embedding(List<double> embedding) {
    _embedding = embedding;
    return this;
  }

  /// Set hybrid weights.
  SearchQueryBuilder hybridWeights({
    double keyword = 0.5,
    double semantic = 0.5,
  }) {
    _keywordWeight = keyword;
    _semanticWeight = semantic;
    return this;
  }

  /// Build the query.
  SearchQuery build() {
    return SearchQuery(
      text: _text,
      mode: _mode,
      limit: _limit,
      minScore: _minScore,
      documentIds: _documentIds,
      tags: _tags,
      metadataFilter: _metadataFilter,
      includeContent: _includeContent,
      includeEmbeddings: _includeEmbeddings,
      embedding: _embedding,
      keywordWeight: _keywordWeight,
      semanticWeight: _semanticWeight,
    );
  }
}
