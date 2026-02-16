/// Index entry definitions.
library;

/// An entry in the knowledge index.
class IndexEntry {
  /// Entry identifier.
  final String id;

  /// Document ID this entry references.
  final String documentId;

  /// Chunk ID (if applicable).
  final String? chunkId;

  /// Entry content (for text-based indexing).
  final String content;

  /// Entry embedding vector.
  final List<double>? embedding;

  /// Entry metadata.
  final Map<String, dynamic> metadata;

  /// Entry score/weight.
  final double score;

  /// Creation timestamp.
  final DateTime? createdAt;

  const IndexEntry({
    required this.id,
    required this.documentId,
    this.chunkId,
    required this.content,
    this.embedding,
    this.metadata = const {},
    this.score = 1.0,
    this.createdAt,
  });

  /// Create from JSON.
  factory IndexEntry.fromJson(Map<String, dynamic> json) {
    return IndexEntry(
      id: json['id'] as String? ?? '',
      documentId: json['documentId'] as String? ?? '',
      chunkId: json['chunkId'] as String?,
      content: json['content'] as String? ?? '',
      embedding: (json['embedding'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      score: (json['score'] as num?)?.toDouble() ?? 1.0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'documentId': documentId,
        if (chunkId != null) 'chunkId': chunkId,
        'content': content,
        if (embedding != null) 'embedding': embedding,
        if (metadata.isNotEmpty) 'metadata': metadata,
        'score': score,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  /// Copy with modifications.
  IndexEntry copyWith({
    String? id,
    String? documentId,
    String? chunkId,
    String? content,
    List<double>? embedding,
    Map<String, dynamic>? metadata,
    double? score,
    DateTime? createdAt,
  }) {
    return IndexEntry(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      chunkId: chunkId ?? this.chunkId,
      content: content ?? this.content,
      embedding: embedding ?? this.embedding,
      metadata: metadata ?? this.metadata,
      score: score ?? this.score,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Check if entry has embedding.
  bool get hasEmbedding => embedding != null && embedding!.isNotEmpty;

  @override
  String toString() => 'IndexEntry($id: doc=$documentId, score=$score)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndexEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Term frequency entry for text-based indexing.
class TermEntry {
  /// The term.
  final String term;

  /// Document ID.
  final String documentId;

  /// Term frequency in document.
  final int frequency;

  /// Positions where term appears.
  final List<int> positions;

  const TermEntry({
    required this.term,
    required this.documentId,
    this.frequency = 1,
    this.positions = const [],
  });

  factory TermEntry.fromJson(Map<String, dynamic> json) {
    return TermEntry(
      term: json['term'] as String? ?? '',
      documentId: json['documentId'] as String? ?? '',
      frequency: json['frequency'] as int? ?? 1,
      positions: (json['positions'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'term': term,
        'documentId': documentId,
        'frequency': frequency,
        if (positions.isNotEmpty) 'positions': positions,
      };

  /// Calculate TF (term frequency).
  double get tf => frequency > 0 ? 1 + (frequency - 1).toDouble().log() : 0;
}

/// Extension for log calculation.
extension on double {
  double log() {
    if (this <= 0) return 0;
    return _log(this);
  }
}

double _log(double x) {
  // Natural log approximation for positive numbers
  if (x <= 0) return double.negativeInfinity;
  if (x == 1) return 0;

  var result = 0.0;
  var term = (x - 1) / (x + 1);
  final term2 = term * term;
  var n = 1;

  for (var i = 0; i < 100; i++) {
    result += term / n;
    term *= term2;
    n += 2;
  }

  return 2 * result;
}
