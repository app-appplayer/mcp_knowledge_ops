/// Embedding utilities for vector operations.
library;

/// Embedding vector representation.
class Embedding {
  /// Vector values.
  final List<double> values;

  /// Model used to generate embedding.
  final String? model;

  /// Embedding metadata.
  final Map<String, dynamic> metadata;

  const Embedding({
    required this.values,
    this.model,
    this.metadata = const {},
  });

  /// Create from JSON.
  factory Embedding.fromJson(Map<String, dynamic> json) {
    return Embedding(
      values: (json['values'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      model: json['model'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'values': values,
        if (model != null) 'model': model,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  /// Get dimension.
  int get dimension => values.length;

  /// Get L2 norm.
  double get norm {
    var sum = 0.0;
    for (final v in values) {
      sum += v * v;
    }
    return _sqrt(sum);
  }

  /// Normalize the embedding.
  Embedding normalize() {
    final n = norm;
    if (n == 0) return this;
    return Embedding(
      values: values.map((v) => v / n).toList(),
      model: model,
      metadata: metadata,
    );
  }

  /// Compute cosine similarity with another embedding.
  double cosineSimilarity(Embedding other) {
    if (values.length != other.values.length) {
      throw ArgumentError('Embedding dimensions must match');
    }

    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;

    for (var i = 0; i < values.length; i++) {
      dot += values[i] * other.values[i];
      normA += values[i] * values[i];
      normB += other.values[i] * other.values[i];
    }

    if (normA == 0 || normB == 0) return 0;
    return dot / (_sqrt(normA) * _sqrt(normB));
  }

  /// Compute Euclidean distance from another embedding.
  double euclideanDistance(Embedding other) {
    if (values.length != other.values.length) {
      throw ArgumentError('Embedding dimensions must match');
    }

    var sum = 0.0;
    for (var i = 0; i < values.length; i++) {
      final diff = values[i] - other.values[i];
      sum += diff * diff;
    }
    return _sqrt(sum);
  }

  /// Compute dot product with another embedding.
  double dotProduct(Embedding other) {
    if (values.length != other.values.length) {
      throw ArgumentError('Embedding dimensions must match');
    }

    var sum = 0.0;
    for (var i = 0; i < values.length; i++) {
      sum += values[i] * other.values[i];
    }
    return sum;
  }

  /// Add another embedding.
  Embedding add(Embedding other) {
    if (values.length != other.values.length) {
      throw ArgumentError('Embedding dimensions must match');
    }

    return Embedding(
      values: List.generate(
        values.length,
        (i) => values[i] + other.values[i],
      ),
      model: model,
    );
  }

  /// Subtract another embedding.
  Embedding subtract(Embedding other) {
    if (values.length != other.values.length) {
      throw ArgumentError('Embedding dimensions must match');
    }

    return Embedding(
      values: List.generate(
        values.length,
        (i) => values[i] - other.values[i],
      ),
      model: model,
    );
  }

  /// Scale embedding by a factor.
  Embedding scale(double factor) {
    return Embedding(
      values: values.map((v) => v * factor).toList(),
      model: model,
      metadata: metadata,
    );
  }

  @override
  String toString() => 'Embedding(dim=$dimension)';

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    var guess = x / 2;
    for (var i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}

/// Abstract embedding provider interface.
abstract class EmbeddingProvider {
  /// Get embedding for text.
  Future<Embedding> embed(String text);

  /// Get embeddings for multiple texts.
  Future<List<Embedding>> embedBatch(List<String> texts);

  /// Get the model name.
  String get modelName;

  /// Get the embedding dimension.
  int get dimension;
}

/// Mock embedding provider for testing.
class MockEmbeddingProvider implements EmbeddingProvider {
  @override
  final String modelName;

  @override
  final int dimension;

  final int _seed;

  MockEmbeddingProvider({
    this.modelName = 'mock',
    this.dimension = 384,
    int seed = 42,
  }) : _seed = seed;

  @override
  Future<Embedding> embed(String text) async {
    // Generate deterministic pseudo-random embedding based on text
    final values = List.generate(dimension, (i) {
      final hash = (text.hashCode + i * _seed) % 10000;
      return (hash / 10000.0) * 2 - 1; // Range [-1, 1]
    });

    return Embedding(
      values: values,
      model: modelName,
      metadata: {'text_length': text.length},
    );
  }

  @override
  Future<List<Embedding>> embedBatch(List<String> texts) async {
    return Future.wait(texts.map(embed));
  }
}

/// Embedding similarity search.
class EmbeddingSimilaritySearch {
  final List<Embedding> _embeddings;
  final List<String> _ids;

  EmbeddingSimilaritySearch()
      : _embeddings = [],
        _ids = [];

  /// Add an embedding.
  void add(String id, Embedding embedding) {
    _embeddings.add(embedding);
    _ids.add(id);
  }

  /// Search for similar embeddings.
  List<SimilarityResult> search(
    Embedding query, {
    int topK = 5,
    double minSimilarity = 0,
  }) {
    final results = <SimilarityResult>[];

    for (var i = 0; i < _embeddings.length; i++) {
      final similarity = query.cosineSimilarity(_embeddings[i]);
      if (similarity >= minSimilarity) {
        results.add(SimilarityResult(
          id: _ids[i],
          similarity: similarity,
          embedding: _embeddings[i],
        ));
      }
    }

    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.take(topK).toList();
  }

  /// Get count.
  int get count => _embeddings.length;

  /// Clear all embeddings.
  void clear() {
    _embeddings.clear();
    _ids.clear();
  }
}

/// Result of a similarity search.
class SimilarityResult {
  /// Entry ID.
  final String id;

  /// Similarity score.
  final double similarity;

  /// The embedding.
  final Embedding embedding;

  const SimilarityResult({
    required this.id,
    required this.similarity,
    required this.embedding,
  });

  @override
  String toString() => 'SimilarityResult($id: $similarity)';
}
