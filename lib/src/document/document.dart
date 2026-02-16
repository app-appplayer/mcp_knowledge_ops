/// Document representation for knowledge management.
library;

import 'chunk.dart';

/// Types of documents.
enum DocumentType {
  /// Plain text document.
  text,

  /// Markdown document.
  markdown,

  /// Code document.
  code,

  /// JSON document.
  json,

  /// HTML document.
  html,

  /// PDF document.
  pdf,

  /// Other document type.
  other;

  static DocumentType fromString(String value) {
    return DocumentType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DocumentType.other,
    );
  }

  static DocumentType fromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'txt':
        return DocumentType.text;
      case 'md':
      case 'markdown':
        return DocumentType.markdown;
      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
      case 'java':
      case 'go':
      case 'rs':
      case 'cpp':
      case 'c':
      case 'h':
        return DocumentType.code;
      case 'json':
        return DocumentType.json;
      case 'html':
      case 'htm':
        return DocumentType.html;
      case 'pdf':
        return DocumentType.pdf;
      default:
        return DocumentType.other;
    }
  }
}

/// A document in the knowledge base.
class Document {
  /// Unique document identifier.
  final String id;

  /// Document title.
  final String title;

  /// Document content.
  final String content;

  /// Document type.
  final DocumentType type;

  /// Source URI or path.
  final String? source;

  /// Document metadata.
  final Map<String, dynamic> metadata;

  /// Document chunks (for chunked processing).
  final List<Chunk> chunks;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last modified timestamp.
  final DateTime? modifiedAt;

  /// Document version.
  final String? version;

  /// Tags for categorization.
  final List<String> tags;

  const Document({
    required this.id,
    required this.title,
    required this.content,
    this.type = DocumentType.text,
    this.source,
    this.metadata = const {},
    this.chunks = const [],
    this.createdAt,
    this.modifiedAt,
    this.version,
    this.tags = const [],
  });

  /// Create from JSON.
  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      type: DocumentType.fromString(json['type'] as String? ?? 'text'),
      source: json['source'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      chunks: (json['chunks'] as List<dynamic>?)
              ?.map((e) => Chunk.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
      version: json['version'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'type': type.name,
        if (source != null) 'source': source,
        if (metadata.isNotEmpty) 'metadata': metadata,
        if (chunks.isNotEmpty) 'chunks': chunks.map((c) => c.toJson()).toList(),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
        if (version != null) 'version': version,
        if (tags.isNotEmpty) 'tags': tags,
      };

  /// Copy with modifications.
  Document copyWith({
    String? id,
    String? title,
    String? content,
    DocumentType? type,
    String? source,
    Map<String, dynamic>? metadata,
    List<Chunk>? chunks,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? version,
    List<String>? tags,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      source: source ?? this.source,
      metadata: metadata ?? this.metadata,
      chunks: chunks ?? this.chunks,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      version: version ?? this.version,
      tags: tags ?? this.tags,
    );
  }

  /// Get content length.
  int get length => content.length;

  /// Get word count.
  int get wordCount => content.split(RegExp(r'\s+')).length;

  /// Get line count.
  int get lineCount => content.split('\n').length;

  /// Check if document is empty.
  bool get isEmpty => content.isEmpty;

  /// Check if document has chunks.
  bool get hasChunks => chunks.isNotEmpty;

  @override
  String toString() => 'Document($id: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Document && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Document collection.
class DocumentCollection {
  /// Collection identifier.
  final String id;

  /// Collection name.
  final String name;

  /// Collection description.
  final String? description;

  /// Documents in this collection.
  final List<Document> documents;

  /// Collection metadata.
  final Map<String, dynamic> metadata;

  const DocumentCollection({
    required this.id,
    required this.name,
    this.description,
    this.documents = const [],
    this.metadata = const {},
  });

  factory DocumentCollection.fromJson(Map<String, dynamic> json) {
    return DocumentCollection(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      documents: (json['documents'] as List<dynamic>?)
              ?.map((e) => Document.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        if (documents.isNotEmpty)
          'documents': documents.map((d) => d.toJson()).toList(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  /// Get document count.
  int get count => documents.length;

  /// Get document by ID.
  Document? getDocument(String id) {
    return documents.where((d) => d.id == id).firstOrNull;
  }

  /// Add a document.
  DocumentCollection addDocument(Document document) {
    return DocumentCollection(
      id: id,
      name: name,
      description: description,
      documents: [...documents, document],
      metadata: metadata,
    );
  }

  /// Remove a document.
  DocumentCollection removeDocument(String documentId) {
    return DocumentCollection(
      id: id,
      name: name,
      description: description,
      documents: documents.where((d) => d.id != documentId).toList(),
      metadata: metadata,
    );
  }
}
