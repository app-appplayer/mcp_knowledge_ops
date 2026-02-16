/// Document chunking for knowledge processing.
library;

/// A chunk of a document.
class Chunk {
  /// Chunk identifier.
  final String id;

  /// Parent document ID.
  final String documentId;

  /// Chunk content.
  final String content;

  /// Chunk index within document.
  final int index;

  /// Start position in original document.
  final int startPosition;

  /// End position in original document.
  final int endPosition;

  /// Chunk metadata.
  final Map<String, dynamic> metadata;

  /// Embedding vector (if computed).
  final List<double>? embedding;

  const Chunk({
    required this.id,
    required this.documentId,
    required this.content,
    this.index = 0,
    this.startPosition = 0,
    this.endPosition = 0,
    this.metadata = const {},
    this.embedding,
  });

  /// Create from JSON.
  factory Chunk.fromJson(Map<String, dynamic> json) {
    return Chunk(
      id: json['id'] as String? ?? '',
      documentId: json['documentId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      index: json['index'] as int? ?? 0,
      startPosition: json['startPosition'] as int? ?? 0,
      endPosition: json['endPosition'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      embedding: (json['embedding'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'documentId': documentId,
        'content': content,
        'index': index,
        'startPosition': startPosition,
        'endPosition': endPosition,
        if (metadata.isNotEmpty) 'metadata': metadata,
        if (embedding != null) 'embedding': embedding,
      };

  /// Copy with modifications.
  Chunk copyWith({
    String? id,
    String? documentId,
    String? content,
    int? index,
    int? startPosition,
    int? endPosition,
    Map<String, dynamic>? metadata,
    List<double>? embedding,
  }) {
    return Chunk(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      content: content ?? this.content,
      index: index ?? this.index,
      startPosition: startPosition ?? this.startPosition,
      endPosition: endPosition ?? this.endPosition,
      metadata: metadata ?? this.metadata,
      embedding: embedding ?? this.embedding,
    );
  }

  /// Get content length.
  int get length => content.length;

  /// Check if chunk has embedding.
  bool get hasEmbedding => embedding != null && embedding!.isNotEmpty;

  @override
  String toString() => 'Chunk($id: index=$index, length=$length)';
}

/// Chunking strategy.
enum ChunkingStrategy {
  /// Fixed size chunks.
  fixedSize,

  /// Sentence-based chunks.
  sentence,

  /// Paragraph-based chunks.
  paragraph,

  /// Semantic chunks.
  semantic,

  /// Code-aware chunks (for source code).
  code,

  /// Custom chunking.
  custom;
}

/// Options for chunking documents.
class ChunkingOptions {
  /// Chunking strategy.
  final ChunkingStrategy strategy;

  /// Target chunk size (in characters).
  final int chunkSize;

  /// Overlap between chunks.
  final int overlap;

  /// Minimum chunk size.
  final int minChunkSize;

  /// Maximum chunk size.
  final int maxChunkSize;

  /// Whether to preserve boundaries (sentences, paragraphs).
  final bool preserveBoundaries;

  /// Separator pattern for splitting.
  final String? separator;

  const ChunkingOptions({
    this.strategy = ChunkingStrategy.paragraph,
    this.chunkSize = 1000,
    this.overlap = 100,
    this.minChunkSize = 100,
    this.maxChunkSize = 2000,
    this.preserveBoundaries = true,
    this.separator,
  });

  ChunkingOptions copyWith({
    ChunkingStrategy? strategy,
    int? chunkSize,
    int? overlap,
    int? minChunkSize,
    int? maxChunkSize,
    bool? preserveBoundaries,
    String? separator,
  }) {
    return ChunkingOptions(
      strategy: strategy ?? this.strategy,
      chunkSize: chunkSize ?? this.chunkSize,
      overlap: overlap ?? this.overlap,
      minChunkSize: minChunkSize ?? this.minChunkSize,
      maxChunkSize: maxChunkSize ?? this.maxChunkSize,
      preserveBoundaries: preserveBoundaries ?? this.preserveBoundaries,
      separator: separator ?? this.separator,
    );
  }
}

/// Chunks documents into smaller pieces.
class DocumentChunker {
  final ChunkingOptions options;

  const DocumentChunker({this.options = const ChunkingOptions()});

  /// Chunk a document.
  List<Chunk> chunk(String documentId, String content) {
    switch (options.strategy) {
      case ChunkingStrategy.fixedSize:
        return _chunkFixedSize(documentId, content);
      case ChunkingStrategy.sentence:
        return _chunkBySentence(documentId, content);
      case ChunkingStrategy.paragraph:
        return _chunkByParagraph(documentId, content);
      case ChunkingStrategy.semantic:
      case ChunkingStrategy.code:
      case ChunkingStrategy.custom:
        // Fall back to paragraph for unimplemented strategies
        return _chunkByParagraph(documentId, content);
    }
  }

  List<Chunk> _chunkFixedSize(String documentId, String content) {
    final chunks = <Chunk>[];
    var start = 0;
    var index = 0;

    while (start < content.length) {
      var end = start + options.chunkSize;
      if (end > content.length) {
        end = content.length;
      }

      // Adjust to preserve word boundaries
      if (options.preserveBoundaries && end < content.length) {
        final lastSpace = content.lastIndexOf(' ', end);
        if (lastSpace > start + options.minChunkSize) {
          end = lastSpace;
        }
      }

      chunks.add(Chunk(
        id: '${documentId}_chunk_$index',
        documentId: documentId,
        content: content.substring(start, end).trim(),
        index: index,
        startPosition: start,
        endPosition: end,
      ));

      start = end - options.overlap;
      if (start < 0) start = 0;
      index++;
    }

    return chunks;
  }

  List<Chunk> _chunkBySentence(String documentId, String content) {
    // Simple sentence splitting
    final sentencePattern = RegExp(r'[.!?]+\s+');
    final sentences = content.split(sentencePattern);

    final chunks = <Chunk>[];
    var currentChunk = StringBuffer();
    var chunkStart = 0;
    var currentPosition = 0;
    var index = 0;

    for (final sentence in sentences) {
      if (currentChunk.isEmpty) {
        currentChunk.write(sentence);
      } else if (currentChunk.length + sentence.length + 1 <= options.chunkSize) {
        currentChunk.write('. ');
        currentChunk.write(sentence);
      } else {
        // Save current chunk
        chunks.add(Chunk(
          id: '${documentId}_chunk_$index',
          documentId: documentId,
          content: currentChunk.toString().trim(),
          index: index,
          startPosition: chunkStart,
          endPosition: currentPosition,
        ));

        index++;
        chunkStart = currentPosition;
        currentChunk = StringBuffer(sentence);
      }
      currentPosition += sentence.length + 2; // +2 for ". "
    }

    // Add final chunk
    if (currentChunk.isNotEmpty) {
      chunks.add(Chunk(
        id: '${documentId}_chunk_$index',
        documentId: documentId,
        content: currentChunk.toString().trim(),
        index: index,
        startPosition: chunkStart,
        endPosition: content.length,
      ));
    }

    return chunks;
  }

  List<Chunk> _chunkByParagraph(String documentId, String content) {
    final paragraphs = content.split(RegExp(r'\n\s*\n'));

    final chunks = <Chunk>[];
    var currentChunk = StringBuffer();
    var chunkStart = 0;
    var currentPosition = 0;
    var index = 0;

    for (final paragraph in paragraphs) {
      final trimmed = paragraph.trim();
      if (trimmed.isEmpty) {
        currentPosition += paragraph.length + 2;
        continue;
      }

      if (currentChunk.isEmpty) {
        currentChunk.write(trimmed);
      } else if (currentChunk.length + trimmed.length + 2 <= options.chunkSize) {
        currentChunk.write('\n\n');
        currentChunk.write(trimmed);
      } else {
        // Save current chunk
        chunks.add(Chunk(
          id: '${documentId}_chunk_$index',
          documentId: documentId,
          content: currentChunk.toString(),
          index: index,
          startPosition: chunkStart,
          endPosition: currentPosition,
        ));

        index++;
        chunkStart = currentPosition;
        currentChunk = StringBuffer(trimmed);
      }
      currentPosition += paragraph.length + 2;
    }

    // Add final chunk
    if (currentChunk.isNotEmpty) {
      chunks.add(Chunk(
        id: '${documentId}_chunk_$index',
        documentId: documentId,
        content: currentChunk.toString(),
        index: index,
        startPosition: chunkStart,
        endPosition: content.length,
      ));
    }

    return chunks;
  }
}
