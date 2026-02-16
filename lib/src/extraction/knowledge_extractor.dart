/// Knowledge extraction from documents.
library;

import 'package:mcp_fact_graph/mcp_fact_graph.dart';

import '../document/document.dart';

/// Abstract knowledge extractor interface.
abstract class KnowledgeExtractor {
  /// Extract knowledge from a document.
  Future<ExtractionResult> extract(Document document);

  /// Extract knowledge from multiple documents.
  Future<List<ExtractionResult>> extractBatch(List<Document> documents);
}

/// Result of knowledge extraction.
class ExtractionResult {
  /// Source document ID.
  final String documentId;

  /// Extracted entities.
  final List<ExtractedEntity> entities;

  /// Extracted relations.
  final List<ExtractedRelation> relations;

  /// Extracted facts as graph nodes.
  final List<FactNode> factNodes;

  /// Extracted facts as graph edges.
  final List<FactEdge> factEdges;

  /// Extraction metadata.
  final Map<String, dynamic> metadata;

  const ExtractionResult({
    required this.documentId,
    this.entities = const [],
    this.relations = const [],
    this.factNodes = const [],
    this.factEdges = const [],
    this.metadata = const {},
  });

  /// Check if extraction found anything.
  bool get isEmpty =>
      entities.isEmpty &&
      relations.isEmpty &&
      factNodes.isEmpty &&
      factEdges.isEmpty;

  /// Check if extraction has results.
  bool get hasResults => !isEmpty;

  /// Get entity count.
  int get entityCount => entities.length;

  /// Get relation count.
  int get relationCount => relations.length;

  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        if (entities.isNotEmpty)
          'entities': entities.map((e) => e.toJson()).toList(),
        if (relations.isNotEmpty)
          'relations': relations.map((r) => r.toJson()).toList(),
        if (factNodes.isNotEmpty)
          'factNodes': factNodes.map((n) => n.toJson()).toList(),
        if (factEdges.isNotEmpty)
          'factEdges': factEdges.map((e) => e.toJson()).toList(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}

/// An extracted entity.
class ExtractedEntity {
  /// Entity ID.
  final String id;

  /// Entity text.
  final String text;

  /// Entity type.
  final String type;

  /// Position in source document.
  final int? position;

  /// Extraction confidence.
  final double confidence;

  /// Entity metadata.
  final Map<String, dynamic> metadata;

  const ExtractedEntity({
    required this.id,
    required this.text,
    required this.type,
    this.position,
    this.confidence = 1.0,
    this.metadata = const {},
  });

  factory ExtractedEntity.fromJson(Map<String, dynamic> json) {
    return ExtractedEntity(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      type: json['type'] as String? ?? '',
      position: json['position'] as int?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'type': type,
        if (position != null) 'position': position,
        'confidence': confidence,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  /// Convert to a fact node.
  FactNode toFactNode() {
    return FactNode(
      id: id,
      type: NodeType.entity,
      content: {
        'text': text,
        'entityType': type,
        ...metadata,
      },
      confidence: confidence,
    );
  }

  @override
  String toString() => 'ExtractedEntity($id: $text [$type])';
}

/// An extracted relation.
class ExtractedRelation {
  /// Relation ID.
  final String id;

  /// Source entity ID.
  final String sourceId;

  /// Target entity ID.
  final String targetId;

  /// Relation type.
  final String type;

  /// Relation label.
  final String? label;

  /// Extraction confidence.
  final double confidence;

  /// Relation metadata.
  final Map<String, dynamic> metadata;

  const ExtractedRelation({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.type,
    this.label,
    this.confidence = 1.0,
    this.metadata = const {},
  });

  factory ExtractedRelation.fromJson(Map<String, dynamic> json) {
    return ExtractedRelation(
      id: json['id'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? '',
      targetId: json['targetId'] as String? ?? '',
      type: json['type'] as String? ?? '',
      label: json['label'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceId': sourceId,
        'targetId': targetId,
        'type': type,
        if (label != null) 'label': label,
        'confidence': confidence,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  /// Convert to a fact edge.
  FactEdge toFactEdge() {
    return FactEdge(
      id: id,
      sourceId: sourceId,
      targetId: targetId,
      type: EdgeType.related,
      label: label ?? type,
      properties: {
        'relationType': type,
        ...metadata,
      },
      confidence: confidence,
    );
  }

  @override
  String toString() => 'ExtractedRelation($sourceId -[$type]-> $targetId)';
}

/// Simple pattern-based knowledge extractor.
class PatternKnowledgeExtractor implements KnowledgeExtractor {
  final List<ExtractionPattern> patterns;

  const PatternKnowledgeExtractor({this.patterns = const []});

  @override
  Future<ExtractionResult> extract(Document document) async {
    final entities = <ExtractedEntity>[];
    final relations = <ExtractedRelation>[];
    var entityIndex = 0;
    var relationIndex = 0;

    for (final pattern in patterns) {
      final matches = pattern.pattern.allMatches(document.content);
      for (final match in matches) {
        if (pattern.isRelation) {
          // Extract relation
          final sourceText = match.group(1) ?? '';
          final targetText = match.group(2) ?? '';

          // Create entity for source if not exists
          final sourceId = '${document.id}_entity_$entityIndex';
          entities.add(ExtractedEntity(
            id: sourceId,
            text: sourceText,
            type: pattern.entityType ?? 'unknown',
            position: match.start,
          ));
          entityIndex++;

          // Create entity for target if not exists
          final targetId = '${document.id}_entity_$entityIndex';
          entities.add(ExtractedEntity(
            id: targetId,
            text: targetText,
            type: pattern.entityType ?? 'unknown',
          ));
          entityIndex++;

          // Create relation
          relations.add(ExtractedRelation(
            id: '${document.id}_rel_$relationIndex',
            sourceId: sourceId,
            targetId: targetId,
            type: pattern.relationType ?? 'related',
          ));
          relationIndex++;
        } else {
          // Extract entity
          entities.add(ExtractedEntity(
            id: '${document.id}_entity_$entityIndex',
            text: match.group(0) ?? '',
            type: pattern.entityType ?? 'unknown',
            position: match.start,
          ));
          entityIndex++;
        }
      }
    }

    return ExtractionResult(
      documentId: document.id,
      entities: entities,
      relations: relations,
      factNodes: entities.map((e) => e.toFactNode()).toList(),
      factEdges: relations.map((r) => r.toFactEdge()).toList(),
    );
  }

  @override
  Future<List<ExtractionResult>> extractBatch(List<Document> documents) async {
    return Future.wait(documents.map(extract));
  }
}

/// An extraction pattern.
class ExtractionPattern {
  /// Pattern regex.
  final RegExp pattern;

  /// Entity type to assign.
  final String? entityType;

  /// Relation type (if pattern extracts relations).
  final String? relationType;

  /// Whether this pattern extracts relations.
  final bool isRelation;

  const ExtractionPattern({
    required this.pattern,
    this.entityType,
    this.relationType,
    this.isRelation = false,
  });

  /// Create an entity extraction pattern.
  factory ExtractionPattern.entity(
    String pattern, {
    required String type,
    bool caseSensitive = false,
  }) {
    return ExtractionPattern(
      pattern: RegExp(pattern, caseSensitive: caseSensitive),
      entityType: type,
      isRelation: false,
    );
  }

  /// Create a relation extraction pattern.
  factory ExtractionPattern.relation(
    String pattern, {
    required String type,
    String? entityType,
    bool caseSensitive = false,
  }) {
    return ExtractionPattern(
      pattern: RegExp(pattern, caseSensitive: caseSensitive),
      entityType: entityType,
      relationType: type,
      isRelation: true,
    );
  }
}

/// Common extraction patterns.
class CommonPatterns {
  /// Email pattern.
  static final email = ExtractionPattern.entity(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    type: 'email',
  );

  /// URL pattern.
  static final url = ExtractionPattern.entity(
    r'https?://[^\s<>"{}|\\^`\[\]]+',
    type: 'url',
  );

  /// Phone number pattern.
  static final phone = ExtractionPattern.entity(
    r'\+?[\d\s\-().]{10,}',
    type: 'phone',
  );

  /// Date pattern (various formats).
  static final date = ExtractionPattern.entity(
    r'\d{4}-\d{2}-\d{2}|\d{1,2}/\d{1,2}/\d{2,4}',
    type: 'date',
  );

  /// Money pattern.
  static final money = ExtractionPattern.entity(
    r'[\$€£¥]\s*[\d,]+\.?\d*|\d+\.?\d*\s*(?:USD|EUR|GBP|JPY)',
    type: 'money',
  );

  /// All common patterns.
  static List<ExtractionPattern> get all => [
        email,
        url,
        phone,
        date,
        money,
      ];
}
