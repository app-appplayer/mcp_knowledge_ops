/// Knowledge index for document storage and retrieval.
library;

import '../document/document.dart';
import '../document/chunk.dart';
import 'index_entry.dart';

/// Abstract knowledge index interface.
abstract class KnowledgeIndex {
  /// Index a document.
  Future<void> index(Document document);

  /// Index multiple documents.
  Future<void> indexAll(Iterable<Document> documents);

  /// Remove a document from the index.
  Future<bool> remove(String documentId);

  /// Get an indexed entry by ID.
  Future<IndexEntry?> get(String id);

  /// Get all entries for a document.
  Future<List<IndexEntry>> getByDocument(String documentId);

  /// Check if a document is indexed.
  Future<bool> contains(String documentId);

  /// Get total entry count.
  Future<int> get count;

  /// Clear all entries.
  Future<void> clear();
}

/// In-memory knowledge index.
class MemoryKnowledgeIndex implements KnowledgeIndex {
  final Map<String, IndexEntry> _entries = {};
  final Map<String, List<String>> _documentEntries = {};
  final DocumentChunker _chunker;

  MemoryKnowledgeIndex({DocumentChunker? chunker})
      : _chunker = chunker ?? const DocumentChunker();

  @override
  Future<void> index(Document document) async {
    // Remove existing entries for this document
    await remove(document.id);

    // Chunk the document
    final chunks = document.hasChunks
        ? document.chunks
        : _chunker.chunk(document.id, document.content);

    // Create entries for each chunk
    final entryIds = <String>[];
    for (final chunk in chunks) {
      final entry = IndexEntry(
        id: chunk.id,
        documentId: document.id,
        chunkId: chunk.id,
        content: chunk.content,
        embedding: chunk.embedding,
        metadata: {
          ...chunk.metadata,
          'title': document.title,
          'type': document.type.name,
          if (document.source != null) 'source': document.source,
        },
        createdAt: DateTime.now(),
      );

      _entries[entry.id] = entry;
      entryIds.add(entry.id);
    }

    _documentEntries[document.id] = entryIds;
  }

  @override
  Future<void> indexAll(Iterable<Document> documents) async {
    for (final document in documents) {
      await index(document);
    }
  }

  @override
  Future<bool> remove(String documentId) async {
    final entryIds = _documentEntries.remove(documentId);
    if (entryIds == null) return false;

    for (final id in entryIds) {
      _entries.remove(id);
    }
    return true;
  }

  @override
  Future<IndexEntry?> get(String id) async {
    return _entries[id];
  }

  @override
  Future<List<IndexEntry>> getByDocument(String documentId) async {
    final entryIds = _documentEntries[documentId] ?? [];
    return entryIds.map((id) => _entries[id]).nonNulls.toList();
  }

  @override
  Future<bool> contains(String documentId) async {
    return _documentEntries.containsKey(documentId);
  }

  @override
  Future<int> get count async => _entries.length;

  @override
  Future<void> clear() async {
    _entries.clear();
    _documentEntries.clear();
  }

  /// Get all entries.
  List<IndexEntry> get allEntries => _entries.values.toList();

  /// Get all document IDs.
  List<String> get documentIds => _documentEntries.keys.toList();
}

/// Inverted index for text-based search.
class InvertedIndex {
  final Map<String, List<TermEntry>> _termIndex = {};
  final Map<String, int> _documentLengths = {};
  int _totalDocuments = 0;
  double _avgDocLength = 0;

  /// Index a document.
  void index(String documentId, String content) {
    // Tokenize content
    final terms = _tokenize(content);
    _documentLengths[documentId] = terms.length;

    // Build term frequency map
    final termFreq = <String, List<int>>{};
    for (var i = 0; i < terms.length; i++) {
      final term = terms[i];
      termFreq.putIfAbsent(term, () => []).add(i);
    }

    // Add to inverted index
    for (final entry in termFreq.entries) {
      final termEntry = TermEntry(
        term: entry.key,
        documentId: documentId,
        frequency: entry.value.length,
        positions: entry.value,
      );

      _termIndex.putIfAbsent(entry.key, () => []).add(termEntry);
    }

    _totalDocuments++;
    _updateAvgDocLength();
  }

  /// Remove a document from the index.
  void remove(String documentId) {
    _documentLengths.remove(documentId);

    for (final entries in _termIndex.values) {
      entries.removeWhere((e) => e.documentId == documentId);
    }

    // Clean up empty term entries
    _termIndex.removeWhere((_, entries) => entries.isEmpty);

    _totalDocuments--;
    _updateAvgDocLength();
  }

  /// Search for terms.
  Map<String, double> search(String query) {
    final queryTerms = _tokenize(query);
    final scores = <String, double>{};

    for (final term in queryTerms) {
      final entries = _termIndex[term];
      if (entries == null) continue;

      // Calculate IDF
      final idf = _idf(entries.length);

      for (final entry in entries) {
        // Calculate TF-IDF score
        final tf = entry.tf;
        final docLength = _documentLengths[entry.documentId] ?? 1;

        // BM25 scoring
        final k1 = 1.2;
        final b = 0.75;
        final tfNorm = (tf * (k1 + 1)) /
            (tf + k1 * (1 - b + b * (docLength / _avgDocLength)));

        scores.update(
          entry.documentId,
          (score) => score + tfNorm * idf,
          ifAbsent: () => tfNorm * idf,
        );
      }
    }

    return scores;
  }

  /// Get terms for a document.
  List<String> getTerms(String documentId) {
    final terms = <String>[];
    for (final entry in _termIndex.entries) {
      if (entry.value.any((e) => e.documentId == documentId)) {
        terms.add(entry.key);
      }
    }
    return terms;
  }

  /// Clear the index.
  void clear() {
    _termIndex.clear();
    _documentLengths.clear();
    _totalDocuments = 0;
    _avgDocLength = 0;
  }

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1)
        .toList();
  }

  double _idf(int docFreq) {
    if (docFreq == 0 || _totalDocuments == 0) return 0;
    return (_totalDocuments / docFreq + 1).log();
  }

  void _updateAvgDocLength() {
    if (_documentLengths.isEmpty) {
      _avgDocLength = 0;
      return;
    }
    final total = _documentLengths.values.reduce((a, b) => a + b);
    _avgDocLength = total / _documentLengths.length;
  }
}

/// Extension for log calculation.
extension _LogExtension on num {
  double log() {
    if (this <= 0) return double.negativeInfinity;
    if (this == 1) return 0;

    final x = toDouble();
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
}
